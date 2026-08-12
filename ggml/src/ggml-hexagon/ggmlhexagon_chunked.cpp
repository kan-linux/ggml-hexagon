// ggmlhexagon_chunked.cpp
//
// JZ's chunked streaming producer-consumer module (Spike B) - implementation.
//
// Spike B-2 scope: build the producer thread, slot table, mutex, condvar,
// and chunk_state state machine. The thread pulls load requests from a
// queue, simulates the I/O (real fseek/fread comes in B-5), and flips the
// slot state from LOADING -> READY. The consumer-side request/wait API
// is the minimum needed to exercise the thread end-to-end from the
// graph_compute_batch hook stub (full layer parsing lands in B-4).
//
// B-1 vs B-2 diff (relative to the B-1 stub):
//   - chunk_slot struct: per-slot state (EMPTY/LOADING/READY/IN_USE),
//     layer index, mempool offset/size, last-use timestamp for LRU,
//     refcount for in-flight cgraph nodes.
//   - slot table: std::vector<chunk_slot> of size n_slots.
//   - mutex + condvar: std::mutex + std::condition_variable for
//     producer-consumer sync (slot state changes + request queue).
//   - request queue: std::deque<int> of slot indices that need filling.
//   - producer thread: std::thread running producer_thread_fn, pulled
//     by a shutdown atomic + condvar predicate.
//   - ggmlhexagon_chunked_request_layer_for_cgraph(): thin wrapper that
//     the graph_compute_batch hook calls. In B-2 it still uses a fake
//     "first node's name" parser (full blk.N. parser in B-4).
//
// Logging note: this file uses its own printf-based logger (with the
// [CHUNKED] tag) instead of the GGMLHEXAGON_LOG_* family because those
// macros expand to static functions in ggml-hexagon-jz.cpp and are not
// reachable from another translation unit without exposing them via a
// header. We can promote these logs to the shared channel in a later spike
// if cross-module log filtering becomes a problem.

#include "ggmlhexagon_chunked.h"

#include "ggml-impl.h"  // ggml_cgraph full definition (header only forward-declares it)
#include "gguf.h"      // Spike B-5: gguf_init_from_file, gguf_get_n_tensors, etc.

#include <atomic>
#include <condition_variable>
#include <cstddef>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <ctime>
#include <deque>
#include <mutex>
#include <new>
#include <set>
#include <thread>
#include <vector>

// App-side log channels: we route to printf (which is also picked up by
// adb logcat via __android_log_write on Android when the binary is
// launched under logcat, and on stdout on Linux/WoA).
#define CHUNKED_LOG_ALWAYS(fmt, ...)                                                          \
    do {                                                                                      \
        std::fprintf(stdout, "[CHUNKED, %s] " fmt "\n", __func__, ##__VA_ARGS__);             \
        std::fflush(stdout);                                                                  \
    } while (0)

#define CHUNKED_LOG_ERROR(fmt, ...)                                                           \
    do {                                                                                      \
        std::fprintf(stderr, "[CHUNKED, %s] ERROR: " fmt "\n", __func__, ##__VA_ARGS__);      \
        std::fflush(stderr);                                                                  \
    } while (0)

// ----------------------------------------------------------------------------
// Forward declarations for helper functions that are defined later in
// this TU. parse_layer_index and is_permanent_tensor_name are used by
// both build_layer_index (init time) and collect_layers_from_cgraph
// (per-batch hook), but the latter is defined after the slot table
// helpers. Forward decls keep the code order flat.
// ----------------------------------------------------------------------------
[[maybe_unused]] static int  parse_layer_index(const char * name);
[[maybe_unused]] static bool is_permanent_tensor_name(const char * name);

// ----------------------------------------------------------------------------
// State machine.
//
// EMPTY    : slot is free; producer can claim it to start a load.
// LOADING  : producer has claimed the slot and is writing chunk bytes.
// READY    : producer finished; consumer can claim it (atomic refcount++).
// IN_USE   : consumer is reading; producer must not evict.
//
// Transitions:
//   EMPTY    -> LOADING  : producer claims slot (sets layer_idx, etc.)
//   LOADING  -> READY    : producer finishes (or fails -> EMPTY with error)
//   READY    -> IN_USE   : consumer claims slot (refcount > 0)
//   IN_USE   -> READY    : consumer releases last ref (refcount -> 0)
//   READY    -> EMPTY    : LRU eviction picks this slot
// ----------------------------------------------------------------------------
enum chunk_state {
    CHUNK_STATE_EMPTY    = 0,
    CHUNK_STATE_LOADING  = 1,
    CHUNK_STATE_READY    = 2,
    CHUNK_STATE_IN_USE   = 3,
};

struct chunk_slot {
    chunk_state state;          // guarded by slot_mutex
    int         layer_idx;      // which model layer is in this slot; -1 if EMPTY
    size_t      mempool_offset; // offset of the slot within the sliding window
    size_t      bytes_loaded;   // how many bytes were written; <= slot_size_bytes
    uint64_t    last_use_seq;   // monotonic counter for LRU; larger = more recent
    int         refcount;       // number of in-flight cgraph nodes holding this slot
    // B-2 keeps the actual gguf I/O as a stub. B-5 will replace this with
    // gguf_t + tensor list + fread.
};

// ----------------------------------------------------------------------------
// hexagon_chunked_state: full definition.
// ----------------------------------------------------------------------------
struct hexagon_chunked_state {
    // B-1 lifecycle fields
    bool      init_done;
    int       n_slots;
    size_t    slot_size_bytes;
    size_t    window_offset;
    size_t    window_size;
    size_t    permanent_size;
    size_t    kv_cache_size;

    // gguf path
    char      gguf_path[256];

    // B-2 producer/consumer sync + slot table
    std::mutex                       * slot_mutex;
    std::condition_variable          * slot_cv;
    std::vector<chunk_slot>            slots;          // size = n_slots
    std::deque<int>                    request_queue;  // slot indices pending fill

    // LRU monotonic counter
    uint64_t                          lru_seq;

    // Producer thread
    std::thread                     * producer_thread;
    std::atomic<bool>                 shutdown;       // set by deinit to stop the thread

    // Bookkeeping counters (B-2 sanity stats; useful for adb logcat checks)
    uint64_t                          stat_loads_started;
    uint64_t                          stat_loads_completed;
    uint64_t                          stat_loads_failed;
    uint64_t                          stat_waits;     // how many times consumer blocked

    // Mempool pointer (set lazily by the hook on first call). The chunked
    // module never owns this memory; it is borrowed from the JZ context.
    void                            * mempool_base;   // == JZ ctx->rpc_mempool
    size_t                            mempool_len;    // == JZ ctx->rpc_mempool_len
    bool                              mempool_bound;  // true after the first hook call

    // B-5: per-layer tensor index built at init from the gguf metadata.
    // layer_index[i] is the list of tensors in layer i; permanent tensors
    // (token_embd, output, rope_freqs) are NOT in the index because they
    // live in the permanent region and are loaded by the existing
    // alloc_buffer path. The intra_slot_offset is the byte offset within
    // a slot where this tensor's bytes start; pre-computed at init so the
    // per-batch remap is a single addition instead of a per-tensor scan.
    struct layer_tensor {
        const char * name;              // gguf-owned name, valid until deinit
        size_t       gguf_offset;       // offset into the gguf data section
        size_t       size;              // tensor size in bytes
        size_t       intra_slot_offset; // offset within a slot (128-byte aligned)
    };
    struct layer_info {
        std::vector<layer_tensor> tensors;
        size_t                    total_size;  // sum of tensor sizes
    };
    std::vector<layer_info>           layer_index;  // size = max_layers + 1, indexed by layer_idx

    // B-5: gguf file handle for the producer thread to fread from. Opened
    // once at init (after building the layer index) and held open for the
    // lifetime of the chunked module. The producer thread is the only
    // reader; no locking needed.
    struct gguf_context             * gguf_ctx;     // gguf metadata (for offset/size lookups)
    FILE                            * gguf_file;    // fread source; never null after init OK
    size_t                            gguf_data_offset;  // gguf_get_data_offset(gguf_ctx)
};

// ----------------------------------------------------------------------------
// Per-batch slot tracking (B-4).
//
// ggmlhexagon_chunked_acquire_for_cgraph returns an opaque int handle that
// the caller (graph_compute_batch) passes back to ggmlhexagon_chunked_release
// after compute. The handle is a 1-based index into g_handle_pool; 0 means
// "invalid / no work". The pool is a simple append-on-demand vector, indexed
// by handle id, so the lookup in release is O(1) and no dynamic allocation
// is needed in the hot path (the pool grows once and then reuses slots).
//
// Each handle also tracks the tensors whose data pointers were remapped
// during acquire, so release can restore them to NULL (the original
// "no-mempool" sentinel set by jz.cpp's init_tensor). Without this restore
// the next batch would see stale slot pointers after a slot was evicted
// and reused for a different layer.
// ----------------------------------------------------------------------------
struct remapped_tensor {
    struct ggml_tensor * tensor;     // tensor whose data was remapped
    void               * orig_data;  // original data pointer (usually NULL)
};
struct batch_handle_entry {
    hexagon_chunked_state * state;
    std::vector<int>        slot_indices;     // slots claimed for this batch
    std::vector<remapped_tensor> remapped;    // tensors whose data we remapped
    bool                    in_use;
};

static std::mutex                g_handle_mutex;
static std::vector<batch_handle_entry> g_handle_pool;  // 0-based; handle id = index + 1
static constexpr int             HANDLE_INVALID = 0;

static int allocate_handle(hexagon_chunked_state * st) {
    std::lock_guard<std::mutex> lock(g_handle_mutex);
    // Reuse a free slot first.
    for (size_t i = 0; i < g_handle_pool.size(); i++) {
        if (!g_handle_pool[i].in_use) {
            g_handle_pool[i].state = st;
            g_handle_pool[i].slot_indices.clear();
            g_handle_pool[i].remapped.clear();
            g_handle_pool[i].in_use = true;
            return (int)(i + 1);
        }
    }
    // Append a new entry.
    batch_handle_entry e;
    e.state = st;
    e.in_use = true;
    g_handle_pool.push_back(std::move(e));
    return (int)g_handle_pool.size();
}

static batch_handle_entry * lookup_handle(int handle) {
    if (handle <= 0) {
        return nullptr;
    }
    size_t idx = (size_t)(handle - 1);
    std::lock_guard<std::mutex> lock(g_handle_mutex);
    if (idx >= g_handle_pool.size()) {
        return nullptr;
    }
    if (!g_handle_pool[idx].in_use) {
        return nullptr;
    }
    return &g_handle_pool[idx];
}

static void free_handle(int handle) {
    if (handle <= 0) {
        return;
    }
    size_t idx = (size_t)(handle - 1);
    std::lock_guard<std::mutex> lock(g_handle_mutex);
    if (idx >= g_handle_pool.size()) {
        return;
    }
    g_handle_pool[idx].in_use = false;
    g_handle_pool[idx].slot_indices.clear();
    g_handle_pool[idx].remapped.clear();
    g_handle_pool[idx].state = nullptr;
}

// ----------------------------------------------------------------------------
// Tensor lookup by name. Returns (layer_idx, intra_slot_offset) via out
// params; returns false if the name is not in the index (e.g. it is a
// permanent tensor or a non-bucketed name).
//
// Lookup is a linear scan over each layer's tensor list. For 9B with
// ~100 tensors per layer the per-call cost is tiny and the cgraph walk
// is per-batch, so we skip the unordered_map<std::string> overhead.
// ----------------------------------------------------------------------------
struct tensor_lookup {
    int    layer_idx;
    size_t intra_slot_offset;
};
[[maybe_unused]] static bool find_tensor_in_layer_index(
        const hexagon_chunked_state * st,
        const char * name,
        tensor_lookup & out) {
    for (int li = 0; li < (int)st->layer_index.size(); li++) {
        for (const auto & t : st->layer_index[li].tensors) {
            if (t.name != nullptr && std::strcmp(t.name, name) == 0) {
                out.layer_idx = li;
                out.intra_slot_offset = t.intra_slot_offset;
                return true;
            }
        }
    }
    return false;
}

// ----------------------------------------------------------------------------
// Internal helpers (all assume slot_mutex is held by caller unless noted).
// ----------------------------------------------------------------------------
static int find_empty_slot_locked(hexagon_chunked_state * st) {
    for (int i = 0; i < st->n_slots; i++) {
        if (st->slots[i].state == CHUNK_STATE_EMPTY) {
            return i;
        }
    }
    return -1;
}

// B-3: proper LRU. Among slots in READY state with refcount==0, return the
// one with the smallest last_use_seq (i.e. the longest idle). If there are
// multiple slots tied at seq=0 (uninitialised), returns the lowest index.
// Returns -1 if no evictable slot exists.
[[maybe_unused]] static int find_evictable_slot_locked(hexagon_chunked_state * st) {
    int best_idx   = -1;
    uint64_t best_seq = UINT64_MAX;
    for (int i = 0; i < st->n_slots; i++) {
        if (st->slots[i].state == CHUNK_STATE_READY && st->slots[i].refcount == 0) {
            if (st->slots[i].last_use_seq < best_seq) {
                best_seq = st->slots[i].last_use_seq;
                best_idx = i;
            }
        }
    }
    return best_idx;
}

// B-3: predicate used by the consumer to wait for "any slot becomes free
// or evictable". Returns true if at least one slot is EMPTY (free) or
// READY+refcount==0 (evictable). Used as the cv predicate when the
// consumer needs a slot but all are currently IN_USE or LOADING.
[[maybe_unused]] static bool has_free_or_evictable_slot_locked(hexagon_chunked_state * st) {
    for (int i = 0; i < st->n_slots; i++) {
        if (st->slots[i].state == CHUNK_STATE_EMPTY) {
            return true;
        }
        if (st->slots[i].state == CHUNK_STATE_READY && st->slots[i].refcount == 0) {
            return true;
        }
    }
    return false;
}

static const char * state_name(chunk_state s) {
    switch (s) {
        case CHUNK_STATE_EMPTY:   return "EMPTY";
        case CHUNK_STATE_LOADING: return "LOADING";
        case CHUNK_STATE_READY:   return "READY";
        case CHUNK_STATE_IN_USE:  return "IN_USE";
        default:                  return "?";
    }
}

// ----------------------------------------------------------------------------
// B-3 helper: identify a permanent-region tensor by name.
//
// Permanent tensors are not per-layer; they are loaded once at init and
// never streamed. Examples (covers all Qwen1.5 / Qwen3 / LLaMA3 / Gemma4
// models in the JZ CI set):
//   token_embd.weight      (vocab embedding)
//   output.weight           (lm-head; sometimes tied to token_embd)
//   output_norm.weight      (final RMSNorm)
//   rope_freqs.weight       (RoPE precomputed sin/cos table)
//
// Returns true if the name is permanent, false otherwise. The cgraph hook
// in B-4 calls this for every source tensor; permanent tensors are skipped
// (no slot needed, no producer request).
// ----------------------------------------------------------------------------
[[maybe_unused]] static bool is_permanent_tensor_name(const char * name) {
    if (name == nullptr) {
        return false;
    }
    // These prefixes cover the JZ test model set; new models may add more.
    // Keep the check order so the most specific prefixes are tried first.
    static const char * const PERMANENT_PREFIXES[] = {
        "token_embd.",
        "output.",
        "rope_freqs.",
        "rope_sin_cos.",   // alternate RoPE name in some gguf exports
        nullptr,
    };
    for (int i = 0; PERMANENT_PREFIXES[i] != nullptr; i++) {
        const char * p = PERMANENT_PREFIXES[i];
        size_t len     = std::strlen(p);
        if (std::strncmp(name, p, len) == 0) {
            return true;
        }
    }
    return false;
}

// ----------------------------------------------------------------------------
// B-5: load one layer from the gguf file into the slot's mempool region.
//
// Called by the producer thread with slot_mutex RELEASED. The slot's
// mempool_offset is set by request_and_wait_for_layer to
//   window_offset + slot_idx * slot_size_bytes
// and points at the start of this slot's region. Tensors in the layer
// are written contiguously in gguf tensor order, with a 128-byte
// alignment per tensor (mirrors the existing alloc_buffer logic so the
// DSP can address each tensor with the same offset arithmetic).
//
// Returns the number of bytes actually written; 0 on any I/O error
// (fseek / fread). The caller (producer thread) interprets 0 as a
// failed load and rolls the slot back to EMPTY.
//
// Threading: only the producer thread calls this function. No locking
// around the fread is required.
// ----------------------------------------------------------------------------
[[maybe_unused]] static size_t load_layer_to_slot(hexagon_chunked_state * st,
                                                  int slot_idx, int layer_idx) {
    if (st->gguf_file == nullptr || st->gguf_ctx == nullptr) {
        CHUNKED_LOG_ERROR("load_layer_to_slot: gguf not open (slot=%d layer=%d)",
                          slot_idx, layer_idx);
        return 0;
    }
    if (layer_idx < 0 || (size_t)layer_idx >= st->layer_index.size()) {
        CHUNKED_LOG_ERROR("load_layer_to_slot: layer %d out of range (max=%zu)",
                          layer_idx, st->layer_index.size());
        return 0;
    }
    const hexagon_chunked_state::layer_info & li = st->layer_index[layer_idx];
    if (li.total_size == 0) {
        CHUNKED_LOG_ERROR("load_layer_to_slot: layer %d has no tensors", layer_idx);
        return 0;
    }
    if (li.total_size > st->slot_size_bytes) {
        CHUNKED_LOG_ERROR("load_layer_to_slot: layer %d size %zu > slot %zu",
                          layer_idx, li.total_size, st->slot_size_bytes);
        return 0;
    }

    char * dst_base = (char *)st->mempool_base +
                      st->window_offset +
                      (size_t)slot_idx * st->slot_size_bytes;
    size_t cursor = 0;
    size_t total_written = 0;

    for (const auto & t : li.tensors) {
        // 128-byte aligned write pointer.
        size_t aligned_cursor = (cursor + 127u) & ~((size_t)127u);
        // Re-fseek per tensor so a partial fread on tensor N does not
        // corrupt the offset for tensor N+1 (fread may short-read on
        // disk pressure or large tensors).
        if (fseek(st->gguf_file, (long)(st->gguf_data_offset + t.gguf_offset), SEEK_SET) != 0) {
            CHUNKED_LOG_ERROR("load_layer_to_slot: fseek failed slot=%d layer=%d off=%zu",
                              slot_idx, layer_idx, t.gguf_offset);
            return 0;
        }
        char * dst = dst_base + aligned_cursor;
        size_t got = fread(dst, 1, t.size, st->gguf_file);
        if (got != t.size) {
            CHUNKED_LOG_ERROR("load_layer_to_slot: fread short slot=%d layer=%d "
                              "expected=%zu got=%zu",
                              slot_idx, layer_idx, t.size, got);
            return 0;
        }
        cursor         = aligned_cursor + t.size;
        total_written  = cursor;
    }
    return total_written;
}

// ----------------------------------------------------------------------------
// Producer thread body.
//
// Loop:
//   1. wait on slot_cv for shutdown OR non-empty request_queue
//   2. if shutdown: exit
//   3. pop slot index from request_queue
//   4. state must be EMPTY (consumer guaranteed this); if not, log and skip
//   5. mark state = LOADING, capture layer_idx from slot
//   6. B-5: real I/O - call load_layer_to_slot() to fread tensors into
//      the slot's mempool region
//   7. mark state = READY, record bytes_loaded, increment last_use_seq
//   8. notify_one (consumer may be waiting on this slot)
//
// The I/O is performed with slot_mutex RELEASED so a slow fread does
// not block the consumer's request evaluation. The shutdown re-check
// after the load (under the lock) handles deinit races.
// ----------------------------------------------------------------------------
static void producer_thread_fn(hexagon_chunked_state * st) {
    CHUNKED_LOG_ALWAYS("producer thread started (n_slots=%d, gguf=%s)",
                       st->n_slots, st->gguf_path);

    std::unique_lock<std::mutex> lock(*st->slot_mutex);
    while (true) {
        st->slot_cv->wait(lock, [st] {
            return st->shutdown.load(std::memory_order_acquire) ||
                   !st->request_queue.empty();
        });

        if (st->shutdown.load(std::memory_order_acquire)) {
            CHUNKED_LOG_ALWAYS("producer thread exit (shutdown)");
            return;
        }

        int slot_idx = st->request_queue.front();
        st->request_queue.pop_front();

        chunk_slot & slot = st->slots[slot_idx];
        if (slot.state != CHUNK_STATE_EMPTY) {
            // Should not happen: the consumer (hook) must claim an EMPTY
            // slot before enqueuing. If it does, log and skip.
            CHUNKED_LOG_ERROR("slot %d state=%s in request queue (expected EMPTY), skip",
                              slot_idx, state_name(slot.state));
            continue;
        }
        int layer_idx = slot.layer_idx;
        slot.state    = CHUNK_STATE_LOADING;
        st->stat_loads_started++;
        lock.unlock();

        // B-5: real fseek + fread from the gguf file into the slot's
        // mempool region. Runs with the slot_mutex released; the slot
        // is in LOADING state so the consumer (request_and_wait_for_layer)
        // is blocked on slot_cv waiting for READY.
        size_t bytes_written = load_layer_to_slot(st, slot_idx, layer_idx);
        bool load_ok = (bytes_written > 0);

        lock.lock();
        // Re-check shutdown: if the user is unloading the model mid-load
        // we drop the bytes and put the slot back to EMPTY.
        if (st->shutdown.load(std::memory_order_acquire)) {
            slot.state    = CHUNK_STATE_EMPTY;
            slot.layer_idx = -1;
            slot.bytes_loaded = 0;
            CHUNKED_LOG_ALWAYS("producer thread exit mid-load (slot %d for layer %d)",
                               slot_idx, layer_idx);
            return;
        }
        if (!load_ok) {
            // Load failed. Roll the slot back to EMPTY so a later
            // request can retry (with possibly a different layer if
            // the issue is layer-specific). The stat counter is
            // incremented for visibility.
            slot.state    = CHUNK_STATE_EMPTY;
            slot.layer_idx = -1;
            slot.bytes_loaded = 0;
            st->stat_loads_failed++;
            CHUNKED_LOG_ERROR("producer: load failed slot=%d layer=%d, slot back to EMPTY",
                              slot_idx, layer_idx);
            // No notify_one: the consumer is still waiting on this
            // slot's specific READY transition; it will time out via
            // the outer shutdown signal or be retried after deinit.
            continue;
        }
        slot.state         = CHUNK_STATE_READY;
        slot.bytes_loaded  = bytes_written;
        slot.last_use_seq  = ++st->lru_seq;
        st->stat_loads_completed++;
        CHUNKED_LOG_ALWAYS("slot %d READY (layer=%d, %zu bytes, seq=%lu)",
                           slot_idx, layer_idx, slot.bytes_loaded,
                           (unsigned long)slot.last_use_seq);
        lock.unlock();

        // Wake exactly one consumer that may be waiting on this slot.
        // (cv.notify_all is overkill; the consumer is a single thread.)
        st->slot_cv->notify_one();
        lock.lock();
    }
}

// ----------------------------------------------------------------------------
// B-5: open the gguf, walk all tensors, and group them by layer_idx.
//
// The gguf is opened with no_alloc=true (metadata only); we never
// allocate ggml_tensor structs because the chunked module does not need
// them - we only need the (offset, size) tuple per tensor for fread.
//
// For each tensor:
//   - if name matches "blk.N.XXX":  append to layer_index[N]
//   - if name is a permanent tensor (token_embd, output, rope_freqs):
//     skip (loaded by alloc_buffer into the permanent region)
//   - else: log once and skip (cgraph walk will not request it either)
//
// After the walk, validates that max_layer_size <= slot_size_bytes; if
// not, returns a negative error code so init can decide to abort
// (Qwen3.5-9B single-layer is ~130 MB which fits a 256 MB slot, but a
// 32 MB slot on a model with 200 MB per layer would fail here).
//
// On any failure, cleans up gguf_ctx / gguf_file and returns a negative
// code. The init caller will mark init_done=false so the hook becomes
// a no-op.
// ----------------------------------------------------------------------------
[[maybe_unused]] static int build_layer_index(hexagon_chunked_state * st) {
    // Suppress designated-initializer warning; gguf_init_params uses them.
#if defined(__GNUC__) || defined(__clang__)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wc++20-designator"
#endif
    struct gguf_init_params params = { .no_alloc = true, .ctx = nullptr };
#if defined(__GNUC__) || defined(__clang__)
#pragma GCC diagnostic pop
#endif

    st->gguf_ctx = gguf_init_from_file(st->gguf_path, params);
    if (st->gguf_ctx == nullptr) {
        CHUNKED_LOG_ERROR("build_layer_index: gguf_init_from_file failed for %s",
                          st->gguf_path);
        return -1;
    }
    st->gguf_file = fopen(st->gguf_path, "rb");
    if (st->gguf_file == nullptr) {
        CHUNKED_LOG_ERROR("build_layer_index: fopen failed for %s", st->gguf_path);
        gguf_free(st->gguf_ctx);
        st->gguf_ctx = nullptr;
        return -2;
    }
    st->gguf_data_offset = gguf_get_data_offset(st->gguf_ctx);

    const int64_t n_tensors = gguf_get_n_tensors(st->gguf_ctx);
    CHUNKED_LOG_ALWAYS("build_layer_index: gguf=%s n_tensors=%lld data_offset=%zu",
                       st->gguf_path, (long long)n_tensors, st->gguf_data_offset);

    // Index layers 0..N (size = max_layers+1 so layer_idx can be used
    // directly). max_layers comes from cfg; if a tensor references a
    // higher layer, we extend the index.
    st->layer_index.clear();
    st->layer_index.resize((size_t)256);  // start with 256; resize up if needed
    for (int i = 0; i < (int)st->layer_index.size(); i++) {
        st->layer_index[i].total_size = 0;
    }

    int n_permanent = 0;
    int n_unknown   = 0;
    int n_layer_tensors = 0;
    size_t max_layer_size = 0;
    int    max_layer_idx_seen = -1;

    for (int64_t i = 0; i < n_tensors; i++) {
        const char * name = gguf_get_tensor_name(st->gguf_ctx, i);
        size_t       off  = gguf_get_tensor_offset(st->gguf_ctx, i);
        size_t       sz   = gguf_get_tensor_size(st->gguf_ctx, i);

        if (name == nullptr) {
            CHUNKED_LOG_ERROR("build_layer_index: tensor %lld has null name",
                              (long long)i);
            n_unknown++;
            continue;
        }
        if (is_permanent_tensor_name(name)) {
            n_permanent++;
            continue;
        }
        int layer_idx = parse_layer_index(name);
        if (layer_idx < 0) {
            // Not a layer-scoped tensor and not a known permanent
            // tensor. Could be a per-model scratch tensor or a name
            // pattern we don't recognize. Skip it: cgraph walk will
            // also skip non-blk.N. names, so the inference path will
            // never request it from us.
            n_unknown++;
            continue;
        }
        // Resize the index if the model has more layers than the
        // initial guess.
        if ((size_t)layer_idx >= st->layer_index.size()) {
            size_t new_size = (size_t)layer_idx + 1;
            st->layer_index.resize(new_size);
            for (size_t k = st->layer_index.size(); k < new_size; k++) {
                st->layer_index[k].total_size = 0;
            }
        }
        hexagon_chunked_state::layer_tensor t;
        t.name         = name;  // gguf-owned; valid until gguf_free
        t.gguf_offset  = off;
        t.size         = sz;
        // intra_slot_offset is filled in the second pass below so the
        // per-tensor offsets are the actual write positions the producer
        // will use (128-byte aligned, sequential).
        st->layer_index[layer_idx].tensors.push_back(t);
        st->layer_index[layer_idx].total_size += sz;
        if (st->layer_index[layer_idx].total_size > max_layer_size) {
            max_layer_size = st->layer_index[layer_idx].total_size;
        }
        if (layer_idx > max_layer_idx_seen) {
            max_layer_idx_seen = layer_idx;
        }
        n_layer_tensors++;
    }

    // Second pass: compute intra_slot_offset per layer. Tensors are
    // written by the producer in gguf tensor order (which is the order
    // we just appended them in). 128-byte alignment matches the
    // existing alloc_buffer padding in jz.cpp so the DSP can address
    // each tensor with the same offset arithmetic.
    for (int li = 0; li < (int)st->layer_index.size(); li++) {
        size_t cursor = 0;
        for (auto & t : st->layer_index[li].tensors) {
            size_t aligned_cursor = (cursor + 127u) & ~((size_t)127u);
            t.intra_slot_offset = aligned_cursor;
            cursor = aligned_cursor + t.size;
        }
    }

    // Shrink the index to (max_layer_idx_seen + 1) so iteration in
    // acquire_for_cgraph is bounded. Empty trailing layers are kept
    // (zero-sized) up to max_layer_idx_seen to keep the layout simple.
    if (max_layer_idx_seen + 1 < (int)st->layer_index.size()) {
        st->layer_index.resize((size_t)max_layer_idx_seen + 1);
    }

    CHUNKED_LOG_ALWAYS("build_layer_index: %lld tensors -> %d layer tensors, "
                       "%d permanent, %d unknown, max_layer_size=%zu MB, max_layer_idx=%d",
                       (long long)n_tensors, n_layer_tensors, n_permanent, n_unknown,
                       max_layer_size / (1u << 20), max_layer_idx_seen);

    if (max_layer_size > st->slot_size_bytes) {
        CHUNKED_LOG_ERROR("build_layer_index: max layer size %zu > slot size %zu "
                          "(increase chunked_slot_mb)",
                          max_layer_size, st->slot_size_bytes);
        fclose(st->gguf_file);
        gguf_free(st->gguf_ctx);
        st->gguf_file = nullptr;
        st->gguf_ctx = nullptr;
        return -3;
    }
    return 0;
}

// ----------------------------------------------------------------------------
// ggmlhexagon_chunked_init
// ----------------------------------------------------------------------------
int ggmlhexagon_chunked_init(hexagon_chunked_state ** out_state,
                             const hexagon_chunked_config * cfg) {
    if (out_state == nullptr) {
        return -1;
    }
    *out_state = nullptr;

    if (cfg == nullptr) {
        CHUNKED_LOG_ERROR("cfg is null; cannot init");
        return -2;
    }
    if (cfg->gguf_path == nullptr || cfg->gguf_path[0] == '\0') {
        CHUNKED_LOG_ERROR("chunked_gguf_path is empty; cannot init");
        return -3;
    }
    if (cfg->window_mb <= 0) {
        CHUNKED_LOG_ERROR("chunked_window_mb=%d must be > 0", cfg->window_mb);
        return -4;
    }
    if (cfg->slot_mb <= 0 || cfg->slot_mb > cfg->window_mb) {
        CHUNKED_LOG_ERROR("chunked_slot_mb=%d invalid (window=%d MB)",
                          cfg->slot_mb, cfg->window_mb);
        return -5;
    }

    auto * st = new (std::nothrow) hexagon_chunked_state();
    if (st == nullptr) {
        CHUNKED_LOG_ERROR("alloc hexagon_chunked_state failed");
        return -6;
    }
    std::memset(st, 0, sizeof(*st));

    st->permanent_size  = (size_t)cfg->permanent_mb  * (1u << 20);
    st->kv_cache_size   = (size_t)cfg->kv_cache_mb   * (1u << 20);
    st->slot_size_bytes = (size_t)cfg->slot_mb       * (1u << 20);
    st->window_size     = (size_t)cfg->window_mb     * (1u << 20);

    st->n_slots = (int)(st->window_size / st->slot_size_bytes);
    if (st->n_slots < 2) {
        CHUNKED_LOG_ERROR("n_slots=%d < 2 (window=%zu MB, slot=%d MB); increase chunked_window_mb or reduce chunked_slot_mb",
                          st->n_slots,
                          st->window_size / (1u << 20),
                          cfg->slot_mb);
        delete st;
        return -7;
    }

    std::snprintf(st->gguf_path, sizeof(st->gguf_path), "%s", cfg->gguf_path);

    // B-2: allocate the synchronization primitives + slot table.
    st->slot_mutex = new (std::nothrow) std::mutex();
    st->slot_cv    = new (std::nothrow) std::condition_variable();
    if (st->slot_mutex == nullptr || st->slot_cv == nullptr) {
        CHUNKED_LOG_ERROR("alloc mutex/cv failed");
        delete st->slot_mutex;
        delete st->slot_cv;
        delete st;
        return -8;
    }

    st->slots.resize(st->n_slots);
    for (int i = 0; i < st->n_slots; i++) {
        st->slots[i].state          = CHUNK_STATE_EMPTY;
        st->slots[i].layer_idx      = -1;
        st->slots[i].mempool_offset = 0;  // set by ensure_layers once mempool is bound
        st->slots[i].bytes_loaded   = 0;
        st->slots[i].last_use_seq   = 0;
        st->slots[i].refcount       = 0;
    }

    st->lru_seq       = 0;
    st->shutdown      = false;
    st->mempool_bound = false;
    st->mempool_base  = nullptr;
    st->mempool_len   = 0;

    st->window_offset = 0;
    st->init_done     = true;

    // B-5: open the gguf and build the per-layer tensor index. This
    // also validates that max_layer_size <= slot_size_bytes; if not,
    // chunked streaming cannot be used for this model + slot
    // combination and we abort init.
    {
        int rc = build_layer_index(st);
        if (rc != 0) {
            CHUNKED_LOG_ERROR("init: build_layer_index failed rc=%d, chunked streaming disabled", rc);
            delete st->slot_mutex;
            delete st->slot_cv;
            delete st;
            return -10;
        }
    }

    // B-2: start the producer thread.
    st->producer_thread = new (std::nothrow) std::thread(producer_thread_fn, st);
    if (st->producer_thread == nullptr) {
        CHUNKED_LOG_ERROR("alloc producer_thread failed");
        if (st->gguf_file) fclose(st->gguf_file);
        if (st->gguf_ctx)  gguf_free(st->gguf_ctx);
        delete st->slot_mutex;
        delete st->slot_cv;
        delete st;
        return -9;
    }

    CHUNKED_LOG_ALWAYS("init: gguf=%s window=%d MB slot=%d MB n_slots=%d permanent=%d MB kv_cache=%d MB max_layers=%d",
                       st->gguf_path,
                       cfg->window_mb,
                       cfg->slot_mb,
                       st->n_slots,
                       cfg->permanent_mb,
                       cfg->kv_cache_mb,
                       cfg->max_layers);

    *out_state = st;
    return 0;
}

// ----------------------------------------------------------------------------
// ggmlhexagon_chunked_deinit
// ----------------------------------------------------------------------------
void ggmlhexagon_chunked_deinit(hexagon_chunked_state ** out_state) {
    if (out_state == nullptr || *out_state == nullptr) {
        return;
    }
    auto * st = *out_state;
    if (!st->init_done) {
        // init_done guards the deinit-from-failed-init case.
        delete st;
        *out_state = nullptr;
        return;
    }

    // Detect outstanding handles: if a graph_compute_batch is mid-flight
    // and the caller races deinit, those handles reference this state
    // (now shutting down) and will dangle. We log it but do not crash;
    // the release_slot path will see shutdown=true and bail.
    {
        std::lock_guard<std::mutex> lock(g_handle_mutex);
        int outstanding = 0;
        for (const auto & e : g_handle_pool) {
            if (e.in_use && e.state == st) {
                outstanding++;
            }
        }
        if (outstanding > 0) {
            CHUNKED_LOG_ERROR("deinit: %d outstanding handle(s) still reference this state",
                              outstanding);
        }
    }

    CHUNKED_LOG_ALWAYS("deinit: gguf=%s n_slots=%d loads_started=%lu loads_completed=%lu loads_failed=%lu waits=%lu",
                       st->gguf_path, st->n_slots,
                       (unsigned long)st->stat_loads_started,
                       (unsigned long)st->stat_loads_completed,
                       (unsigned long)st->stat_loads_failed,
                       (unsigned long)st->stat_waits);

    // Stop producer thread.
    if (st->producer_thread != nullptr) {
        {
            std::lock_guard<std::mutex> lock(*st->slot_mutex);
            st->shutdown.store(true, std::memory_order_release);
        }
        st->slot_cv->notify_all();
        st->producer_thread->join();
        delete st->producer_thread;
        st->producer_thread = nullptr;
    }

    // B-5: close the gguf file and free the gguf context. The producer
    // thread is already joined so no concurrent fread is possible.
    if (st->gguf_file != nullptr) {
        fclose(st->gguf_file);
        st->gguf_file = nullptr;
    }
    if (st->gguf_ctx != nullptr) {
        gguf_free(st->gguf_ctx);
        st->gguf_ctx = nullptr;
    }
    st->layer_index.clear();
    st->layer_index.shrink_to_fit();

    delete st->slot_cv;
    delete st->slot_mutex;
    st->slots.clear();
    st->slots.shrink_to_fit();

    delete st;
    *out_state = nullptr;
}

// ----------------------------------------------------------------------------
// Internal: request a slot for the given layer_idx and wait until it is READY.
//
// Returns the slot index on success; -1 on shutdown. refcount is incremented
// (atomically with respect to the lock) before returning so the slot will
// not be evicted while the consumer is using it.
//
// B-3: if all slots are IN_USE (no EMPTY, no READY+refcount==0), the
// consumer waits on slot_cv for the predicate has_free_or_evictable_slot.
// The release_slot path notifies slot_cv when a slot becomes free, so
// the consumer wakes up and re-evaluates. This is the only place where
// the consumer can block beyond the slot's own LOADING -> READY wait.
//
// LRU: when multiple slots are READY+refcount==0, the longest-idle
// (smallest last_use_seq) is chosen. See find_evictable_slot_locked.
// ----------------------------------------------------------------------------
[[maybe_unused]] static int request_and_wait_for_layer(hexagon_chunked_state * st, int layer_idx) {
    std::unique_lock<std::mutex> lock(*st->slot_mutex);

    // 1. Is a slot already READY for this layer? Claim it (refcount++).
    for (int i = 0; i < st->n_slots; i++) {
        if (st->slots[i].state == CHUNK_STATE_READY &&
            st->slots[i].layer_idx == layer_idx &&
            st->slots[i].refcount == 0) {
            st->slots[i].refcount = 1;
            st->slots[i].last_use_seq = ++st->lru_seq;
            CHUNKED_LOG_ALWAYS("hit slot %d for layer %d (seq=%lu)",
                               i, layer_idx, (unsigned long)st->slots[i].last_use_seq);
            return i;
        }
    }

    // 2. Find an EMPTY slot, or an evictable (READY, refcount=0) slot.
    int slot_idx = find_empty_slot_locked(st);
    if (slot_idx < 0) {
        slot_idx = find_evictable_slot_locked(st);
        if (slot_idx >= 0) {
            CHUNKED_LOG_ALWAYS("evict slot %d (was layer=%d) for layer %d",
                               slot_idx, st->slots[slot_idx].layer_idx, layer_idx);
            st->slots[slot_idx].state         = CHUNK_STATE_EMPTY;
            st->slots[slot_idx].layer_idx     = -1;
            st->slots[slot_idx].bytes_loaded  = 0;
        }
    }
    if (slot_idx < 0) {
        // B-3: wait for an IN_USE slot to free up rather than failing
        // immediately. This handles the case where a previous cgraph
        // batch is still holding slots open. release_slot will notify
        // slot_cv when refcount drops to 0.
        CHUNKED_LOG_ALWAYS("waiting for free slot for layer %d (all %d slots IN_USE/LOADING)",
                           layer_idx, st->n_slots);
        st->slot_cv->wait(lock, [st] {
            return st->shutdown.load(std::memory_order_acquire) ||
                   has_free_or_evictable_slot_locked(st);
        });
        if (st->shutdown.load(std::memory_order_acquire)) {
            CHUNKED_LOG_ALWAYS("request cancelled (shutdown) while waiting for free slot");
            return -1;
        }
        // Re-evaluate after wakeup.
        slot_idx = find_empty_slot_locked(st);
        if (slot_idx < 0) {
            slot_idx = find_evictable_slot_locked(st);
            if (slot_idx >= 0) {
                CHUNKED_LOG_ALWAYS("evict slot %d (was layer=%d) for layer %d (after wait)",
                                   slot_idx, st->slots[slot_idx].layer_idx, layer_idx);
                st->slots[slot_idx].state         = CHUNK_STATE_EMPTY;
                st->slots[slot_idx].layer_idx     = -1;
                st->slots[slot_idx].bytes_loaded  = 0;
            }
        }
        if (slot_idx < 0) {
            // Spurious wakeup or some other state. Fail gracefully.
            CHUNKED_LOG_ERROR("spurious wakeup, still no slot for layer %d", layer_idx);
            return -1;
        }
    }

    // 3. Claim the slot, mark it as needing a load, push to producer queue.
    chunk_slot & slot = st->slots[slot_idx];
    slot.layer_idx      = layer_idx;
    slot.state          = CHUNK_STATE_EMPTY;  // producer will flip to LOADING
    slot.mempool_offset = (size_t)slot_idx * st->slot_size_bytes;
    slot.last_use_seq   = ++st->lru_seq;
    slot.refcount       = 0;  // producer will eventually set state=READY, then we refcount++

    st->request_queue.push_back(slot_idx);
    st->stat_waits++;
    CHUNKED_LOG_ALWAYS("enqueue slot %d for layer %d (queue size=%zu)",
                       slot_idx, layer_idx, st->request_queue.size());

    // 4. Wake producer and wait for state==READY (or shutdown).
    st->slot_cv->notify_one();
    st->slot_cv->wait(lock, [st, slot_idx] {
        return st->shutdown.load(std::memory_order_acquire) ||
               st->slots[slot_idx].state == CHUNK_STATE_READY;
    });

    if (st->shutdown.load(std::memory_order_acquire)) {
        CHUNKED_LOG_ALWAYS("request cancelled (shutdown) for slot %d layer %d",
                           slot_idx, layer_idx);
        return -1;
    }

    // 5. Mark IN_USE so the producer cannot evict while we are reading.
    slot.state    = CHUNK_STATE_IN_USE;
    slot.refcount = 1;
    CHUNKED_LOG_ALWAYS("slot %d IN_USE (layer=%d, %zu bytes)",
                       slot_idx, layer_idx, slot.bytes_loaded);
    return slot_idx;
}

// ----------------------------------------------------------------------------
// Internal: release a slot (refcount--, flip IN_USE -> READY if last).
//
// B-3: when the slot transitions IN_USE -> READY, notify slot_cv so any
// consumer waiting for a free slot (in request_and_wait_for_layer step 2)
// wakes up and re-evaluates.
// ----------------------------------------------------------------------------
[[maybe_unused]] static void release_slot(hexagon_chunked_state * st, int slot_idx) {
    if (slot_idx < 0 || slot_idx >= st->n_slots) {
        return;
    }
    std::unique_lock<std::mutex> lock(*st->slot_mutex);
    chunk_slot & slot = st->slots[slot_idx];
    if (slot.state != CHUNK_STATE_IN_USE) {
        CHUNKED_LOG_ERROR("release_slot: slot %d state=%s (expected IN_USE), skip",
                          slot_idx, state_name(slot.state));
        return;
    }
    if (slot.refcount <= 0) {
        CHUNKED_LOG_ERROR("release_slot: slot %d refcount=%d <= 0, skip",
                          slot_idx, slot.refcount);
        return;
    }
    slot.refcount -= 1;
    bool freed = false;
    if (slot.refcount == 0) {
        slot.state = CHUNK_STATE_READY;
        slot.last_use_seq = ++st->lru_seq;
        freed = true;
        CHUNKED_LOG_ALWAYS("slot %d -> READY (layer=%d, seq=%lu)",
                           slot_idx, slot.layer_idx, (unsigned long)slot.last_use_seq);
    }
    // If the slot just became free, drop the lock before notifying to
    // avoid the notified thread immediately blocking on the lock we are
    // still holding.
    if (freed) {
        lock.unlock();
        st->slot_cv->notify_one();
    }
}

// ----------------------------------------------------------------------------
// B-2 helper: parse a tensor name like "blk.31.attn_q.weight" -> 31.
// Returns -1 if the name does not match the layer pattern (permanent region).
// ----------------------------------------------------------------------------
[[maybe_unused]] static int parse_layer_index(const char * name) {
    if (name == nullptr) {
        return -1;
    }
    static const char PREFIX[] = "blk.";
    if (std::strncmp(name, PREFIX, 4) != 0) {
        return -1;
    }
    int n = 0;
    bool any = false;
    for (const char * p = name + 4; *p >= '0' && *p <= '9'; p++) {
        n = n * 10 + (*p - '0');
        any = true;
    }
    return any ? n : -1;
}

// ----------------------------------------------------------------------------
// Internal: lazy-bind the JZ mempool on first call.
//
// Computes the sliding window offset as
//   head_reserve + permanent_size + kv_cache_size
// matching the layout in section 2.6.3 of the design doc. The chunked module
// only consumes its own window; permanent and kv_cache regions are managed
// by the JZ init / alloc_buffer paths. The mempool base/len are pulled from
// jz.cpp via the ggmlhexagon_jz_get_mempool_info helper, which avoids a
// brittle struct-mirror hack.
// ----------------------------------------------------------------------------
[[maybe_unused]] static void lazy_bind_mempool(hexagon_chunked_state * st, void * ctx) {
    if (st->mempool_bound) {
        return;
    }
    void * base = nullptr;
    size_t len  = 0;
    ggmlhexagon_jz_get_mempool_info(ctx, &base, &len);
    if (base == nullptr || len == 0) {
        CHUNKED_LOG_ERROR("lazy_bind_mempool: jz mempool not available "
                          "(base=%p len=%zu)", base, len);
        return;
    }
    st->mempool_base = base;
    st->mempool_len  = len;

    const size_t head_reserve = 8u * (1u << 20);
    st->window_offset = head_reserve + st->permanent_size + st->kv_cache_size;
    if (st->window_offset + st->window_size > st->mempool_len) {
        CHUNKED_LOG_ERROR("mempool too small for sliding window: "
                          "window_offset=%zu + window_size=%zu > mempool_len=%zu",
                          st->window_offset, st->window_size, st->mempool_len);
        st->init_done = false;
        return;
    }
    for (int i = 0; i < st->n_slots; i++) {
        st->slots[i].mempool_offset = st->window_offset +
                                      (size_t)i * st->slot_size_bytes;
    }
    st->mempool_bound = true;
    CHUNKED_LOG_ALWAYS("mempool bound: base=%p len=%zu MB window_offset=%zu MB "
                       "window_size=%zu MB n_slots=%d",
                       st->mempool_base, st->mempool_len / (1u << 20),
                       st->window_offset / (1u << 20),
                       st->window_size / (1u << 20), st->n_slots);
}

// ----------------------------------------------------------------------------
// Internal: collect the unique layer indices referenced by a cgraph.
//
// Walks cgraph->nodes[*]->src[0..GGML_MAX_SRC-1], parses the layer index
// from each source tensor's name (pattern "blk.N...."), and adds each new
// layer to `out_layers`. Permanent-region tensors (token_embd, output,
// rope_freqs) are skipped. A name that does not match the blk.N. pattern
// is also skipped; this covers non-layer scratch tensors (KV cache,
// activations) and any model-specific names not in the block pattern.
//
// Returned set is in the order layers are first seen, which is the order
// cgraph ops walk the graph. This is the same order the producer sees
// requests in, so a layer that is only referenced by a single later op
// may not be a slot hit in this batch; the producer will still be able
// to load it on demand.
// ----------------------------------------------------------------------------
[[maybe_unused]] static void collect_layers_from_cgraph(struct ggml_cgraph * cgraph,
                                                       std::set<int> & out_layers) {
    out_layers.clear();
    if (cgraph == nullptr) {
        return;
    }
    for (int i = 0; i < cgraph->n_nodes; i++) {
        struct ggml_tensor * node = cgraph->nodes[i];
        if (node == nullptr) {
            continue;
        }
        // Walk all source tensors of the op. The block weight tensor is
        // almost always src[0] for MUL_MAT, but FLASH_ATTN_EXT, RMS_NORM,
        // ROPE etc. may carry it on other slots; checking all of them is
        // safer than assuming the convention.
        for (int s = 0; s < GGML_MAX_SRC; s++) {
            struct ggml_tensor * src = node->src[s];
            if (src == nullptr) {
                continue;
            }
            if (is_permanent_tensor_name(src->name)) {
                continue;
            }
            int layer_idx = parse_layer_index(src->name);
            if (layer_idx < 0) {
                continue;
            }
            out_layers.insert(layer_idx);
        }
        // Also parse the dst tensor name: a layer-scoped dst (e.g. an
        // attention output) still belongs to that layer. This catches
        // fusion / view ops where the dst name carries the layer tag.
        if (node->name[0] != '\0' && !is_permanent_tensor_name(node->name)) {
            int layer_idx = parse_layer_index(node->name);
            if (layer_idx >= 0) {
                out_layers.insert(layer_idx);
            }
        }
    }
}

// ----------------------------------------------------------------------------
// Internal: remap cgraph source tensors to their current slot offsets.
//
// Called from acquire_for_cgraph AFTER all slots for the batch have been
// claimed and the producer has flipped each slot to READY. For each
// acquired layer, walk the cgraph source tensors and any tensor whose
// name matches an entry in layer_index[layer] gets:
//   - its data pointer re-pointed to mempool_base + slot.mempool_offset
//     + tensor.intra_slot_offset
//   - the original pointer saved in the handle so release can restore it
//
// A tensor referenced from multiple ops in the same cgraph is only
// remapped once (the remap is idempotent and would overwrite itself);
// the handle's remapped list is a flat vector so release is O(N) over
// the unique set rather than over all cgraph src references.
//
// Permanent tensors (token_embd, output, rope_freqs) and unknown names
// are skipped: their data pointers were set by alloc_buffer and must
// NOT be remapped (the DSP still reads from the permanent region).
// ----------------------------------------------------------------------------
[[maybe_unused]] static void remap_tensors_in_cgraph(
        hexagon_chunked_state * st,
        struct ggml_cgraph * cgraph,
        const std::set<int> & acquired_layers,
        batch_handle_entry * entry) {
    if (cgraph == nullptr || entry == nullptr || acquired_layers.empty()) {
        return;
    }
    // Quick membership test for "was this layer acquired this batch".
    auto is_acquired = [&acquired_layers](int li) {
        return acquired_layers.count(li) > 0;
    };
    for (int i = 0; i < cgraph->n_nodes; i++) {
        struct ggml_tensor * node = cgraph->nodes[i];
        if (node == nullptr) {
            continue;
        }
        for (int s = 0; s < GGML_MAX_SRC; s++) {
            struct ggml_tensor * src = node->src[s];
            if (src == nullptr || src->name[0] == '\0') {
                continue;
            }
            // Cheap skip for non-layer names; the full lookup is the
            // name->layer_index scan below.
            int src_layer = parse_layer_index(src->name);
            if (src_layer < 0 || !is_acquired(src_layer)) {
                continue;
            }
            // Verify the tensor is actually part of the layer's index
            // (defensive: a tensor named "blk.5.X" might not be in the
            // model at all, e.g. a custom head we did not know to skip).
            tensor_lookup tlu;
            if (!find_tensor_in_layer_index(st, src->name, tlu)) {
                continue;
            }
            // Find which slot holds src_layer in this batch.
            int slot_idx = -1;
            for (int sidx : entry->slot_indices) {
                if (st->slots[sidx].layer_idx == src_layer) {
                    slot_idx = sidx;
                    break;
                }
            }
            if (slot_idx < 0) {
                continue;
            }
            void * new_data = (char *)st->mempool_base +
                              st->slots[slot_idx].mempool_offset +
                              tlu.intra_slot_offset;
            // Save original (usually NULL) and remap. Dedupe via a
            // linear scan of the existing remapped list (the list is
            // small; the alternative is a set<ggml_tensor*>).
            bool already = false;
            for (const auto & r : entry->remapped) {
                if (r.tensor == src) {
                    already = true;
                    break;
                }
            }
            if (!already) {
                remapped_tensor rt;
                rt.tensor    = src;
                rt.orig_data = src->data;
                entry->remapped.push_back(rt);
                src->data = new_data;
            }
        }
    }
}

// ----------------------------------------------------------------------------
// ggmlhexagon_chunked_acquire_for_cgraph
//
// B-4 entry point. Walks the cgraph to discover the unique set of layer
// indices referenced by this batch, then claims one slot per layer via
// request_and_wait_for_layer (which blocks the consumer until the producer
// has flipped the slot to READY). After slot acquisition, remaps each
// layer tensor's data pointer from its "no-mempool" sentinel (NULL) to
// the slot's mempool offset where the producer has just written the
// tensor bytes. Returns an opaque int handle on success; 0 means
// "nothing to do" or "acquire failed".
//
// The handle is consumed by ggmlhexagon_chunked_release at the end of the
// batch; calling release with handle=0 is a safe no-op. release restores
// each remapped tensor's data pointer to its saved original so a later
// acquire (or a layer eviction + reload) starts from a clean slate.
//
// Ordering: the call is invoked at the top of graph_compute_batch, BEFORE
// the cgraph cache lookup. The producer gets a head start on the first
// batch; on a cache hit the same wait still runs (cheap on cache hits
// because the slot is already READY for the same layer).
// ----------------------------------------------------------------------------
int ggmlhexagon_chunked_acquire_for_cgraph(struct hexagon_chunked_state * st,
                                           void * ctx, struct ggml_cgraph * cgraph) {
    if (st == nullptr || !st->init_done) {
        return HANDLE_INVALID;
    }
    if (ctx == nullptr) {
        CHUNKED_LOG_ERROR("ctx is null, cannot bind mempool");
        return HANDLE_INVALID;
    }

    // Lazy-bind the mempool on first call. Must succeed before any slot
    // can be used; the function leaves init_done=true on a too-small
    // mempool, so the cgraph walk below will just return empty.
    lazy_bind_mempool(st, ctx);
    if (!st->mempool_bound) {
        return HANDLE_INVALID;
    }

    // Walk the cgraph and collect the unique set of layer indices.
    std::set<int> layers;
    collect_layers_from_cgraph(cgraph, layers);
    if (layers.empty()) {
        // Nothing to stream (likely a KV-cache-only or all-permanent batch).
        return HANDLE_INVALID;
    }

    int handle = allocate_handle(st);
    if (handle <= 0) {
        CHUNKED_LOG_ERROR("allocate_handle failed (out of memory?)");
        return HANDLE_INVALID;
    }

    int acquired_count = 0;
    CHUNKED_LOG_ALWAYS("acquire: n_layers=%zu for cgraph n_nodes=%d",
                       layers.size(), cgraph ? cgraph->n_nodes : 0);
    for (int layer_idx : layers) {
        int slot_idx = request_and_wait_for_layer(st, layer_idx);
        if (slot_idx < 0) {
            // Shutdown or spurious wakeup. Roll back the slots we have
            // already claimed so a later acquire can start from a clean
            // slate.
            CHUNKED_LOG_ERROR("acquire failed for layer %d, rolling back %d slots",
                              layer_idx, acquired_count);
            for (int j = 0; j < acquired_count; j++) {
                release_slot(st, g_handle_pool[handle - 1].slot_indices[j]);
            }
            // Roll back any remapped tensors (acquire_for_cgraph only
            // remaps after this loop, so on the failure path no
            // remaps have happened yet; we just free the handle).
            free_handle(handle);
            return HANDLE_INVALID;
        }
        g_handle_pool[handle - 1].slot_indices.push_back(slot_idx);
        acquired_count++;
    }

    // All slots are READY. Remap the cgraph source tensors in this
    // batch to point at the slot region. Done OUTSIDE the slot lock
    // because it touches the tensor's data pointer (which the DSP
    // side does not read until compute begins). The remap is the
    // point at which the consumer (DSP) starts to see the streamed
    // layer weights.
    remap_tensors_in_cgraph(st, cgraph, layers, &g_handle_pool[handle - 1]);

    CHUNKED_LOG_ALWAYS("acquire OK: handle=%d n_slots=%d remapped=%zu "
                       "(total_loads=%lu completed=%lu)",
                       handle, acquired_count,
                       g_handle_pool[handle - 1].remapped.size(),
                       (unsigned long)st->stat_loads_started,
                       (unsigned long)st->stat_loads_completed);
    return handle;
}

// ----------------------------------------------------------------------------
// ggmlhexagon_chunked_release
//
// B-4 entry point. Restores every remapped tensor's data pointer to
// the value saved at acquire time, releases every slot that
// acquire_for_cgraph claimed, and frees the handle. Safe to call with
// handle=0 (no-op). Must be called exactly once per non-zero handle
// returned by acquire_for_cgraph.
//
// The restore step is critical: without it, after a slot is evicted
// and reused for a different layer, the evicted layer's tensors would
// still point at the slot's old contents (now overwritten by the new
// layer), causing silent data corruption.
// ----------------------------------------------------------------------------
void ggmlhexagon_chunked_release(int handle) {
    if (handle <= 0) {
        return;
    }
    batch_handle_entry * entry = lookup_handle(handle);
    if (entry == nullptr) {
        CHUNKED_LOG_ERROR("release: handle=%d is invalid (not in_use)", handle);
        return;
    }
    hexagon_chunked_state * st = entry->state;
    if (st == nullptr) {
        CHUNKED_LOG_ERROR("release: handle=%d has null state", handle);
        free_handle(handle);
        return;
    }
    // Restore remapped tensor data pointers first. We do this BEFORE
    // releasing the slots so a concurrent evict cannot overwrite a
    // tensor we are about to dereference (in practice the only reader
    // here is the same thread that called acquire, so the race is
    // theoretical; the order also makes the bug easier to repro if
    // it ever does occur).
    for (const auto & r : entry->remapped) {
        if (r.tensor != nullptr) {
            r.tensor->data = r.orig_data;
        }
    }
    for (size_t i = 0; i < entry->slot_indices.size(); i++) {
        release_slot(st, entry->slot_indices[i]);
    }
    CHUNKED_LOG_ALWAYS("release: handle=%d n_slots=%zu n_remapped=%zu",
                       handle, entry->slot_indices.size(),
                       entry->remapped.size());
    free_handle(handle);
}

// ----------------------------------------------------------------------------
// ggmlhexagon_chunked_classify_tensor
//
// Public helper for jz.cpp's alloc_buffer / init_tensor / set_tensor
// paths. Decides how a tensor is handled by the chunked module:
//   1 = permanent tensor (token_embd, output, rope_freqs); bump-alloc
//       in mempool as usual; NOT remapped at compute time
//   0 = layer tensor (blk.N.*); NOT bump-allocated; data = NULL until
//       acquire remaps it; freed back to NULL on release
//  -1 = unknown / defensive default; bump-alloc as usual
//
// The function is safe to call on a null name (returns -1) and does
// not depend on any chunked state being initialised, so jz.cpp can
// call it from the very first alloc_buffer call (well before
// ggmlhexagon_chunked_init runs).
// ----------------------------------------------------------------------------
int ggmlhexagon_chunked_classify_tensor(const char * name) {
    if (name == nullptr || name[0] == '\0') {
        return -1;
    }
    if (is_permanent_tensor_name(name)) {
        return 1;
    }
    if (parse_layer_index(name) >= 0) {
        return 0;
    }
    return -1;
}
