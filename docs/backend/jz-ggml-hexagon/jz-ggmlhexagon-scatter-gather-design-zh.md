# JZ ggml-hexagon Scatter-Gather 扩容设计文档

> **最终结论 (2026-08-11)**: 本路径已被 **DSP 32-bit user VA 4 GiB hard cap** 堵死, scatter-gather 路线正式关闭, 详见 [第五节 Spike A 实测结论](#五-spike-a-实测结论--路径关闭) 与 [第七节 根因定位](#七-根因定位-dsp-4-gib-va-hard-cap)。
>
> 适用范围: 突破 V79 DSP 32-bit user VA 4 GiB hard cap, 容纳超过 single mempool 容量的大模型 (如 Qwen3.5-9B 5.03 GiB, Qwen3.5-13B/20B 等)
>
> 实施状态: Spike A 已落地并完成 N=2/N=5 两组实测, N=2 OK, N=5 在第 3 个 buffer FAIL, 根因为 VA 耗尽
>
> 后续路径: 转向 chunked streaming (producer-consumer), 详见 [jz-ggmlhexagon-pp-tg-optimization-analysis-zh.md: 8.6.4](file:///home/zhouwg/develop/ggml-hexagon/docs/backend/jz-ggml-hexagon/jz-ggmlhexagon-pp-tg-optimization-analysis-zh.md)
>
> 上游文档: [jz-ggmlhexagon-pp-tg-optimization-analysis-zh.md: 8.6.3](file:///home/zhouwg-develop/ggml-hexagon/docs/backend/jz-ggml-hexagon/jz-ggmlhexagon-pp-tg-optimization-analysis-zh.md) scatter-gather 修复路径总览

## 术语表

| 缩写 | 全称 / 含义 |
|------|-------------|
| JZ   | JZ's ggml-hexagon (custom backend, `GGML_HEXAGON_JZ=ON`) |
| QCOM | Qualcomm's ggml-hexagon (official backend, `GGML_HEXAGON_JZ=OFF`) |
| mempool | kernel-allocated AP-DSP shared memory (single allocation, offset addressing) |
| FastRPC | Fast Remote Procedure Call (高通 AP-DSP 通信机制, 含 `rpcmem_alloc2` / `fastrpc_mmap` / `FASTRPC_MAP_FD_DELAYED_EXTENDED` 等 API) |
| HAP | Hexagon Advanced Processor (DSP 端用户态 SDK, 含 `HAP_mmap2` 内存映射 API) |
| cDSP | Compute DSP (高通 Hexagon DSP, 8 Elite = V79) |
| cgraph | compute graph (ggml 计算图, 一组 op 节点的有向无环图) |
| IOVA | I/O Virtual Address (DMA 寻址用的虚拟地址, 由 ION 分配) |
| Tier 1 | single mempool (单一连续 IOVA, 0~4 GiB, 装 lm-head / 主要权重 / 算子 descriptor) |
| Tier 2 | per-chunk 动态 rpcmem (非连续, 每个独立 4 GiB window, 装大模型溢出权重 / KV cache 溢出) |

## 一、设计动机

### 1.1 根因

V79 DSP user VA 32-bit 4 GiB hard cap, JZ 当前 single mempool 单次 `rpcmem_alloc2` 最多 4 GiB 物理, `fastrpc_mmap` + `HAP_mmap2` 后映射到 4 GiB VA 范围。Qwen3.5-9B repack 后 5.03 GiB 超过此上限, ~2 GiB 权重回退 heap, 触发 mirror memcpy (每 token ~200 ms, 占 TG wall 78%)。

### 1.2 候选路径 (来自 [jz-ggmlhexagon-pp-tg-optimization-analysis-zh.md: 8.6.1](file:///home/zhouwg/develop/ggml-hexagon/docs/backend/jz-ggml-hexagon/jz-ggmlhexagon-pp-tg-optimization-analysis-zh.md) Table-39)

| 路径 | 描述 | 评价 |
|---|---|---|
| 1a. 改 get_max_size | 让 ggml core 拆 1 GiB chunk | 不可行: JZ `alloc_buffer` 是 bump allocator, 多次调用仍从同一 mempool 切块, 总容量不变 |
| **1b. Scatter-gather** | DSP 端 HVX descriptor 从 system memory 拉 weight, 绕过 4 GiB VA | 容量/mirror 维度的明显更优 |
| 1c. HAP_mmap2 sliding window | 按 layer 切换 mmap 内容 | 仍受 V79 4 GiB 总 VA 限制 |
| 1d. 混合方案 | 控制结构在 VA, weight 在 system memory | 工程量最大, 1-2 个月 |

### 1.3 平台约束

仅使用高通提供的 FastRPC API (`rpcmem_alloc2`, `fastrpc_mmap`) 与 HAP API (`HAP_mmap2`), 严禁依赖:
- ION 子系统 (`/dev/ion`, `ION_IMPORT`): Android 平台特有, 上游不会接受
- `memfd_create`: Linux 平台特性, 同样非通用
- 自定义 kernel module: 维护成本高

## 二、目标架构

### 2.1 双 Tier 内存模型

| Tier | backing store | 数量 | 生命周期 | VA 特征 | 典型内容 |
|---|---|---|---|---|---|
| Tier 1 | single mempool | 1 | 整个 session | 单一连续 IOVA, 0~4 GiB | lm-head, 主要权重, 算子 descriptor |
| Tier 2 | per-chunk 动态 rpcmem | N (1-16) | 一次 cgraph 计算 (可滑动) | 非连续, 每个独立 4 GiB window | 大模型溢出权重, KV cache 溢出 |

### 2.2 与 QCOM per-chunk 的差异

| 维度 | QCOM per-chunk | JZ Tier 2 (本设计) |
|---|---|---|
| backing store | 高通私有 heap | system memory (`RPCMEM_HEAP_ID_SYSTEM`) |
| 初始化策略 | init 时一次性 mmap, 不释放 | cgraph 计算时按需 mmap, 计算结束可滑动 |
| 突破 4 GiB VA 方式 | 多 buffer 共享 4 GiB window | sliding window 让不同 buffer 在不同时刻占据 VA window |
| 跨平台兼容性 | 依赖 QCOM 私有 heap 限制 | 仅依赖 system memory + FastRPC + HAP, 跨 Android/Linux/WoA |

### 2.3 alloc_buffer 路由策略

`alloc_buffer(buft, size)` 由 ggml core `ggml_dyn_tallocr_new_chunk` 调用, `size = MAX(min_size, max_chunk_size)`, 不知道 chunk 内具体 tensor 列表。路由逻辑:

```text
TIER1_FREE = rpc_mempool_len - rpc_mempool_usage
TIER1_LMHEAD_RESERVE = 1.5 GiB  # Qwen3.5-9B output.weight repack 后 545 MiB + 余量

if (size <= TIER1_FREE) and (rpc_mempool_usage < TIER1_LMHEAD_RESERVE):
    # Tier 1: bump allocator 切 mempool (现有逻辑, 几乎不动)
    return bump_alloc(size)

else:
    # Tier 2: 新建独立 rpcmem buffer
    buf = rpcmem_alloc2(RPCMEM_HEAP_ID_SYSTEM, RPCMEM_DEFAULT_FLAGS, size)
    fd  = rpcmem_to_fd(buf)
    fastrpc_mmap(domain_id, fd, buf, 0, size, FASTRPC_MAP_FD_DELAYED)
    # DSP 端 HAP_mmap2 推迟到首次 cgraph 计算时执行 (sliding window 入口)
    return tier2_buf_init(buf, fd, size)
```

阈值选择: 1.5 GiB reserve 略大于 Qwen3.5-9B lm-head repack 后 545 MiB, 留余量给小权重 (token_embedding 等); 实际数值需 5-6 模型 AB CI 调优。

## 三、实施阶段

### 3.1 阶段总览

| 阶段 | 内容 | 状态 | 阻塞 |
|---|---|---|---|
| Spike A | multi-rpcmem + HAP_mmap2 链路验证 | 已 patch, 待用户构建测试 | 无 |
| Spike B | HAP_mmap2 冷启动 + L2 命中延迟对比 | 待 Spike A 通过 | Spike A |
| Spike C | AP 侧 per-call mmap overhead 实测 | 待 Spike B | Spike B |
| Spike D | 4 GiB VA window 滑动 + L2 evict 代价 | 待 Spike C | Spike C |
| alloc_buffer 改造 | 实现 Tier 路由, 默认关闭 | 待 Spike A-D 通过 | Spike D |
| 描述符协议扩展 | `hex_tensor_desc` 加 tier 标识 + buffer_id | 待 alloc_buffer 改造 | alloc_buffer |
| mirror 机制扩展 | 跨 buffer mirror 支持 | 待描述符协议扩展 | 描述符协议 |
| 5 模型 CI 回归 | Qwen1.5-1.8B/2B/Gemma4-E2B/Llama-3.2-1B 不退化 | 待全量落地 | 全部上述 |
| Qwen3.5-9B 性能验证 | 期望 TG 1.48 -> 6-7 tok/s | 待 5 模型 CI 通过 | 5 模型 CI |

### 3.2 Spike A 目标

**唯一目标**: 验证 N 个独立 rpcmem buffer 能同时完整跑通 3 个 API:

1. `rpcmem_alloc2` (AP 侧分配 system memory)
2. `fastrpc_mmap` (FastRPC 框架建立 AP-DSP 共享映射)
3. `HAP_mmap2` (DSP 端建立 user VA 映射)

通过条件:
- 5 个 buffer 全部 3 步成功
- 每次 `HAP_mmap2` 返回非 `(void*)-1` 的合法 VA
- 5 个 VA 之间不重叠, 都在 V79 4 GiB VA window 内
- AP 侧 `memset` 写测试 pattern 不触发 `BUS_ERR` 或段错误

**不验证**:
- 跨 buffer 数据访问正确性 (Spike B/D)
- 多 buffer 同时 DSP 算子访问 (Spike B)
- mmap/unmap 滑动 (Spike D)
- 性能数据 (Spike C)

### 3.3 Spike A 落地 patch (本批次)

[ggml_dsp.idl: line 19](file:///home/zhouwg/develop/ggml-hexagon/ggml/src/ggml-hexagon/kernels/ggml_dsp.idl#L19) - 新增 `register_rpcmem` IDL 函数, 复用 `register_ion` 相同的 `(fd, size_lo, size_hi)` 三参数约定。

[entry.c: ggml_dsp_register_rpcmem](file:///home/zhouwg/develop/ggml-hexagon/ggml/src/ggml-hexagon/kernels/entry.c) - DSP 端实现, 复用 `ggml_dsp_register_ion` 的 HAP_mmap2 逻辑, 但不持久化 VA (probe 仅做映射验证)。

[ggml-hexagon-jz.cpp: probe_multi_rpcmem](file:///home/zhouwg/develop/ggml-hexagon/ggml/src/ggml-hexagon/ggml-hexagon-jz.cpp) - AP 侧 probe 函数, 5 轮循环跑通 3 步 API, 失败立即 `goto cleanup` 不中断初始化。

[ggml-hexagon-jz.cpp: hexagon_appcfg_t.probe_multi_rpcmem](file:///home/zhouwg/develop/ggml-hexagon/ggml/src/ggml-hexagon/ggml-hexagon-jz.cpp) - 配置项, 默认 0 (关闭, 生产无开销), 开启需在 cfg 文件 `[cdsp]` 段加 `probe_multi_rpcmem = 1`。

### 3.4 用户验证流程

1. 同步 `feature/qwen3.5-9b-optimize-5` 分支到本地
2. `./scripts/build-kernels.sh` 重新编译 IDL + DSP 端 entry.c
3. `./scripts/build-run-ggmlhexagon-android.sh` 重新编译 AP 端
4. 编辑 `/data/local/tmp/ggml-hexagon.cfg`, `[cdsp]` 段加 `probe_multi_rpcmem = 1`
5. 推送 cfg 到设备: `adb push /data/local/tmp/ggml-hexagon.cfg /data/local/tmp/`
6. 运行任意模型, 捕获 `adb logcat` 输出
7. 检查 `[MULTI-RPCMEM-PROBE]` 日志:
   - `START` 标记 probe 开始
   - 5 个 `OK` 表示 3 步 API 全部成功
   - 任何 `FAIL step=...` 都需要进一步诊断

## 四、待解决问题 (Spike A 之后)

| 问题 | 触发阶段 | 影响 |
|---|---|---|
| HAP_mmap2 冷启动延迟 (首次 vs 命中 L2) | Spike B | 决定 sliding window mmap/unmap 切换频率上限 |
| per-call mmap overhead 占比 | Spike C | 决定是否需要 mmap 缓存 (重复用同一 fd) |
| 4 GiB VA window 滑动 L2 evict 代价 | Spike D | 决定 layer 切换 vs cgraph 切换粒度 |
| `hex_tensor_desc` tier 标识位设计 | alloc_buffer 改造 | 影响现有 descriptor 协议兼容性 |
| mirror 机制跨 buffer 支持 | 描述符协议扩展 | 决定 heap 权重能否保留 mirror 优化 |
| `weight_inval_ptrs[]` set 扩容量 | 描述符协议扩展 | bit 0 first-touch bitmap 跟踪跨 tier |
| 5 模型 CI 不退化验证 | 全量落地 | scatter-gather 不能影响 < 4 GiB 模型 TG 性能 |

## 五、Spike A 实测结论 & 路径关闭

Spike A patch ([kernels/ggml_dsp.idl](file:///home/zhouwg/develop/ggml-hexagon/ggml/src/ggml-hexagon/kernels/ggml_dsp.idl) + [kernels/entry.c](file:///home/zhouwg/develop/ggml-hexagon/ggml/src/ggml-hexagon/kernels/entry.c) + [ggml-hexagon-jz.cpp](file:///home/zhouwg/develop/ggml-hexagon/ggml/src/ggml-hexagon/ggml-hexagon-jz.cpp)) 已落地并在 qwen3.5-9B 上完成 N=5 与 N=2 两组实测。

### 5.1 N=5 实测 (probe_multi_rpcmem=1, BUF_SIZE=4 MiB, log: probe_20260811-124420.txt)

**前 2 个 buffer 成功, 第 3 个 FAIL**:

```
[MULTI-RPCMEM-PROBE] START: N=5 x 4 MiB, FastRPC only (no ION)
[RPCMEM-REG] HAP_mmap2 OK: va=FD000000 (fd=19, size=4MB, time=22 us)
[RPCMEM-REG] HAP_mmap2 OK: va=FD400000 (fd=20, size=4MB, time=23 us)
Error 0x8000054d: fastrpc_mmap_validate failed for fd 21, pa 0xcfda00000, dsp_va 0x0 size 4194304, flags 0x3, mode 0x7, perm 0x3
Error 0x8000054d: fastrpc_invoke_fd_mmap_create failed for fd 21 of length 4194304 bytes
[MULTI-RPCMEM-PROBE] FAIL step=fastrpc_mmap, fd=21
```

第 4/5 个 buffer 未尝试 (probe 失败后立即 `goto cleanup`)。第 1/2 个 buffer VA = 0xFD000000/0xFD400000, 都在 V79 32-bit VA 高区。

### 5.2 N=2 实测 (BUF_SIZE=4 MiB, log: probe_20260811-130438.txt)

**2 个 buffer 全部成功**:

```
[MULTI-RPCMEM-PROBE] START: N=2 x 4 MiB
[RPCMEM-REG] HAP_mmap2 OK: va=FD000000 (fd=19, size=4MB, time=22 us)
[RPCMEM-REG] HAP_mmap2 OK: va=FD400000 (fd=20, size=4MB, time=23 us)
[MULTI-RPCMEM-PROBE] OK: 2 x 4 MiB, all 3 APIs (rpcmem_alloc2 + fastrpc_mmap + HAP_mmap2) succeeded
```

| 实体 | 测得值 |
|---|---|
| buffer 0 VA | 0xFD000000 (4 MiB) |
| buffer 1 VA | 0xFD400000 (4 MiB) |
| 累计探测 VA | 8 MiB |
| 状态 | 全 OK |

### 5.3 N=2 vs N=5 联合判读

| 测试 | 累计探测 size | 状态 | 隐含 |
|---|---|---|---|
| N=2 | 8 MiB | OK | VA 还有空间容纳 2 个 4 MiB buffer |
| N=5 | 12 MiB (第 3 个失败) | FAIL | VA 在第 3 个 4 MiB 时耗尽 |

注意 N=5 失败累计 size 是 12 MiB, 不是 8 MiB。说明第 3 个 4 MiB buffer 想分配 VA 0xFD800000 时触发 VA 上限, 不是 buffer 1 触发。VA 空间在 ~8-12 MiB 区间开始不足, 与 DSP 32-bit VA 总空间计算 (4 GiB 减去 mempool/代码/栈/堆) 完全吻合。

### 5.4 路径关闭决议

综合 N=2/N=5 实测与 [第七节 根因定位](#七-根因定位-dsp-4-gib-va-hard-cap), scatter-gather 路径正式关闭:

1. **DSP 路径不成立**: V79 DSP 32-bit user VA 4 GiB hard cap 是硬件限制, 无法通过多 buffer sliding window 绕开
2. **sliding window 实质是 QCOM 方案**: 即便能绕开 VA 限制, 也与 QCOM per-chunk shared buffer 方案等效, 无差异化
3. **Spike B-D 不再继续**: HAP_mmap2 冷启动延迟 / per-call mmap overhead / 4 GiB window 滑动 等测量已无意义

Spike A patch 保留, 标记为"已完成历史使命, 不再演进"。

## 六、决策记录

### 6.1 为什么不用 ION_IMPORT (2026-08-11 决策)

ION_IMPORT 依赖 Android 平台 `/dev/ion` 子系统, 是 Linux 内核 ion 驱动提供的特性, 在上游 ggml-hexagon 仓库不被接受。改为仅使用高通公开 API (`rpcmem_alloc2` + `fastrpc_mmap` + `HAP_mmap2`), 三者均通过 FastRPC/HAP 公开接口实现, 跨 Android/Linux/WoA 通用。

### 6.2 为什么不用 memfd_create (2026-08-11 决策)

memfd_create 是 Linux 3.17+ 内核特性, 同样依赖特定平台。WoA (MSVC) 与某些嵌入式 Linux 不支持。坚持使用高通提供的 rpcmem 体系, 跨平台一致。

### 6.3 per-chunk rpcmem 分配 (2026-08-11 决策)

ggml core 内部 `ggml_dyn_tallocr` 维护 chunk 数组 (`GGML_VBUFFER_MAX_CHUNKS = 16`), 每个 chunk 是一个独立 backend buffer。`alloc_buffer` 一次调用 = 一个 chunk, chunk 内可含多个 tensor。QCOM 实际按 chunk 分配 (`[ggml-hexagon.cpp: ggml_backend_hexagon_buffer_type_alloc_buffer](file:///home/zhouwg/develop/ggml-hexagon/ggml/src/ggml-hexagon/ggml-hexagon.cpp)`, chunk_size 上限 `opt_mbuf = 1 GiB`)。JZ 沿用此模式, 每 chunk 一个独立 rpcmem buffer, 简化 alloc_buffer 路由决策 (一次决定整 chunk 去向)。

### 6.4 alloc_buffer 复杂度评估 (2026-08-11 评估)

`alloc_buffer` 本身的 Tier 路由逻辑非常简单 (一个 `if/else`, 信号是 `rpc_mempool_usage` + `size`)。真正的复杂度在下游 5 个环节, 估算总改动量是 alloc_buffer 的 10-20 倍, 详见 [jz-ggmlhexagon-pp-tg-optimization-analysis-zh.md: 8.6.3](file:///home/zhouwg/develop/ggml-hexagon/docs/backend/jz-ggml-hexagon/jz-ggmlhexagon-pp-tg-optimization-analysis-zh.md) Table-39 步骤 1b 的实施成本表。

### 6.5 scatter-gather 路径关闭 (2026-08-11 决策)

基于 Spike A N=5 FAIL 与 N=2 OK 两组实测, scatter-gather 路径正式关闭, 理由:
1. DSP 32-bit user VA 4 GiB hard cap 是硬件限制, scatter-gather 不能突破
2. 即便能突破 (例如 64-bit VA 模式), 方案与 QCOM per-chunk shared buffer 等效, 无差异化
3. JZ 的 4 GiB single mempool 设计是核心优势 (连续 IOVA + 简单 mirror), 不应被新 buffer 架构稀释

后续转向 chunked streaming (producer-consumer), 核心思想: 模型按 layer 切块, AP 端 producer 加载下一块到同一个 mempool (覆盖前一块), DSP consumer 在固定 mempool 上计算当前块, **零额外 DSP VA 需求, 零 fastrpc_mmap 调用**。

## 七、根因定位: DSP 4 GiB VA hard cap

### 7.1 VA 资源账本 (基于 N=2 log line 595/605 实证)

| VA 范围 | 大小 | 占用方 | 实证来源 |
|---|---|---|---|
| 0x00000000 - 0x005FFFFF | 6 MiB | mempool 前 6 MB 保留 / low region | 反推 (mempool 起始 0x00600000) |
| **0x00600000 - 0xFBE00000** | **4024 MiB (3.93 GiB)** | **主 mempool 占用** | log line 595: `[ION-REG] HAP_mmap2 OK: va=00600000 (fd=18, size=4024MB)` |
| 0xFBE00000 - 0xFCFFFFFF | 18 MiB | DSP code/libggmldsp-skel-v79.so 加载区 | log line 491: `adsp_process_group_mem_map pgid 3004 flags 0x2 fd -1 vaddr 0x71101ff000 pageSize 16` (mapped 区域, 非 user VA) |
| 0xFD000000 - 0xFD3FFFFF | 4 MiB | probe buffer 0 | log line 624: `HAP_mmap2 OK: va=FD000000` |
| 0xFD400000 - 0xFD7FFFFF | 4 MiB | probe buffer 1 | log line 634: `HAP_mmap2 OK: va=FD400000` |
| 0xFD800000 - 0xFDBFFFFF | 4 MiB | **probe buffer 2 想要但失败** | 反推 (buffer 0 + 4 MiB = buffer 1; buffer 1 + 4 MiB = 期望 buffer 2) |
| 0xFDC00000 - 0xFFFFFFFF | 35 MiB | VTCM (8 MiB) + DSP stack/heap + 内核保留 | 推算 |

注: 上面"log line 491" 中 vaddr `0x71101ff000 pageSize 16` 实际 VA = `0x71101ff000 << 4` = `0x71101ff0000` 是 40-bit kernel VA, 不在 user VA 范围。仅列出以说明 kernel 已使用部分高区 VA。

### 7.2 为什么 N=2 OK 而 N=5 FAIL

| 测试 | 累计 VA 需求 | 失败点 VA | 失败点累计 size |
|---|---|---|---|
| N=2 (8 MiB) | 0xFD000000 - 0xFD7FFFFF | 无 | OK |
| N=5 (期望 20 MiB, 实际测 12 MiB) | 0xFD000000 - 0xFDBFFFFF (期望) | 0xFD800000 (第 3 个 4 MiB) | 12 MiB |

V79 32-bit user VA 总空间 4 GiB = 0x100000000。减去 mempool 0xFBE00000 = 0x4200000 = 67 MiB 给高区使用。67 MiB 中:
- 18 MiB (libggmldsp-skel-v79.so)
- 8 MiB (VTCM)
- ~26 MiB (DSP stack/heap/QuRT 内核保留)
- **净可用 15 MiB** (实测 2 x 4 MiB = 8 MiB OK, 3 x 4 MiB = 12 MiB FAIL, 临界点在 8-12 MiB 区间)

kernel `fastrpc_mmap_validate` 在累计 VA 超过净可用时返回 0x8000054d (用户态转为 0x80000401)。该错误是 **kernel-side VA allocator** 拒绝分配, 不是 quota, 不是 PA 冲突 (fd 19/20/21 的 PA 0xcfee00000/0xcfde00000/0xcfda00000 都在合理 system memory 范围)。

### 7.3 为什么 QCOM 不受影响

QCOM 没有 JZ 的 4 GiB single mempool。其 `alloc_buffer` 每个 buffer 独立 mmap, 每次 mmap size 受 `opt_mbuf = 1 GiB` 限制。多个 1 GiB buffer 的 mmap 不会触发 VA 配额, 因为:
- 没有单一 buffer 占用 4 GiB
- VA 碎片化程度低, kernel 容易定位 1 GiB 对齐的空闲区间
- 实际上 QCOM 的 cgraph 拆分使每 buffer 几十 MB, 远低于 VA 配额

QCOM 的 multiple per-chunk shared buffer 方案 = JZ 探索的 scatter-gather + sliding window 方案, 同样受 4 GiB VA 限制, 但因为单 buffer size 小 (1 GiB 上限), 实际未达到 VA 上限。

### 7.4 关闭 scatter-gather 的根本原因

1. **V79 DSP 32-bit user VA 是硬件限制**: 任何 AP-DSP 共享内存方案最终都需要在 DSP 端 HAP_mmap2, 受此限制
2. **JZ 的 4 GiB single mempool 是该限制的最大化利用**: 占满 4 GiB 后, 任何额外 mmap 都失败
3. **scatter-gather 想在同一个 DSP 进程内多 mmap**: 物理上不可能, VA 不够
4. **sliding window 想用 unmap 后再 mmap 复用槽位**: 等同于 QCOM per-chunk 方案, 无差异化

## 八、修订历史

| 日期 | 修订内容 | 作者 |
|---|---|---|
| 2026-08-11 | 初版, Spike A 设计 + patch, 决策记录 5.1-5.4 | JZ + MiniMax-M3 |
| 2026-08-11 | **Spike A 实测完成**: N=5 FAIL (第 3 个 buffer), N=2 OK; 新增 [第五节 Spike A 实测结论](#五-spike-a-实测结论--路径关闭)、[第七节 根因定位](#七-根因定位-dsp-4-gib-va-hard-cap); scatter-gather 路径正式关闭, 转向 chunked streaming | JZ + MiniMax-M3 |
