// ggmlhexagon_chunked.h
//
// JZ's chunked streaming producer-consumer module (Spike B).
//
// Design goal: support large models (e.g. Qwen3.5-9B Q4_0 = 5.1 GiB) whose
// weights cannot fit in the JZ single mempool (~4 GiB on 8 Elite / V79 due to
// 32-bit DSP VA limit). Producer thread reads chunks from a gguf file into
// mempool slots; consumer (DSP-side inference) waits for the chunk covering
// the layers it needs.
//
// Spike B scope (this header):
//   - hexagon_chunked_state struct: holds slot table, mutex, condvar, LRU
//     bookkeeping, gguf handle, producer thread handle. Implementation lives
//     in ggmlhexagon_chunked.cpp.
//   - ggmlhexagon_chunked_init() / ggmlhexagon_chunked_deinit(): lifecycle
//     hooks called from jz.cpp init_dsp / deinit path.
//   - ggmlhexagon_chunked_ensure_layers_for_cgraph(): hook called from
//     ggmlhexagon_backend_graph_compute_batch before the cgraph cache lookup;
//     waits until mempool has the layers referenced by the cgraph.
//
// Non-goals (out of Spike B scope):
//   - Actual gguf tensor I/O and per-layer group loading (added in B-5).
//
// All public symbols use the ggmlhexagon_chunked_* prefix to keep them
// discoverable in the JZ source tree and avoid name clashes with the existing
// ggml-hexagon-jz.cpp and QCOM (htp/) paths.
//
// Config is passed by value (not by reference to the JZ global) so this
// module does not depend on any jz.cpp internal symbol. This keeps the
// module testable in isolation and avoids making the JZ globals extern.

#pragma once

#include "ggml.h"
#include "ggml-cpp.h"
#include <cstddef>
#include <cstdint>

#ifdef __cplusplus
extern "C" {
#endif

// Opaque forward decl. The full definition is in ggmlhexagon_chunked.cpp
// and is only accessed via the API below. jz.cpp stores a pointer to this
// in ggml_backend_hexagon_context::chunked_state.
struct hexagon_chunked_state;

// Configuration for chunked streaming. Copied by value into the state
// struct at init time so the source can be freed (cfg) right after.
// All sizes are in MiB (matching the cfg file units) and converted to
// bytes inside the module.
struct hexagon_chunked_config {
    const char * gguf_path;          // absolute path to gguf, must outlive init call
    int          window_mb;          // sliding window size in MiB
    int          slot_mb;            // single slot size in MiB
    int          max_layers;         // preflight hint: max layer index in gguf
    int          permanent_mb;       // permanent region (embedding/lm-head/rope)
    int          kv_cache_mb;        // KV cache region reserved size
};

// Lifecycle: allocates the state struct, validates the cfg, computes the
// slot layout. Returns 0 on success. On any failure, *out_state is left
// NULL; the caller is expected to log the error and fall back to
// non-chunked operation. The state pointer stays valid until deinit.
int  ggmlhexagon_chunked_init(struct hexagon_chunked_state ** out_state,
                              const struct hexagon_chunked_config * cfg);

// Lifecycle: stops producer thread (if any), closes gguf, frees slot table.
// Safe to call with *out_state == NULL.
void ggmlhexagon_chunked_deinit(struct hexagon_chunked_state ** out_state);

// Mempool info helper exported by jz.cpp. Replaces the jz_ctx_min struct
// mirror hack: the chunked module calls this to obtain the JZ context's
// single mempool base + length without depending on the jz.cpp struct
// layout. Implemented in ggml-hexagon-jz.cpp.
void ggmlhexagon_jz_get_mempool_info(void * jz_ctx, void ** out_base, size_t * out_len);

// Per-batch slot tracking. B-4 needs the hook to (a) acquire slots for
// all needed layers, and (b) release them once the cgraph compute is
// done. The release happens in a separate call so the cgraph cache hit
// path can be optimised (a cache hit uses the same slots as the prior
// miss that populated them).
//
// B-4 entry: ggmlhexagon_chunked_acquire_for_cgraph() returns a handle
// (opaque int) that the caller passes to ggmlhexagon_chunked_release()
// after compute. The handle is 0 on failure.
int  ggmlhexagon_chunked_acquire_for_cgraph(struct hexagon_chunked_state * state,
                                            void * ctx, struct ggml_cgraph * cgraph);
void ggmlhexagon_chunked_release(int handle);

// Per-tensor classification used by jz.cpp's alloc_buffer / set_tensor
// paths to decide whether to bump-alloc a tensor in mempool. A "layer
// tensor" (blk.N.*) is loaded on demand by the producer; a "permanent
// tensor" (token_embd, output, rope_freqs) is loaded once at init.
// Returns:
//   1  = permanent tensor (skip from chunked streaming; bump-alloc as usual)
//   0  = layer tensor (skip bump-alloc; data remapped at acquire time)
//  -1  = unknown / non-classified (bump-alloc as usual, defensive default)
int  ggmlhexagon_chunked_classify_tensor(const char * name);

#ifdef __cplusplus
}
#endif
