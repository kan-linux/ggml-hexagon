/*
 * 2024-2026 The ggml authors
 *
 * this single-source-file is part of jz's ggml-hexagon
 *
 * GitHub:   - https://github.com/zhouwg/ggml-hexagon
 *
 * Quantized GET_ROWS: gather rows from a q4_K weight tensor and dequantize
 * them to f32 on the DSP. Hooked into entry.c dispatch table as jz_op_get_rows.
 * Falls back to Qualcomm's op_get_rows for f32 src0.
 */

#pragma clang diagnostic ignored "-Wunused-variable"
#pragma clang diagnostic ignored "-Wunused-function"
#pragma clang diagnostic ignored "-Wunused-but-set-variable"

#include <HAP_farf.h>
#include <HAP_perf.h>

#include <math.h>
#include <string.h>

#define GGML_COMMON_DECL_C
#include "ggml-common.h"
#include "htp-ctx.h"
#include "htp-ops.h"
#include "hvx-utils.h"

// ---------------------------------------------------------------------------
// fp16 -> fp32 helpers (from ggml-impl.h, kept local to avoid including it)
// ---------------------------------------------------------------------------
static inline float fp32_from_bits(uint32_t w) {
    union { uint32_t as_bits; float as_value; } fp32;
    fp32.as_bits = w;
    return fp32.as_value;
}

static inline uint32_t fp32_to_bits(float f) {
    union { float as_value; uint32_t as_bits; } fp32;
    fp32.as_value = f;
    return fp32.as_bits;
}

static inline float fp16_to_fp32(uint16_t h) {
    const uint32_t w = (uint32_t) h << 16;
    const uint32_t sign = w & 0x80000000u;
    const uint32_t two_w = w + w;

    const uint32_t exp_offset = 0xE0u << 23;
    const float exp_scale = 0x1.0p-112f;
    const float normalized_value = fp32_from_bits((two_w >> 4) + exp_offset) * exp_scale;

    const uint32_t magic_mask = 126u << 23;
    const float magic_bias = 0.5f;
    const float denormalized_value = fp32_from_bits((two_w >> 17) | magic_mask) - magic_bias;

    const uint32_t denormalized_cutoff = 1u << 27;
    const uint32_t result = sign |
        (two_w < denormalized_cutoff ? fp32_to_bits(denormalized_value) : fp32_to_bits(normalized_value));
    return fp32_from_bits(result);
}

// Unpack 6-bit scale/min pair for q4_K group j (from ggml-et/et-kernels/src/quants.h)
static inline void get_scale_min_k4(int j, const uint8_t * q, uint8_t * d, uint8_t * m) {
    if (j < 4) {
        *d = q[j] & 63;
        *m = q[j + 4] & 63;
    } else {
        *d = (q[j + 4] & 0xF) | ((q[j - 4] >> 6) << 4);
        *m = (q[j + 4] >> 4) | ((q[j] >> 6) << 4);
    }
}

// Scalar q4_K row dequantize, mirrors dequantize_row_q4_K() in ggml-quants.c
static void dequantize_row_q4_K_dsp(const block_q4_K * __restrict x, float * __restrict y, int64_t k) {
    const int nb = k / QK_K;
    for (int i = 0; i < nb; i++) {
        const uint8_t * q = x[i].qs;
        const float d   = fp16_to_fp32(x[i].d);
        const float min = fp16_to_fp32(x[i].dmin);
        int is = 0;
        uint8_t sc, m;
        for (int j = 0; j < QK_K; j += 64) {
            get_scale_min_k4(is + 0, x[i].scales, &sc, &m);
            const float d1 = d * sc; const float m1 = min * m;
            get_scale_min_k4(is + 1, x[i].scales, &sc, &m);
            const float d2 = d * sc; const float m2 = min * m;
            for (int l = 0; l < 32; ++l) *y++ = d1 * (q[l] & 0xF) - m1;
            for (int l = 0; l < 32; ++l) *y++ = d2 * (q[l] >> 4) - m2;
            q += 32; is += 2;
        }
    }
}

// ---------------------------------------------------------------------------
// Quantized GET_ROWS worker
// ---------------------------------------------------------------------------
struct get_rows_quant_context {
    struct htp_ops_context * octx;
    uint32_t tasks_per_thread;
    uint32_t total_tasks;
    struct fastdiv_values div_ne10;
    struct fastdiv_values div_ne10_ne11;
};

static void get_rows_quant_thread(unsigned int nth, unsigned int ith, void * data) {
    struct get_rows_quant_context * grctx = (struct get_rows_quant_context *) data;
    struct htp_ops_context * octx = grctx->octx;

    const uint32_t ne00 = octx->src[0]->ne[0];
    const uint32_t ne01 = octx->src[0]->ne[1];

    const uint32_t ne10 = octx->src[1]->ne[0];
    const uint32_t ne11 = octx->src[1]->ne[1];
    const uint32_t ne12 = octx->src[1]->ne[2];

    const uint32_t nb01 = octx->src[0]->nb[1];
    const uint32_t nb02 = octx->src[0]->nb[2];
    const uint32_t nb03 = octx->src[0]->nb[3];

    const uint32_t nb10 = octx->src[1]->nb[0];
    const uint32_t nb11 = octx->src[1]->nb[1];
    const uint32_t nb12 = octx->src[1]->nb[2];

    const uint32_t nb1 = octx->dst->nb[1];
    const uint32_t nb2 = octx->dst->nb[2];
    const uint32_t nb3 = octx->dst->nb[3];

    const uint32_t dr  = grctx->tasks_per_thread;
    const uint32_t ir0 = dr * ith;
    if (ir0 >= grctx->total_tasks) {
        return;
    }
    const uint32_t ir1 = MIN(ir0 + dr, grctx->total_tasks);

    const bool is_i32 = (octx->src[1]->type == HTP_TYPE_I32);

    uint64_t qt = HAP_perf_get_qtimer_count();

    for (uint32_t i = ir0; i < ir1; ++i) {
        const uint32_t i12 = fastdiv(i, &grctx->div_ne10_ne11);
        const uint32_t rem = i - i12 * ne11 * ne10;
        const uint32_t i11 = fastdiv(rem, &grctx->div_ne10);
        const uint32_t i10 = rem - i11 * ne10;

        const uintptr_t src1_addr = octx->src[1]->data + i10*nb10 + i11*nb11 + i12*nb12;
        uint32_t i01 = is_i32 ? *(int32_t *)src1_addr : (uint32_t)*(int64_t *)src1_addr;

        if (i01 >= ne01) {
            continue;
        }

        const block_q4_K * src0_row = (const block_q4_K *)(octx->src[0]->data + i01*nb01 + i11*nb02 + i12*nb03);
        float * dst_row = (float *)(octx->dst->data + i10*nb1 + i11*nb2 + i12*nb3);

        dequantize_row_q4_K_dsp(src0_row, dst_row, ne00);
    }

    qt = HAP_perf_qtimer_count_to_us(HAP_perf_get_qtimer_count() - qt);
    FARF(HIGH, "get-rows-quant %d/%d: ne00=%u rows=%u (%u:%u) usec %u\n",
         ith, nth, ne00, ne10*ne11*ne12, ir0, ir1, (unsigned) qt);
}

// ---------------------------------------------------------------------------
// jz_op_get_rows: dispatch wrapper
//   - f32 src0  -> Qualcomm op_get_rows (get-rows-ops.c)
//   - q4_K src0 -> gather + dequantize to f32
// ---------------------------------------------------------------------------
int jz_op_get_rows(struct htp_ops_context * octx) {
    if (octx->src[0]->type == HTP_TYPE_F32) {
        return op_get_rows(octx);
    }

    if (octx->src[0]->type != HTP_TYPE_Q4_K) {
        return HTP_STATUS_NO_SUPPORT;
    }
    if (octx->dst->type != HTP_TYPE_F32) {
        return HTP_STATUS_NO_SUPPORT;
    }
    if (octx->src[1]->type != HTP_TYPE_I32 && octx->src[1]->type != HTP_TYPE_I64) {
        return HTP_STATUS_NO_SUPPORT;
    }

    const uint32_t ne00 = octx->src[0]->ne[0];
    if (ne00 % QK_K != 0) {
        return HTP_STATUS_NO_SUPPORT;
    }

    if (octx->flags & HTP_OPFLAGS_SKIP_COMPUTE) {
        return HTP_STATUS_OK;
    }

    const uint32_t ne10 = octx->src[1]->ne[0];
    const uint32_t ne11 = octx->src[1]->ne[1];
    const uint32_t ne12 = octx->src[1]->ne[2];
    const uint32_t nr = ne10 * ne11 * ne12;

    struct get_rows_quant_context grctx;
    grctx.octx = octx;
    grctx.total_tasks = nr;
    grctx.div_ne10      = init_fastdiv_values(ne10);
    grctx.div_ne10_ne11 = init_fastdiv_values(ne10 * ne11);

    const uint32_t n_threads = MIN(nr, octx->n_threads);
    grctx.tasks_per_thread = (nr + n_threads - 1) / n_threads;

    worker_pool_run_func(octx->ctx->worker_pool, get_rows_quant_thread, &grctx, n_threads);

    return HTP_STATUS_OK;
}
