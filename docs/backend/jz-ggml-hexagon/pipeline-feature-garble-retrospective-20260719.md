> Author: MiniMax-M3
> Date: 2026-07-19
> Context: pipeline feature (pipeline_mode=1) 在 native FastRPC + single ION mempool 架构下的乱码调试复盘; 期间在 JZ 后端 graph_compute_batch 与 worker 线程两条路径间做了一系列对照实验, 排除了若干具体 cache 一致性维护方案与一条 driver 层替代路径, 但未能找到可稳定 ship 的修复.
>
> 与本文相关的代码路径:
> - AP: ggml/src/ggml-hexagon/ggml-hexagon-jz.cpp (graph_compute_batch, pipeline_worker_loop)
> - DSP: ggml/src/ggml-hexagon/htp/entry.c
> - 配置: scripts/ggml-hexagon.cfg (pipeline_mode, ion_sync_mode, dsp_cache_mode)

---

## 1. 背景与目标

JZ ggml-hexagon 在同步架构 (pipeline_mode=0) 下, PP 已达到甚至偶尔超过 Qualcomm 同设备基线 (详见 [ion-mempool-vs-perbuffer-analysis-20260713.md](ion-mempool-vs-perbuffer-analysis-20260713.md), gemma-4-E2B-it-Q4_0 实测稳定均值 ~349 tok/s, 单跑峰值可达 388 tok/s). TG 方面, JZ 在同设备同模型同推理命令行下落后 Qualcomm (高通基于 dspqueue 报告最高 ~26 tok/s, JZ 同步模式约 18 tok/s 量级).

本次工作的目标: 在保持 native FastRPC (而非 dspqueue) + single ION shared mempool (而非 per-buffer ION) 的 JZ 架构前提下, 通过 AP 端 graph 准备与 DSP 端 batch 执行的 batch-level 重叠, 把 TG 拉近到 Qualcomm 水平. 实现上引入 pipeline feature: 双 floor ION mempool + AP 端 worker 线程 + heap snapshot 机制.

实际效果: pipeline_mode=1 启用时 TG 抬升到 ~24 tok/s, 但推理输出出现有规律乱码 (token 重复 1 次到 3 次不等, 偶发提前 EOS, 具体模式随 cache 配置变化). pipeline_mode=0 时推理完全正常.

## 2. 架构概览 (pipeline_mode=1)

为支持 batch-level 重叠, 引入了以下结构:

- **双 floor ION mempool**: ION 共享池被切成两个等大的 floor (floor_id = seq & 1). 一个 floor 由 main 线程用于下一 graph 的描述符/mirror 写入, 另一个 floor 由 worker 线程提交给 DSP 正在执行. 双 floor 设计的目标是让 AP 写入与 DSP DMA 永远落在不同的物理范围, 避免直接地址竞争.
- **AP worker 线程**: main 线程完成 Phase 1-6 (图分析, 算子融合, ION 偏移分配, descriptor 构建) 后, 把 task 推入 queue, 由 worker 线程负责 Phase 6.7 (deferred heap->ION mirror 拷贝), Phase 6.5 cache flush, Phase 7 (blocking FastRPC invoke), Phase 7.5 (DC CIVAC), Phase 8 (ION->heap copy-back).
- **heap snapshot**: Phase 6 中, main 线程把要写入 ION mirror 的 heap 数据复制一份到 task 自带的 snapshot buffer. worker 线程从 snapshot 而非 live heap 读取, 避免与 main 线程在下一 graph 准备中覆写 heap 的竞争.
- **floor 错位诊断 (Test D)**: 在 main 端和 worker 端分别打印 [FLOOR-CHECK-MAIN] / [FLOOR-CHECK-WORKER] 日志, 包含 seq, floor_id, pm_count, pm[0].off, pm[0].len, batch_off, floor_abs. 用于确认 task 在正确的 floor 上被处理.

时序:

```
graph i:    main  |  prep P1..P6  |  push task i  |  return (继续 graph i+1 prep)
worker:                       |  Phase 6.7  |  Phase 6.5  |  Phase 7 (RPC)  |  Phase 7.5  |  Phase 8
graph i+1:           main  |  prep P1..P6  |  push task i+1  |  return
```

两条流水线在 i 与 i+1 之间发生时间重叠, 这是 TG 提升的来源. 正确性的关键约束是: DSP 读取 floor[i] 的字节时, 这些字节必须已经 (a) 由 main 写完, (b) 由 main 的 cache flush 推到 DRAM, (c) 没被 main 在 i+1 准备中再写. 双 floor 设计满足 (c), 但 (a) (b) 的保证依赖具体的 cache flush 时序策略.

## 3. 已尝试方案与结果

下列每条方案都曾在 pipeline_mode=1 下独立测试, 推理命令与基线一致. 乱码与性能描述基于 gemma-4-E2B-it-Q4_0 默认推理 (44 token prompt + 255 token generate).

### 3.1 Method A: 注释掉 main 端 Phase 6.5 whole-pool ion_sync_for_direction

- 假设: main 线程在 Phase 6.5 对整池做 `ion_sync_for_direction(fd, 1)` (WRITE 方向), 与 worker 线程在另一 floor 上的 in-flight DSP DMA 并发, 导致 ION 内存竞争.
- 改动: 注释掉 main 端 `if (do_ion_sync && !use_pipeline) { ion_sync_for_direction(...) }` 整段; 保留 worker 端的 `ion_sync_for_direction(rpc_mempool_handle, 1)`.
- 结果: 乱码从"灾难性数据损坏"缓解为"每个 token 精确重复一次". 性能 (PP, TG) 较 pipeline_mode=0 仍有提升.
- 结论: 排除 Hypothesis A (whole-pool ion_sync 是乱码的主因), 但确证 main/worker 间的 whole-pool 同步是部分破坏源.

### 3.2 E1 方案: 强制所有 pending_mirrors 走 heap snapshot 路径

- 假设: main 线程在 Phase 6 中填充 `heap_snapshot` 与 worker 线程 Phase 8 的 copy-back 对同一段 heap 存在数据竞争, snapshot 包含陈旧数据.
- 改动: 修改 mirror 构造逻辑, 让所有 `pending_mirrors` 都从 `heap_snapshot` 读取, 不再回退到 live heap (`pm.original_data`).
- 结果: 仍乱码, 模式与 Method A 后一致.
- 诊断: Test D 日志显示 `pm_count=0` 始终, 说明 E1 路径在当前 mirror 构造逻辑下根本没有激活, 实际仍走 live heap. 路径未生效即被否决.

### 3.3 跨 core cache coherency 测试: main 自 flush, worker 只 flush 自己写的 mirror

- 假设: ARM `dc cvac` 是 per-core local 操作. main 线程的 ION 写入留在其 L1/L2 中, worker 线程在另一 core 上跑 `dc cvac` 看不到 main 的 L1, DSP 因此读到 stale DRAM. 修复: 让 main 在 phase 6.5 自己 flush 自己写的 ION 范围, worker 端只 flush 自己 Phase 6.7 memcpy 的 mirror.
- 改动: 在 main 端 Phase 6.5 flush 之前补一遍 per-range `cpu_dcache_flush_range`; worker 端只保留对 `task->pending_mirrors` 的 flush, 删掉对 `task->flush_ranges` 的 flush.
- 结果: 仍乱码, 模式不变.

### 3.4 dsp_cache_mode 切换: bit 2 (bulk dst flush) 关闭

- 假设: dsp_cache_mode=4 的 bit 2 (bulk dst flush) 与 pipeline 异步性冲突.
- 改动: 设 `dsp_cache_mode=0` (DSP 端无 cache 优化), `ion_sync_mode` 保持 1.
- 结果: 仍乱码, 模式不变.
- 结论: 排除 DSP 端 bulk flush 是乱码的源.

### 3.5 Test E: main 自做 per-range DC CVAC, 关掉 whole-pool ion_sync

- 假设: 既然 worker 跨 core 看不到 main 的 L1, 那就让 main 自己 flush, 干脆关掉 whole-pool `ion_sync_for_direction`, 完全靠 per-range `dc cvac` / `dc civac` 维护一致性.
- 改动:
  1. main 端 Phase 6.5 do_dc_cvac 路径: 删除 `if (use_pipeline) { deferred_flush_ranges.push_back(...); }` 分支, 统一改为 `cpu_dcache_flush_range(...)` (无论 use_pipeline).
  2. worker 端 do_dc_cvac 路径: 注释掉对 `task->flush_ranges` 与 `task->pending_mirrors` 的 flush 调用.
  3. `ion_sync_mode = 2` (DC CVAC/CIVAC only, 关掉 whole-pool `ion_sync`).
- 结果: **乱码恶化**, 从"每个 token 重复一次"变成"每个 token 重复三次", 同时 PP 从基线 ~4.4 ms/tok 退化到 5.36 ms/tok, TG 从 ~70 ms/tok 退化到 147.91 ms/tok (10x 退化). 已 revert.

### 3.6 同步性测试: pipeline_mode=0 推理正常

- 关键对照: 在同样的 cache 配置下, `pipeline_mode=0` 推理完全正常, TG 回到 pipeline 引入前的水平.
- 推论: 乱码严格与 pipeline 模式的并发重叠相关, 而非 dsp_cache_mode / ion_sync_mode 单独决定.

### 3.7 async fastrpc probe (2026-07-19, init 阶段)

- 动机: worker 线程 + 同步 invoke 方案下, native FastRPC 阻塞到 DSP 返回是性能上界. async fastrpc 在 driver 层把"调用"与"完成"解耦, 理论上是另一条 batch-level 重叠路径.
- 改动: 在 `ggmlhexagon_init_dsp` 末尾加 TEMP DIAG probe 块, 用与同步 `execute_batch` (mid=4) 相同的 marshalling (prim[2] = {0u, 0xFFFB}) 调 `remote_handle64_invoke_async`, 立即 `fastrpc_async_get_status` + `fastrpc_release_async_job`.
- 结果 (两次独立 init):
  - `err=0x14` `jobid=0` 两次一致.
- 错误码含义: `0x14` (十进制 20) = `AEE_EUNSUPPORTED` (见 `prebuilts/Hexagon_SDK/6.6.0.0/incs/stddef/AEEStdErr.idl:66`). 即当前 handle/域配置上 driver 拒绝 async 调用.
- 推论: JZ 平台 + Hexagon SDK 6.6.0.0 配合当前 `ggmlop_handle` 的获取方式下, async fastrpc API 不可用. 这条突破方向被关闭, 不再作为后续选项.

## 4. 已确证 / 已排除

- **确证 (positive):**

- pipeline 拓扑本身 (双 floor ION mempool + worker 线程 + 同步 invoke) 能让 TG 从同步基线抬升到 ~24 tok/s. 重叠确实在发生, 不是空跑.
- floor 管理正确: Test D 日志中 [FLOOR-CHECK-MAIN] / [FLOOR-CHECK-WORKER] 的 floor_abs 计算结果与 (task->seq & 1) 一致, 没有 floor 错位.

**排除 (negative hypotheses):**

| 编号 | 假设 | 排除依据 |
|------|------|----------|
| A | whole-pool `ion_sync_for_direction` 是乱码主因 | Method A 后模式变化但未消失 |
| B | main 线程 L1 未 flush, worker 跨 core 看不到 | Test E 后反而恶化 |
| C | floor 寻址错位 | Test D 日志 floor_abs 正确 |
| D | DSP 端 bit 2 bulk flush 引起乱码 | dsp_cache_mode=0 后仍乱码 |
| E1 | heap snapshot 未生效, live heap 被竞争 | pm_count=0, 路径未激活 |
| E2 (Test E) | 关掉 whole-pool `ion_sync`, 改 per-range `dc cvac` 能修 | 反而恶化, 乱码程度加深 + 性能退化 |
| F | async fastrpc 替代 worker 线程 + 同步 invoke | invoke_async 返回 AEE_EUNSUPPORTED (0x14), API 在当前 handle/域配置上不可用 |

**仍 open:**

- Phase 7/7.5/8 时序: DSP 写完 + FastRPC 返回 + DC CIVAC + memcpy copy-back 之间的 ordering.
- descriptor 内部结构错位 (hex_op_desc / hex_tensor_desc / hex_batch_hdr 字段布局, 与 mirror 写入错位无关).
- worker 端 Phase 7.5 DC CIVAC 是否完整覆盖 DSP 写入的所有 dst (当前实现基于 `task->mirrors` + 所有 ION-resident dst, 但 split output 边界可能漏覆盖).
- Phase 8 copy-back 的时序: worker 做完 CIVAC 后立刻 memcpy 回 heap, 中间没有 barrier 等待 in-flight DMA.
- DSP 侧 dspqueue 化 (这与 native FastRPC 的架构前提冲突, 属于架构级重写).

## 5. 技术结论

- **架构层面**: native FastRPC + single ION mempool 这套约束下, batch-level cache 一致性没有 driver 提供的语义保障. Qualcomm 的 dspqueue 把 AP->DSP buffer 的 flush/invalidate 抽象成 `DSPQUEUE_BUFFER_FLAG_FLUSH_SENDER | INVALIDATE_RECIPIENT`, 由 driver 在合适时点统一维护. JZ 在 native FastRPC 下, 必须自己枚举所有 dirty range, 自己选 flush 策略, 自己处理 AP 端 cache 与 DSP 端 SMMU 的可见性. 在单线程同步模型下, 这条路经过多次迭代已经收敛到稳态. 但在双线程并发模型下, cache flush 的"操作者"与"被操作者"分布在不同 CPU core 上, 而 ARM 的 `dc cvac` 是 per-core local 操作, 跨 core 不可见. 这条不变量在 sync 模式下不暴露, 在 pipeline 模式下成为核心难点.
- **方法层面**: Test A 到 Test E 的逐条假设排除走得有效, 排除了若干表面合理但实际不成立的方案. 但仍未命中. 这与 Kimi-K3 在此方向上 ~9 小时未取得突破是一致的信号: 该搜索空间靠纯静态推理 + 有限次实测不收敛.
- **不能做等价推断**: "缓存一致性问题比 dspqueue 复杂" (经验事实) 不等于 "pipeline 在 native FastRPC + single ION mempool 架构下不可行" (原则结论). 复杂与不可行之间没有蕴含关系. 当前只能断言"在已尝试的具体方案范围内, 未找到稳定方案", 不能断言"所有可能方案都不行". 截至 2026-07-19, open 选项已从"async fastrpc + DSP 侧 dspqueue 化"两个收窄为只剩"DSP 侧 dspqueue 化"一个 (async fastrpc 已实测 AEE_EUNSUPPORTED 关闭).

## 6. 工程决策

- pipeline_mode=1 在当前状态下暂不启用.
- pipeline feature 作为 feature 分支保留, 不合并到主开发分支. 主分支保持 pipeline_mode 默认 0.
- 已稳定的其它 TG 优化 (cgraph reorder, QKV/FFN fusion, single ION mempool) 与 pipeline 解耦, 独立 ship.
- 任何对 pipeline feature 的继续探索 (DSP 侧 dspqueue 化, 4/8 floor 扩展等) 应在 feature 分支内进行, 每次都需要先在测试模型上跑通再考虑合并. async fastrpc 在 2026-07-19 已实测不可用 (AEE_EUNSUPPORTED 0x14), 不再是选项.

## 7. 后续可能突破方向 (供参考, 不承诺)

1. ~~**async fastrpc**~~ (2026-07-19 已实测关闭): init 阶段 TEMP DIAG probe 两次返回 AEE_EUNSUPPORTED (0x14), JZ 平台 + Hexagon SDK 6.6.0.0 配合当前 handle 不可用. 不再是选项.
2. **DSP 侧 dspqueue 化**: 把当前 AP 主导的 batch descriptor 协议重写为 DSP 侧 dspqueue 协议. 这与 native FastRPC 前提冲突, 属于架构级重写, 短期不现实.
3. **descriptor 内部错位**: 仍 open 的假设之一. 如果乱码根因不在 cache 而在 descriptor 结构, 现有的 cache flush 路径优化都是徒劳. 验证手段: 在测试模型上加 sentinel tensor, 比对 AP 写前/DSP 读后/worker CIVAC 后三个时间点上的 descriptor 字节.
4. **4/8 floor mempool**: 增加 floor 数量, 进一步隔离 main 写入与 DSP DMA 的时间窗口. 曾在 sync 模式下讨论, 理论上有用, 但在 pipeline 模式下的 cache 维护复杂度会进一步上升. 优先级低.
5. **放弃 batch-level 重叠, 改 op-level 重叠**: Qualcomm 的 dspqueue 主要在 op-level 重叠 (单 batch 内 op 之间的流水). 如果 batch-level 切不动, op-level 可能更现实. 但这同样依赖 dspqueue 化的 batch 协议.

---

附录: 关键 commit / log 文件参考

- /home/zhouwg/develop/ggml-hexagon/ggml/src/ggml-hexagon/ggml-hexagon-jz.cpp: graph_compute_batch (Phase 1-8), pipeline_worker_loop
- /home/zhouwg/develop/ggml-hexagon/scripts/ggml-hexagon.cfg: pipeline_mode, ion_sync_mode, dsp_cache_mode
- /home/zhouwg/develop/ggml-hexagon/log_test-d.txt: Test D 抓取的 logcat, 验证 floor 管理正确
- /home/zhouwg/develop/ggml-hexagon/docs/backend/jz-ggml-hexagon/algotype29-perf-analysis-en-20260711.md: JZ vs Qualcomm 性能基线
- /home/zhouwg/develop/ggml-hexagon/docs/backend/jz-ggml-hexagon/ion-mempool-vs-perbuffer-analysis-20260713.md: ION mempool 选型与 PP 性能分析
