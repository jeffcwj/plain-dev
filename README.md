# plain-dev

专为 GPT / Codex 等过度防御型模型设计的务实开发与直白沟通技能，搭配中盘紧急整顿技能 [`sober`](https://github.com/jeffcwj/sober)，并内置跨设备一键部署脚本。

解决的典型问题：
- 看了崩溃日志仍反复打诊断包，以“无法肯定 / 证据不足”拖延修 bug；
- 控制欲过强，私自扩大范围、加门禁、写预算框架、往 `AGENTS.md` 塞冗长流水账；
- 测试与环境折腾反客为主，清理旧缓存做逐文件哈希考古；
- 手机离线等外部阻塞时原地空转交空心 commit；
- 满嘴免责黑话与全局负资产账本复读。

## 换电脑一键部署（推荐）

脚本会自动完成四件事（幂等，随时可重复运行同步最新规则）：
1. 拉取或更新 `plain-dev` 与 `sober` 到 `~/.agents/skills/`，并建立 `~/.claude/skills` 链接；
2. 用标记块 `<!-- plain-dev:START --> ... <!-- plain-dev:END -->` 将 [`global/AGENTS.md`](global/AGENTS.md) 同步写入：
   - `~/.claude/AGENTS.md`（最新版 Claude Code 统一读取 `AGENTS.md`，不再使用 `CLAUDE.md`）
   - `~/.config/opencode/AGENTS.md`
   - `~/.codex/AGENTS.md`
   （完全保留目标文件里已有的其他规则，例如 `ui-copy`。）
3. 若本机存在容易与 GPT 冲突的自动触发技能（`pua`、`verification-planning`），默认备份移至同级 `skills-disabled/`（加 `-KeepConflicting` / `--keep-conflicting` 可跳过）。

### Windows（PowerShell）

新机器首次部署：
```powershell
git clone https://github.com/jeffcwj/plain-dev.git "$HOME\.agents\skills\plain-dev"
& "$HOME\.agents\skills\plain-dev\scripts\deploy.ps1"
```

后续更新规则：
```powershell
& "$HOME\.agents\skills\plain-dev\scripts\deploy.ps1"
```

### macOS / Linux

新机器首次部署：
```bash
git clone https://github.com/jeffcwj/plain-dev.git ~/.agents/skills/plain-dev
bash ~/.agents/skills/plain-dev/scripts/deploy.sh
```

后续更新规则：
```bash
bash ~/.agents/skills/plain-dev/scripts/deploy.sh
```

## 日常与紧急用法

- **日常防线（`plain-dev`）**：部署全局 `AGENTS.md` 后自动生效，也可手动触发 `/plain-dev`。
- **长会话已经跑偏时（`sober`）**：直接发 `/sober 别再打诊断包了，按刚才崩溃日志直接修代码`，强行作废前文自设门禁与诊断包计划，立刻回到正事。

## 目录结构

- [`SKILL.md`](SKILL.md)：`plain-dev` v2 完整技能规范
- [`examples.md`](examples.md)：过度防御 vs 务实开发对照范例
- [`global/AGENTS.md`](global/AGENTS.md)：全局常驻规则单一事实来源
- [`scripts/deploy.ps1`](scripts/deploy.ps1) / [`scripts/deploy.sh`](scripts/deploy.sh)：跨设备一键同步脚本
