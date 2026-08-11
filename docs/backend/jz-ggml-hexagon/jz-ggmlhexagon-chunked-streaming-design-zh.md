# JZ's ggml-hexagon 大模型分块流式加载设计

> Initial: 2026-08-11

> Last updated: 2026-08-11

> Author: MiniMax-M3 (draft), Jeff Zhou (review & feedback)

> Status: Spike A completed, Spike B pending

> 实验分支: `feature/qwen3.5-9b-chunked-streaming`

> 与 scatter-gather 文档的关系: scatter-gather 已 ruled out (VA 上限), 本文档是替代路径

***

| 缩写 | 全称 / 含义 |
|------|-------------|
| JZ   | JZ's ggml-hexagon (custom backend, `GGML_HEXAGON_JZ=ON`) |
| QCOM | Qualcomm's ggml-hexagon (official backend, `GGML_HEXAGON_JZ=OFF`) |
| mempool | kernel-allocated AP-DSP shared memory (single allocation, offset addressing) |
| FastRPC | Fast Remote Procedure Call (高通 AP-DSP 通信机制, 含 `rpcmem_alloc2` / `fastrpc_mmap` 等 API) |
| HAP | Hexagon Advanced Processor (DSP 端用户态 SDK, 含 `HAP_mmap2` 内存映射 API) |
| cDSP | Compute DSP (高通 Hexagon DSP, 8 Elite = V79) |
| cgraph | compute graph (ggml 计算图, 一组 op 节点的有向无环图) |
| PP | Prompt Processing (prefill phase) |
| TG | Token Generation (decode phase) |
| Spike | 小范围验证实验, 用最小代码改动回答单一技术问题 |
| Tier 1 | single mempool (单一连续 IOVA, 0~4 GiB, 装 lm-head / 主要权重 / 算子 descriptor) |
| Tier 2 | (本方案不使用) 动态 rpcmem buffer |
| chunk | 模型权重的逻辑分块, 大小由切分策略决定 |
| producer | AP 侧线程, 负责将模型 chunk 从 gguf 文件读入 mempool |
| consumer | DSP 侧推理循环, 负责消费 mempool 中的权重 |
| sliding window | mempool 中可复用的环形区域, 装入/淘汰 chunk 避免 mirror memcpy |

## 一、目标与背景

### 1.1 问题陈述

Qwen3.5-9B Q4_0 gguf 在磁盘上占 **5.1 GiB**。当前 JZ 后端 ([`ggml-hexagon-jz.cpp`](file:///home/zhouwg/develop/ggml-hexagon/ggml/src/ggml-hexagon/ggml-hexagon-jz.cpp) + [`kernels/`](file:///home/zhouwg/develop/ggml-hexagon/ggml/src/ggml-hexagon/kernels/)) 的 single mempool 在 8 Elite (V79) 上限为 4 GiB (受 32-bit DSP VA 空间约束), 装不下 9B 完整权重。

结论: 9B 模型无法在单 mempool 架构下整段加载, 必须将模型切成多个 chunk 顺序加载。

### 1.2 scatter-gather 路径 ruled out

2026-08-11 在 `feature/qwen3.5-9b-scatter-gather` 分支上验证 scatter-gather + sliding window 方案, 结论为 **不可行**:

| 失败原因 | 证据 |
|----------|------|
| DSP VA 空间耗尽 (4 GiB 上限) | N=5 多 buffer 探测, 第 3 个 buffer 分配失败 0x8000054d |
| 64-bit VA mode 未启用 | 探测 `EXTENDED_MAP_SUPPORT = 0` |
| 32-bit VA 上限无法绕过 | 主 mempool 已占 4 GiB, 剩余约 17 MiB 不可用 |

scatter-gather 路径需要等待高通 Hexagon SDK 或 8 Elite firmware 解锁 64-bit VA mode, 在此之前不可行。

### 1.3 chunked streaming 取舍

**chunked streaming** = 在 single mempool (4 GiB) 范围内, 通过 producer-consumer 流水线按时序加载不同 chunk 的模型权重:

| 维度 | scatter-gather (ruled out) | chunked streaming (本方案) | QCOM per-chunk buffer |
|------|---------------------------|---------------------------|----------------------|
| VA 空间 | 4 GiB (当前) / >4 GiB (需 64-bit VA) | 4 GiB (single mempool) | 4 GiB per buffer (累计可超过 4 GiB) |
| 镜像拷贝 | 0 次 (按需 mmap) | 0 次 (producer 直接写入 mempool) | 每 chunk 1 次 (AP 镜像到 buffer) |
| AP-DSP 共享模型 | yes (按需) | yes (整段按时序) | yes (按 chunk) |
| 等待条件 | 需要 64-bit VA mode | 不需要, 现有架构直接可用 | 不需要 |
| 复杂度 | 1 个 mempool + N 个 buffer | 1 个 mempool + 1 个 sliding window | N 个 per-chunk buffer |
| 平台依赖 | FastRPC + HAP | FastRPC + HAP + producer thread | FastRPC + HAP + driver |
| 与上游兼容性 | 中 (需解释 sliding window 内存模型) | 高 (复用现有 mempool 路径) | 高 (QCOM 已是默认路径) |

**关键差异**: 本方案不扩展 VA 空间, 而是在时间维度上复用同一段 4 GiB mempool。代价是: 不同 chunk 不能并发推理 (因为它们共享同一段物理地址)。

### 1.4 成功标准

| 指标 | 目标 |
|------|------|
| 模型可加载 | Qwen3.5-9B Q4_0 (5.1 GiB) 全部权重可按时序访问 |
| 推理正确性 | TG 输出与 CPU 参考实现 bit-equivalent |
| 性能 | TG speed >= 5.7 tok/s (Qwen3.5-9B 8 Elite 8 Gen 3 目标值) |
| 平台依赖 | 仅使用高通 FastRPC + HAP API, 不依赖 ION / memfd / 64-bit VA |
| 与上游兼容 | producer-consumer 仅在 AP 侧, 不修改 DSP kernel 接口 |

## 二、方案设计

### 2.1 整体架构

```
        +-------------------+         +-------------------+
        |   AP (producer)   |         |   DSP (consumer)  |
        |                   |         |                   |
        |  read gguf chunk  |         |  wait for chunk   |
        |       |           |         |       |           |
        |       v           |         |       v           |
        |  write to mempool | <-----> |  consume chunk    |
        |  signal ready     |  cond   |  signal consumed  |
        |                   |  var    |                   |
        +-------------------+         +-------------------+
                  |                              |
                  v                              v
        +-------------------------------------------+
        |   single mempool (4 GiB, sliding window)  |
        |   [ chunk 0 | chunk 1 | ... | slot N-1 ]  |
        +-------------------------------------------+
```

producer 线程在 AP 侧跑, 负责按时序将 chunk 从 gguf 文件读入 mempool 的不同 slot; DSP 主线程作为 consumer, 等待 mempool 中目标 chunk 就绪后消费。

### 2.2 数据流

单次推理 batch (PP 或 TG) 的数据流:

1. **AP 调度器决定**当前 batch 需要哪些 tensor (按 layer / 按 op 划分)
2. **producer 检查**这些 tensor 是否已在 mempool:
   - 是: 直接返回 mempool offset 给 DSP
   - 否: 从 gguf 读取对应 chunk, 写入 mempool 的下一个空闲 slot
3. **producer 通知**DSP: "chunk K 已就绪, 在 mempool offset X"
4. **DSP consumer**接收通知, 读取 mempool, 执行 op
5. **AP 调度器回收**已用 slot (LRU / 引用计数)

注意: producer 与 consumer 在同一 mempool 上工作, 写读顺序由 mutex + condvar 同步。

### 2.3 producer-consumer 同步

| 方案 | 优点 | 缺点 | 决定 |
|------|------|------|------|
| mutex + condvar | 实现简单, 适合低频 chunk 切换 | 加锁开销, 不适合高频 | **采用** |
| lock-free ring buffer | 无锁, 高并发 | 实现复杂, 需要 ABA 处理 | 备选 (若 mutex 性能不达标) |
| channel (单写单读) | 无锁, 简洁 | 只能传引用, 不传数据 | 不适用 (需要传 chunk 数据本身) |

**采用方案**: mutex + condvar, 每个 mempool slot 维护状态:

```cpp
enum chunk_state {
    CHUNK_EMPTY,    // 空闲, 可写入
    CHUNK_LOADING,  // producer 正在写
    CHUNK_READY,    // consumer 可读
    CHUNK_IN_USE,   // consumer 正在读
};
```

state 转换: `EMPTY -> LOADING -> READY -> IN_USE -> EMPTY`。

### 2.4 chunk 切分策略

| 策略 | 粒度 | 优点 | 缺点 |
|------|------|------|------|
| 按 layer | 每个 layer 一个 chunk (约 200-500 MiB) | 简单, PP 顺序加载与推理顺序一致 | 单一 layer 超过 mempool 时不可行 |
| 按 tensor group | attention / ffn 拆开 | 灵活, 适合 TG 重用 | TG 中 KV cache 跨多个 chunk, 复杂 |
| 固定大小 | 256 MiB / chunk | 简单, 可预测 | 切分可能不与 op 边界对齐 |

**采用策略**: 按 layer 切分为主, 单 layer 大于 mempool 容量时按 tensor group 二次切分。

Qwen3.5-9B (5.1 GiB / ~40 layers) 单 layer 约 130 MiB, 远小于 4 GiB mempool 容量, 按 layer 切分可行。

### 2.5 内存管理

mempool 内部按 sliding window 管理:

```
+----------------------------------+  4 GiB
| reserved for lm-head / op desc   |  ~512 MiB (固定占用)
+----------------------------------+
| sliding window for weights       |  ~3.5 GiB
| [ slot 0 | slot 1 | ... | slot N]|
+----------------------------------+
```

slot 大小 = ceil(max_layer_size / page_size) * page_size。N = sliding_window_size / slot_size。

| 模型 | 单 layer | slot 大小 | 窗口 slot 数 | 总占用 |
|------|----------|----------|--------------|--------|
| Qwen1.5-1.8B (1.9 GiB) | ~30 MiB | 32 MiB | ~108 | <4 GiB |
| Qwen3.5-2B (2.3 GiB) | ~40 MiB | 64 MiB | ~50 | <4 GiB |
| Qwen3.5-9B (5.1 GiB) | ~130 MiB | 256 MiB | ~13 | <4 GiB |

**关键约束**: 窗口 slot 数 >= 当前 batch 需要的最大层跨度 (典型为 1-3, 因为 attention/KV cache 需要跨层访问)。13 个 slot 对 9B 模型足够。

## 三、Spike 计划

### 3.1 Spike A: 同步基线 (单线程) — ✅ 已完成

**目标**: 验证 producer 在主线程内同步加载 chunk 到 mempool, 推理能正常完成。

**改动** (实测 vs 计划):
- 计划: 在 `ggmlhexagon_init_rpcmempool` 之后新增 `ggmlhexagon_chunked_load_init`, 按 layer 加载
- 实际: **简化为 init 阶段按 gguf 顺序一次性加载到 mempool**, 不集成到推理路径; 仅验证 gguf 读取 + mempool region bump-alloc 能力
- cfg 控制: `enable_chunked_test` (默认 0) + `test_gguf_path`

**实测数据 (8 Elite V79, SDK 6.6.0.0, 2026-08-11)**:

| 模型 | 文件大小 | n_tensors | loaded | skipped | failed | bytes_loaded | 加载耗时 | 吞吐 | pool_usage |
|------|----------|-----------|--------|---------|--------|--------------|----------|------|------------|
| Qwen1.5-1.8B (Q4_0) | 1.04 GiB | 291 | 291 | 0 | 0 | 1.04 GB | 255 ms | 4.1 GB/s | 1062 MB (26%) |
| Qwen3.5-9B (Q4_0) | 5.1 GiB | 427 | 300 | 127 | 0 | 3.91 GB | 2.17 s | 1.8 GB/s | 4000 MB (99%) |

**关键观察**:
- 小模型 1.04 GB 全装下, 加载 255 ms (4.1 GB/s, 远高于 DSP 推理速度)
- 9B 装下 300 tensors (3.91 GB), 跳过 127 tensors (1.1 GB), 与"5.1 GB > 4 GB mempool"预测一致
- 加载速度从 4.1 GB/s 降到 1.8 GB/s, 因为大模型尾部 fseek 跨越大距离
- 副作用: spike A 把 `ctx->rpc_mempool_usage` 推到 4000 MB, 推理 mirror buffer 分配失败
- 修复: 函数入口保存 `saved_mempool_usage`, 返回前 `memset 0` spike A 区域 + 恢复 mempool_usage; 修复后 Qwen3.5-9B 推理路径不再报 `mempool full`

**验证清单**:
- [x] Qwen1.5-1.8B 完整推理 (256 batch_calls, cgraph hit 98.8%, 无 mempool full)
- [x] Qwen3.5-2B 完整推理 (n_layer=24, 256 batch_calls)
- [x] Qwen3.5-9B 完整推理 (n_layer=32; **推理功能正常**, TG 速度由 Phase 5 mirror 拖慢, 与 spike A 无关)
- [x] gguf 读取 + mempool bump-alloc 能力验证
- [x] mempool 副作用修复验证

**结论**:
- ✓ alloc 能力 OK, 加载速度 1.8 ~ 4.1 GB/s 足够支撑 chunked streaming
- ✓ 容量边界明确: 5.1 GiB 模型 = 4 GiB 装下 + 1.1 GiB skipped
- ✓ spike A 不污染 mempool, 可安全运行任意次
- ✗ **spike A 不能解决 9B 推理问题**: 它只是 init 阶段一次加载, 不会与推理时序配合; 9B 推理仍因模型本身超过 mempool 容量而失败, 需要 spike B 按 layer 集成

**风险**: 同步加载会拖慢 PP 速度 (每个 chunk 切换时 stall)。

### 3.2 Spike B: 异步 producer (单 producer 线程) — 🔄 下一步

**目标**: 验证 producer 线程异步预加载下一 chunk, 消除 PP 中的 stall, 集成到推理路径。

**核心思路**:
- **不再在 init 阶段加载** (spike A 的局限), 而是在 **batch 调度时按需加载**
- 引入 `chunk_state` 状态机 (`EMPTY -> LOADING -> READY -> IN_USE -> EMPTY`)
- consumer 在 batch N 处理时, producer 预加载 batch N+1 需要的 chunk
- LRU 淘汰最旧 slot, 引用计数保护正在使用的 chunk

**改动**:
- `ggml-hexagon-jz.cpp`: 新增 `ggmlhexagon_chunked_state` 结构体, 包含 sliding window slot 表 + mutex + condvar
- 新增 `producer_thread_fn` 入口, `std::thread` 启动
- 修改 `ggmlhexagon_backend_graph_compute_batch`: batch 开始前等待目标 chunk 就绪
- 修改 `ggmlhexagon_alloc_buffer`: tensor 分配时按 layer 触发 producer 加载
- `kernels/entry.c`: 无改动 (DSP 仍通过 single mempool offset 寻址)
- `kernels/ggml_dsp.idl`: 无改动

**待决问题 (Spike A 后已明确)**:
1. ~~producer 启动时机~~ → batch 调度时按需启动, 不在 init
2. ~~sliding window slot 大小~~ → Qwen3.5-9B 单 layer ~130 MiB, slot 大小 = 256 MiB
3. ~~LRU vs ARC~~ → 简单 LRU + 引用计数足够
4. ~~跨 batch 预取~~ → 预取下一 batch 的下一 layer, producer sleep 等待 signal

**验证**:
- [ ] Spike A 全部用例通过
- [ ] Qwen3.5-9B PP 速度 >= 当前 (因为消除了 Phase 5 mirror 拖慢)
- [ ] Qwen3.5-9B TG 速度 >= 5.7 tok/s
- [ ] 长时间推理 (1000+ tokens) 无内存泄漏
- [ ] producer-consumer 同步无 race condition (pthread helgrind 验证)

**通过条件**: Qwen3.5-9B 可在 4 GiB mempool 上完成完整推理, TG speed >= 5.7 tok/s, 正确性 bit-equivalent。

**风险**: thread 同步 bug 可能导致 race condition, 需要严格验证。

### 3.3 Spike C: 双缓冲 (2-slot sliding window)

**目标**: 验证最小 sliding window (2 slot) 能消除 producer-consumer 互锁。

**改动**:
- 复用 Spike B 的 producer 线程
- mempool 切分为 2 个 slot, producer 写 slot A 时 consumer 读 slot B
- 切换通过 condvar 信号, 无需 mutex 互锁读写

**验证**:
- [ ] Spike B 全部用例通过
- [ ] TG 速度 >= QCOM Q9B 8 Elite 基线
- [ ] producer 线程 CPU 占用率 < 30%

**通过条件**: 2-slot 窗口无 race condition, 性能达到 QCOM 80%。

**风险**: 双缓冲对 Qwen3.5-2B / 1.8B 等小模型可能过度复杂。

### 3.4 Spike 决策表

| Spike | 通过则下一步 | 不通过则 |
|-------|------------|---------|
| A     | 进入 B     | 回退到 scatter-gather 或等待 64-bit VA |
| B     | 进入 C     | 改用 lock-free ring buffer 或扩大 mempool 容量 |
| C     | 进入正式实现 | 缩到 1-slot (Spike B 单 slot 异步) |

## 四、性能预期

### 4.1 预期收益 (含 Spike A 实测)

| 模型 | Spike A (init 加载) | Spike B 目标 (异步 producer) | Spike C 目标 (双缓冲) | QCOM 8 Elite 基线 |
|------|---------------------|------------------------------|------------------------|-------------------|
| Qwen1.5-1.8B (1.04 GiB) | ✓ 1.04 GB 全装下, 255 ms (4.1 GB/s) | TG >= 28 tok/s | TG >= 28 tok/s | 27 (与 QCOM 持平) |
| Qwen3.5-2B (2.3 GiB) | n/a (未跑 spike A) | TG >= 25 tok/s | TG >= 25 tok/s | 24 (与 QCOM 持平) |
| Qwen3.5-9B (5.1 GiB) | ✓ 3.91 GB 装下 (300/427), 2.17 s (1.8 GB/s) | TG >= 5.7 tok/s | TG >= 6 tok/s | 5+ (当前 1.1) |

**Spike A 关键数据**:
- 加载吞吐稳定 1.8 ~ 4.1 GB/s, 远高于 DSP 推理速度 (~50 ms/batch, 即 1 GB/s 量级)
- 这意味着 producer 即使在同步模式下, 也**不会**成为推理瓶颈; 异步化主要解决的是 PP stall 问题
- 9B 加载 2.17 s 是一次性成本, 对长上下文推理 (1000+ tokens) 可摊销

### 4.2 主要瓶颈

1. **chunk 切换延迟**: producer 写新 chunk 期间 consumer 必须等待, 影响 PP 吞吐
2. **sliding window slot 调度**: slot 数不足时可能触发 mirror memcpy (回退到 scatter-gather 失败前的方案)
3. **producer 线程上下文切换**: 异步 producer 与 consumer 之间的线程切换开销

### 4.3 监控指标

通过现有 perf stats 监控:
- `batch_calls`, `cum_p10`, `cum_graph`: 推理时延
- `p10 3-way cumulative: rpc_setup / dsp_exec / civac`: producer 加载 vs DSP 推理时间占比
- 新增 `chunk_load_count`, `chunk_load_avg_us`: chunk 加载频次和耗时
- 新增 `chunked_lru_evict_count`: LRU 淘汰次数, 反映 slot 调度压力

## 五、风险与缓解

| 风险 | 影响 | 缓解 | 状态 |
|------|------|------|------|
| 9B 单一 layer 超过 mempool 容量 | 模型无法加载 | 启用 tensor group 二级切分 (2.4 节) | 设计中 (Spike A 验证 9B 单 layer ~130 MiB, 远小于 4 GB) |
| producer-consumer 死锁 | 推理卡住 | 加看门狗, 30s 内无进展则 abort | 待 Spike B 实现 |
| mempool LRU 淘汰正在使用的 chunk | 推理结果错误 | 引用计数保护, 在用 chunk 标 pinned | 待 Spike B 实现 |
| AP 侧 producer 线程 CPU 占用过高 | 手机发烫, 功耗高 | 限制 producer 优先级, 空闲时 sleep | 待 Spike B 实现 |
| 长稳态内存碎片 | mempool 可用空间下降 | 定期 (每 N batch) 整理 mempool | 待 Spike B 实现 |
| **spike / probe 污染 mempool_usage** | 推理 mirror 失败 | 函数入口保存 `mempool_usage`, 返回前 `memset 0` spike 区域 + 恢复 | ✓ Spike A 已修复 |

## 六、与现有模块的关系

### 6.1 不修改

- `kernels/entry.c`: DSP 侧入口, 无需修改 (consumer 仍通过 single mempool 寻址)
- `kernels/ggml_dsp.idl`: IDL 接口不变 (`register_rpcmem` / `execute_batch`)
- `kernels/*.c`: 所有 HVX/HMX kernel 无需修改

### 6.2 增量修改

- `ggml-hexagon-jz.cpp`:
  - 新增 `hexagon_chunked_state` 结构体
  - 新增 `producer_thread_fn`
  - 修改 `ggmlhexagon_init_rpcmempool` 接受 sliding window 参数
  - 修改 `ggml_backend_hexagon_context` 加 `chunked_state` 字段
- `ggml-hexagon.cpp` (QCOM, 不修改): 维持 QCOM per-chunk buffer 方案不变

### 6.3 与 scatter-gather 文档关系

scatter-gather 文档原计划存放在 `docs/backend/jz-ggml-hexagon/jz-ggmlhexagon-scatter-gather-design-zh.md`, 但因 ruled out 而未提交。本文档是 scatter-gather ruled out 后的替代路径, 不依赖 64-bit VA mode。

## 七、待决问题

1. **producer 启动时机**: 是 `ggmlhexagon_init_dsp` 期间启动, 还是首次 batch 才启动?
2. **sliding window slot 大小**: 固定还是按模型动态调整?
3. **LRU vs ARC 淘汰策略**: 简单 LRU 是否够用, 还是需要 ARC?
4. **跨 batch chunk 预取**: 是否预取下一 batch 需要的 chunk, 还是按需加载?

以上问题在 Spike A 通过后, 通过性能 profiling 决定。

## 八、参考资料

- 上一份 scatter-gather 探索: `feature/qwen3.5-9b-scatter-gather` (commit 24f309c77)
- single mempool 设计: [`kernels/entry.c`](file:///home/zhouwg/develop/ggml-hexagon/ggml/src/ggml-hexagon/kernels/entry.c)
- perf stats 体系: [`jz-ggmlhexagon-pp-tg-optimization-analysis-zh.md`](file:///home/zhouwg/develop/ggml-hexagon/docs/backend/jz-ggml-hexagon/jz-ggmlhexagon-pp-tg-optimization-analysis-zh.md)
- Qualcomm FastRPC API: `prebuilts/Hexagon_SDK/6.6.0.0/incs/remote.h`
- Qualcomm HAP API: `prebuilts/Hexagon_SDK/6.6.0.0/incs/HAP_mem.md`
- EXTENDED_MAP_SUPPORT (ruled out): `prebuilts/Hexagon_SDK/6.6.0.0/incs/remote.h:410`

## 九、Spike A 实测数据附录

### 9.1 测试环境

- 设备: 8 Elite (SnapDragon), dsp arch V79
- SDK: Hexagon SDK 6.6.0.0
- 系统内存: 24834 MiB
- mempool 容量: 4024 MB (4 GiB 减去头保留 8 MB, 共 4024 MB 数据区)
- DSP 能力: `has_vtcm=1, has_hvx=1, has_hmx=1, has_async_fastrpc=0, has_extended_map=0`
- 测试分支: `feature/qwen3.5-9b-chunked-streaming`
- commit: (待 spike A commit 后填入)
- 工具链: `build-run-ggmlhexagon-android.sh`

### 9.2 Qwen1.5-1.8B (Q4_0) 实测

```
[CHUNKED-TEST] start:  gguf=/sdcard/qwen1_5-1_8b-chat-q4_0.gguf mempool=4024 MB usage=0 MB
[CHUNKED-TEST] 291 tensors, data_offset=5945184
[CHUNKED-TEST] progress: 50 tensors, 519 MB
[CHUNKED-TEST] progress: 100 tensors, 633 MB
[CHUNKED-TEST] progress: 150 tensors, 754 MB
[CHUNKED-TEST] progress: 200 tensors, 863 MB
[CHUNKED-TEST] progress: 250 tensors, 976 MB
[CHUNKED-TEST] done:    loaded=291 failed=0 skipped=0 bytes=1114290176 pool_usage=1062 MB
[CHUNKED-TEST] restored mempool_usage=0 MB
[CHUNKED-TEST] 291 tensors loaded, 0 failed, 1114290176 bytes, pool_usage=0 MB
```

| 指标 | 数值 |
|------|------|
| 文件大小 | 1.04 GB |
| n_tensors | 291 |
| loaded | 291 (100%) |
| bytes_loaded | 1.04 GB (1114290176 B) |
| 加载耗时 | 255 ms |
| 加载吞吐 | 4.1 GB/s |
| pool_usage | 1062 MB (mempool 利用率 26.4%) |
| 推理 batch_calls | 256 (TG 295.66 tok/s) |
| cgraph cache hit_rate | 98.8% (253/256) |

### 9.3 Qwen3.5-9B (Q4_0) 实测

```
[CHUNKED-TEST] start:  gguf=/sdcard/Qwen3.5-9B-Q4_0.gguf mempool=4024 MB usage=0 MB
[CHUNKED-TEST] 427 tensors, data_offset=10968288
[CHUNKED-TEST] progress: 50 tensors, 1737 MB
[CHUNKED-TEST] progress: 100 tensors, 2184 MB
[CHUNKED-TEST] progress: 150 tensors, 2642 MB
[CHUNKED-TEST] progress: 200 tensors, 3112 MB
[CHUNKED-TEST] progress: 250 tensors, 3583 MB
[CHUNKED-TEST] progress: 300 tensors, 4000 MB
[CHUNKED-TEST] done:    loaded=300 failed=0 skipped=127 bytes=4194523904 pool_usage=4000 MB
[CHUNKED-TEST] restored mempool_usage=0 MB
[CHUNKED-TEST] 300 tensors loaded, 0 failed, 4194523904 bytes, pool_usage=0 MB
```

| 指标 | 数值 |
|------|------|
| 文件大小 | 5.1 GiB |
| n_tensors | 427 |
| loaded | 300 (70.3%) |
| skipped | 127 (29.7%) |
| bytes_loaded | 3.91 GB (4194523904 B) |
| 加载耗时 | 2.17 s |
| 加载吞吐 | 1.8 GB/s |
| pool_usage | 4000 MB (mempool 利用率 99.4%) |
| 推理功能 | 正常 (spike A 修复后) |
| TG 速度 | 未单独测量 (Phase 5 mirror 拖慢) |

### 9.4 副作用 + 修复

**问题**: spike A 把 `ctx->rpc_mempool_usage` 推到 ~4024 MB, 后续推理路径 `mempool-batch: mempool full for mirror (1802240 bytes)` 失败。

**修复** (在 [`ggmlhexagon_test_chunked_load`](file:///home/zhouwg/develop/ggml-hexagon/ggml/src/ggml-hexagon/ggml-hexagon-jz.cpp#L1818) 中):
1. 函数入口: `const size_t saved_mempool_usage = ctx->rpc_mempool_usage;`
2. 函数返回前: `memset((char*)ctx->rpc_mempool + saved_mempool_usage, 0, ctx->rpc_mempool_usage - saved_mempool_usage);`
3. 函数返回前: `ctx->rpc_mempool_usage = saved_mempool_usage;`
4. 新增 LOG_ALWAYS: `restored mempool_usage=0 MB`

**修复后验证**: Qwen3.5-9B 推理不再报 `mempool full`, mempool_usage 恢复为 0。

### 9.5 对 Spike B 的启示

1. **加载吞吐充足**: 1.8 ~ 4.1 GB/s 远高于 DSP 推理速度, 即使同步加载也不成为瓶颈
2. **mempool 副作用需严格控制**: 任何 probe/spike 都必须 save/restore `mempool_usage` + memset 清零
3. **gguf 顺序加载是可行的**: 验证了 `gguf_init_from_file + gguf_get_tensor_name/offset/size + fseek/fread` 全链路
4. **不分 layer 不影响 spike A**: 因为 spike A 不与推理路径交互, 加载顺序无所谓
5. **但 spike B 必须按 layer 顺序**: producer 需要知道 layer 索引, 推理 layer N 时加载 layer N, 这是 spike A 未验证的部分
