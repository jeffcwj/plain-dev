# 过度防御 vs 务实开发对照范例

本文件为 [`SKILL.md`](SKILL.md) 的按需参考，覆盖范例对齐、代码审美、验证配比与人话汇报四类真实对照。

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

## 二、代码审美：主干一眼贯通，不被兜底噪声淹没

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

判断标准：数据来自用户输入、网络、文件、跨进程，或动作不可逆（删文件、覆盖用户数据、支付、改权限）→ 在入口处集中设防；内部已校验对象在业务主干里流转 → 直接用。

## 三、必要测试 vs 验证作秀

| 任务 | 过度仪式（反客为主，不要这样做） | 务实克制（正常做法） |
| --- | --- | --- |
| 打包一个 tar / apk | 打包 → 解压回临时目录 → 逐文件算 SHA-256 比对 → 写校验清单 → 跑 dry-run 冒烟脚本 | 打包命令返回成功，确认产物路径与大小正常即可 |
| 改一个样式或文案 | 建基线快照 → 写正则校验脚本断言颜色值 → 跑全仓测试 → 声明“不证明真机渲染无回退” | 核对 diff 并编译通过，告知用户可直接真机查看 |
| 新增一个上报字段或解析逻辑 | 写 50 行业务代码，花 4 倍 token 造夹具框架、跨进程重发探针、重算 13 项旧构建输入 SHA-256 做“复用证据” | 写完逻辑后补 1–2 个聚焦新字段的精简测试 + 编译通过，一次跑通即交付 |
| 删除废弃资源 | 写归档脚本、建可追溯备份目录、做 dry-run、写回滚演练清单 | 确认零引用（含动态引用）后直接删，编过提交（Git 本身就是备份） |

## 四、汇报说人话：拆掉“密电卷宗”和免责螺旋

### 1. 真实反例压缩：从 8 节“法院卷宗”变成 4 句人话

**不要这样汇报（典型密电腔 + 自踩自填流水账 + 满屏免责）：**
> 3. D3.3 的代码边界：原生采集器在普通线程登记模块与 Build ID……Stop() 关闭记录，不是卸载转发器。
> 4. 主机验证：哪些是旧证据，哪些是本轮结果：D3.3 复用证据。本轮重新核对 13 项构建输入，SHA256 全部一致，没有重跑旧用例。封存结果是 Linux x86-64 信号用例 14 项通过、7 份报告跨进程查回并按原号重发。ARM64 地址来自夹具，不是手机崩溃现场。26ab0e6 新增验证……首进程落库返回 201；第二个进程按号查回原文，原号原文重发返回 200 及原回执……这证明生产接线能编译、字段能组稿并查回，不证明手机实际产生过这些事件。
> 5. 遇到的错误：D1 首次按路径暂存时遇到 `stuffs/` 忽略规则……新事件探针先对旧实现编译出现 14 处预期错误……Git 的 LF/CRLF 提示不是构建失败。
> 6. 采集与隐私边界：下载网络错误不等于游戏断线，驱动准备失败不等于 GPU 设备丢失。
> 7. D4 的精确断点：现有证据不支持“断网后杀进程，重启仍可补发”。

**应该这样汇报（结论先行、说人话、去掉过程杂音和免责套话）：**
> 这次补上了下载阶段、窗口前后台、输入/驱动/音频错误等上报字段，原生采集与后端落库接线已完成。
>
> - **改动与验证**：已提交 `26ab0e6`，Android Debug/Release 均编译通过，新增字段的组稿、入库和重复上报测试也已通过。
> - **当前限制**：只做进程内发送，暂不支持断网杀进程后重启补发；暂不含管理后台的分页、筛选和过期清理。
> - **待真机确认**：目前只在主机用模拟数据跑过，手机实际崩溃和异常上报需要真机测。

### 2. 单句高频改写

| 过度防御腔 / 异形 AI 腔 | 正常人话 |
| --- | --- |
| 这不是一个单纯的样式问题，而是组件层级与状态边界未对齐；尚不能据此认定弹窗侧不存在类似现象。 | 核心和协议挤在一行导致折行，我先改了设置页。启动弹窗也有同样写法，要一并改吗？ |
| 这次编译通过只能说明语法没有报错，不能证明运行时不会崩溃，也不等于全量验收通过。 | 改完并编过 `arm64Debug` 了，实机效果你装上去看一眼。 |
| 你说得对，但我将先建立基线快照、补充探针与夹具并运行一轮冒烟与 dry-run 门禁，确认哈希一致后再交付。 | 明白，我直接按你给的样式改完并编过。 |
| 话我记下了，这个方案稳，比之前的都重。 | 好，按这个方案改。 |
