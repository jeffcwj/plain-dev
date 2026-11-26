# 过度防御 vs 务实开发对照范例

本文件为 [`SKILL.md`](SKILL.md) 的按需参考，覆盖范例对齐、修 Bug 停打诊断包、代码审美、验证与清理、以及人话汇报五类真实对照。

## 一、贴合参考项目：别擅自“帮用户升级架构”

假设用户喂了一个简洁的旧项目：单文件 `ConfigStore.kt` 直接读写 JSON，主路径清晰，只在读文件处处理 `IOException`。

```kotlin
// 不写：嘴上说参考老项目，动手擅自“升级”成 6 个类的防御架构
interface ConfigRepositoryContract { /* 仅一个实现 */ }
data class FrozenConfigDraft(...)
class ConfigBoundaryGuard { /* 重复校验每个非空字段 */ }
class ConfigReadbackVerifier { /* 写完再读回算 SHA-256 */ }
class ConfigFallbackResolver { /* 读失败静默返回假默认配置 */ }

// 写：照着老项目的粒度和风格写，新模块与老模块像同一人所写
class ProfileStore(private val file: File) {
    fun load(): Profile = json.decodeFromString(file.readText())
    fun save(profile: Profile) {
        file.writeText(json.encodeToString(profile))
    }
}
```

## 二、修 Bug：看了日志直接修，别把用户当诊断包人肉测试机

| 场景 | 偏执死循环（不要这样做） | 务实修复（正常做法） |
| --- | --- | --- |
| 拿到崩溃堆栈，指向息屏恢复后 `EGL` 尺寸查询失败 | “这只说明退出前调用了尺寸查询，证据不足，尚不能肯定是否锁屏引起，我先打一版带 20 条埋点的诊断包你再测一次……”（连打 4 轮诊断包还不改一行修复代码） | 直接检查 `EGL` 恢复与尺寸查询路径，修掉空表面/失焦状态下的非法调用，编出可测包给用户验证；若仍复现再看新日志换方案 |
| 排查帧率慢，用户催着激进点别抠零点几毫秒 | 嘴上答应砍支线，转身花 20 个回合给离线统计脚本 `scale_window.py` 补边界单测（覆盖“只快一项”“差值刚好等于波动”） | 直接删掉无效分支，按影响最大的渲染/主路径动手改，上机测一次看真实帧率变化 |

## 三、代码审美：主干一眼贯通，不被兜底噪声淹没

### 1. 内部辅助函数：信任内部约定

```ts
// 不写：80% 篇幅都在防不存在的异常和空值，一眼看不出函数在干嘛
function formatServerLabel(server: ServerItem): string {
  try {
    if (!server || typeof server !== 'object') return 'Unknown';
    const name = typeof server.name === 'string' && server.name.trim()
      ? server.name.trim()
      : 'Unnamed';
    const port = Number.isInteger(server.port) && server.port > 0 ? server.port : 7777;
    return `${name}:${port}`;
  } catch {
    return 'Unknown';
  }
}

// 写：干净直白，一眼看清逻辑
function formatServerLabel(server: ServerItem): string {
  return `${server.name.trim()}:${server.port}`;
}
```

### 2. 什么时候必须设防（集中放在真实外部边界）

```kotlin
// 该设防：外部用户选择的不可信文件 + 磁盘 I/O 边界
fun importUserBackup(uri: Uri): AppConfig {
    val raw = contentResolver.openInputStream(uri)?.use { it.bufferedReader().readText() }
        ?: throw IOException("无法读取所选备份文件")
    return json.decodeFromString<AppConfig>(raw)
}
```

判断标准：数据来自用户输入、网络、文件、跨进程，或动作不可逆（删用户正式数据、支付、改权限）→ 在入口集中设防；内部已校验对象在业务主干流转 → 直接用。

## 四、必要测试、清理与阻塞：把时间花在刀刃上

| 任务 | 过度仪式 / 空转内卷（不要这样做） | 务实克制（正常做法） |
| --- | --- | --- |
| 清理 300G 工程里的旧缓存和废弃包 | 逐个比对 678 个旧文件的 SHA-256、核对能否从 APK 还原、最后释放 `0 B` 写进文档提交；再顺手写套“写入预算系统 + 58 个主机单测”，干了 10 小时 | 确认旧构建目录、重复归档和淘汰 APK 不再使用后直接删干净，几分钟把体积压下来并报释放空间 |
| 打包一个 APK / tar | 打包成功后自己写个解析脚本验清单，脚本正则写错于是宣布“不能报完成，先修校验脚本再核一轮” | 删掉自造脚本，直接用 `aapt2` / `apksigner` 一行看结果，正常就交付 |
| 改一个样式或文案 | 建基线快照 → 写正则校验脚本断言颜色值 → 跑全仓测试 → 声明“不证明真机渲染无回退” | 核对 diff 并编译通过，告知用户可直接真机查看 |
| 手机离线 / 等真机复现 | 干不了正事就翻旧日志写“证据缺口”提交空 commit，顺便给离线工具补边界单测 | 一句话说明手机离线，等恢复连接后再装包测试，直接结束本轮 |

## 五、汇报说人话：拆掉“密电卷宗”和负资产复读机

### 1. 真实反例压缩

**不要这样汇报（密电腔 + 负资产复读机 + 空心提交）：**
> ToGLES 旧测量目录的 678 个文件和两份 APK 都原地保留，本轮实际释放 0 B……已写入实施计划，本地提交 e19e2a7。本轮未构建、未操作手机。这轮只在主机验证，不拿磁盘清理或历史观战数据充当实战成绩。两档骁龙的正式整局验收仍是 0/4，联发科也还没验。

**应该这样汇报（结论先行、只说本轮正事）：**
> 已删掉旧构建缓存、淘汰测试包和重复备份，共释放 126 GB（当前工程不含原版数据包占 118 GB）。备份脚本也改成了只存差异文件，避免以后再暴涨。

### 2. 单句高频改写

| 过度防御腔 / 推责口头禅 | 正常人话 |
| --- | --- |
| 现有证据不足，无法肯定是否由该路径触发，我先打一版诊断包加日志确认后再决定是否修复。 | 堆栈已经指向 `EGL` 切后台尺寸失效，我先按这个根因把判空和重建补上，编好包你直接试。 |
| 这次编译通过只能说明语法没有报错，不能证明运行时不会崩溃，也不等于全量验收通过。 | 改完并编过 `arm64Debug` 了，实机效果你装上去看一眼。 |
| 正式整局验收仍是 0/4，本轮未改引擎、未构建、未操作手机，不拿磁盘清理充当实战成绩。 | （整句删掉，用户根本没问这些。） |
| 你说得对，但我将先建立基线快照、补充探针与夹具并运行一轮冒烟门禁。 | 明白，我直接按你的意思改完并编过。 |
