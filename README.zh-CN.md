# ai-disk-cleanup

**用 AI Agent 找出是什么占满了你的磁盘 —— 但不让它删除任何你没有批准的东西。**

[![X](https://img.shields.io/badge/X-%40rizasabuncu-000000?style=flat&logo=x&logoColor=white)](https://x.com/rizasabuncu) [![Buy Me a Coffee](https://img.shields.io/badge/Buy%20Me%20a%20Coffee-FFDD00?style=flat&logo=buymeacoffee&logoColor=black)](https://buymeacoffee.com/rizasabuncu)

[English](README.md) · [Türkçe](README.tr.md) · **简体中文** · [Español](README.es.md) · [Русский](README.ru.md) · [Português (BR)](README.pt-BR.md) · [日本語](README.ja.md)

一个提示词加两个小工具。Agent（Claude Code、Codex、Cursor……）在 macOS、Linux 或 Windows
上测量你的磁盘，解释每一个大项，并逐项询问你。默认情况下它**自己从不删除任何东西**：它写
一份计划，由你用一个脚本来执行；脚本会再次检查每条路径，并对每个条目询问 y/N。

提示词只是请求，Agent 可能会无视它。所以这个仓库不只依赖提示词。安全性来自删除发生在
哪里，以及一个从物理上拦住 Agent 的沙箱或 hook。

## 两种模式

| | **计划模式**（默认） | **执行模式**（需主动开启） |
|---|---|---|
| 谁来删除 | 你，通过运行 `run-plan` | Agent，每条命令一个已批准条目 |
| Agent 能写什么 | 只有 `cleanup-plan.txt` | 已批准的删除，每一条都由你确认 |
| 由什么强制保证 | 操作系统沙箱（推荐）+ guard hook | guard hook + 手动（Manual）权限模式 |
| 适用于 | 任何 Agent | macOS、Linux 或 WSL2 上的 Claude Code |

除非有理由，否则请使用计划模式。

## 快速开始 —— 计划模式

**1. 在一个空文件夹里、在沙箱中启动 Agent。** 沙箱允许它读取你的磁盘，但由操作系统强制
它只能在那个文件夹里写入。

Claude Code（macOS、Linux、WSL2）：

```bash
mkdir -p ~/disk-audit && cd ~/disk-audit
```

```bash
claude --settings '{"sandbox": {"enabled": true, "allowUnsandboxedCommands": false, "failIfUnavailable": true}}'
```

Codex（macOS、Linux、WSL2 以及原生 Windows）：

```bash
codex --sandbox workspace-write --ask-for-approval on-request
```

Claude Code 在原生 Windows 上没有沙箱；在那里请使用 Codex、WSL2 中的 Claude Code，或者
至少使用下面的 guard hook。

**2. 粘贴你所用语言的提示词：**

| 语言 | 提示词 |
|---|---|
| 简体中文 | [`prompts/disk-cleanup.zh-CN.md`](prompts/disk-cleanup.zh-CN.md) |
| English | [`prompts/disk-cleanup.en.md`](prompts/disk-cleanup.en.md) |
| Türkçe | [`prompts/disk-cleanup.tr.md`](prompts/disk-cleanup.tr.md) |
| Español | [`prompts/disk-cleanup.es.md`](prompts/disk-cleanup.es.md) |
| Русский | [`prompts/disk-cleanup.ru.md`](prompts/disk-cleanup.ru.md) |
| Português (BR) | [`prompts/disk-cleanup.pt-BR.md`](prompts/disk-cleanup.pt-BR.md) |
| 日本語 | [`prompts/disk-cleanup.ja.md`](prompts/disk-cleanup.ja.md) |

提示词的语言也决定了 Agent 用什么语言回答你。

**3. 回答它的问题。** 它会展示一张编号表格，每行一个条目。你回复想删除的编号，它把这些
写进 `cleanup-plan.txt`。

**4. 读一遍计划，然后自己运行它。** 使用本仓库克隆中的 `tools/run-plan.sh`（或
`run-plan.ps1`）。先读一遍脚本，它很短。

```bash
bash run-plan.sh --dry-run cleanup-plan.txt
```

```bash
bash run-plan.sh cleanup-plan.txt
```

在 Windows 上，在一个普通（非管理员）的 PowerShell 7 窗口中：

```powershell
pwsh -File run-plan.ps1 cleanup-plan.txt
```

## run-plan 会检查什么

每个条目之前检查一次，你回答 y 之后再检查一次：

- 路径是字面意义上的绝对路径：没有 `~`、通配符或 `..`；
- 它不是符号链接、junction 或云端占位文件，它的任何父目录也不是；
- 它不是受保护的位置：系统目录、你的主目录及其顶层目录、密钥和钥匙串、邮件、照片库、
  云同步目录；
- 它不是 git 仓库或 worktree 的根目录；
- 在 git 仓库内部时，它必须被 git ignore，因此不可能是你的源代码；
- `cmd` 条目只能是单条命令：没有 `sudo`、`rm`、管道、命令串联、重定向、
  `git worktree remove --force` 或 `docker … --volumes`。

它拒绝以 root 或管理员身份运行。需要提权的条目会在最后列出，供你检查后手动运行。空回答
或输入结束都视为"否"。

## 执行模式（Claude Code）

只有当你希望由 Agent 自己删除时才使用。执行模式无法使用沙箱，因为沙箱会阻止在工作目录
之外写入；所以保护来自 guard hook，以及你对每条命令的确认。

1. 安装 guard：

   ```bash
   mkdir -p ~/.ai-disk-cleanup && cp guard/disk_guard.py ~/.ai-disk-cleanup/
   ```

2. 把 [`guard/settings.example.json`](guard/settings.example.json) 放到检查用的文件夹里，
   命名为 `.claude/settings.json`。
3. 在那里以 **Manual（手动）** 权限模式启动 Claude Code（不是 auto，也不是 bypass）：

   ```bash
   AI_DISK_CLEANUP_MODE=execute claude
   ```

4. 在对话中输入 "execute mode"。

guard 会在每一次 Bash 和文件工具调用之前运行，在任何权限模式下都是如此：

- **计划模式**（未设置 `AI_DISK_CLEANUP_MODE`）：只放行测量命令 —— `du`、`df`、`ls`、
  不带 `-delete`/`-exec` 的 `find`、`git status`、`docker system df` 等。其他一切都会被拦截。
  文件工具只能写工作目录里的 `cleanup-plan*.txt`。在计划模式下也值得安装。
- **执行模式：** 另外，一组固定的删除命令（对一条已检查路径的 `rm`、不带 `--force` 的
  `git worktree remove`、`npm cache clean`、`xcrun simctl runtime delete` 等）会以权限确认的
  形式交给你。在 Manual 以外的任何权限模式下，guard 都会拒绝它们，所以不经你点击就不会
  删除任何东西。
- 它会拦截 `sudo`、解释器（`python -c`、`awk`、`bash -c`）、命令替换、写入文件的重定向
  以及多行命令。它在失败时保持关闭：如果缺少 Python 或 guard 崩溃，hook 以退出码 2 结束，
  命令被拦截。

开始之前先确认它在工作：让 Agent 运行 `rm -rf /tmp/probe`。guard 必须拒绝它。

## 什么能保护你，什么不能

| 层 | 能拦住 | 拦不住 |
|---|---|---|
| 提示词规则 | 配合的 Agent | 无视规则的 Agent |
| 计划模式 | Agent 删除任何东西 | 你批准了错误的条目 |
| run-plan 检查 | 符号链接、受保护目录、仓库中未被 ignore 的文件、`sudo`、串联命令 | 你答应了的、错误但合法的路径 |
| 操作系统沙箱 | Agent 启动的任何程序在文件夹外写入 | Claude 的文件工具（它们在沙箱外运行）、MCP 服务器；Claude Code 在原生 Windows 上 |
| Guard hook | 非测量命令、在计划文件之外写入、你未确认的删除 | MCP 工具、PowerShell 工具、Claude Code 以外的工具、你自己移除 hook |

仍然由你负责的部分：

- **回答之前先读表格。** 大小和"可重新生成"都是 Agent 的判断，两者都可能出错。
- **删除是永久的。** `path` 条目不经过回收站。`quarantine` 可以撤销，但在你清空之前不会
  腾出空间。
- **备份。** 清理前做一次快照是最好的保险，但快照本身也占用磁盘空间 —— 恰恰是你缺的东西。
- **Windows 脚本**（`run-plan.ps1`）尚未在 Windows 机器上运行过。请先用 `-DryRun`，遇到
  异常请反馈。

## 免责声明

**未经你明确批准，任何东西都不会被删除——哪怕是缓存。** 如果它删除了你没有点名的东西，
那就是一个 bug：请停止它，并[提交 issue](https://github.com/riza/ai-disk-cleanup/issues)。

本项目按"原样"提供，不提供任何担保。命令在你的机器上执行，结果由你自己负责。

## 自己 `du | sort` 不就够了？

不够。因为最大的收获很少在你第一眼看的地方，而且显而易见的数字会骗人。在下面这次运行中，
一个显示 **60 GB** 的 `Docker.raw` 实际只占 **14 GB**；头号元凶是某次半途而废的重构留下的
**23 GB** git worktree；还有两个 **15 GB** 的模拟器 runtime 躺在 `/Library` 里，只扫主目录的
方法永远到不了那儿。

## 一次真实的运行

macOS，494 GB 磁盘，**已用 99%，仅剩 5.2 GB**。这次运行用的是旧版提示词，由 Agent 直接删除：

| 步骤 | 释放 |
|---|---|
| 某个项目里无人使用的 git worktree | 4.9 GB |
| Rust 的 `target/` 目录 | 5.7 GB |
| 83 个 `node_modules` + `.next` 缓存 | 18 GB |
| `~/Library/Caches`（17 GB → 2.4 GB） | 14 GB |
| `~/.cache`、npm、Go 模块缓存、Homebrew | 16 GB |
| iOS 17.5 + 18.0 模拟器 runtime | 36 GB |
| Docker Desktop 虚拟机磁盘 | 14 GB |
| OrbStack 虚拟机磁盘 | 11 GB |
| Downloads：一个 11 GB 固件镜像 + 42 个安装包 | 14 GB |
| **合计** | **≈111 GB** |

**可用空间从 5.2 GB 到 117 GB。** 它也暴露了这一版修复的问题：worktree 是用 `--force` 删除
的，没有检查未提交的工作；两块虚拟机磁盘是在引擎停止时删除的，没有查看里面有哪些卷。

## 仓库结构

    prompts/disk-cleanup.<语言>.md   提示词，七种语言（英文为基准）
    tools/run-plan.sh                在 macOS 和 Linux 上执行计划
    tools/run-plan.ps1               在 Windows 上执行计划（PowerShell 7）
    guard/disk_guard.py              Claude Code 的 PreToolUse guard
    guard/settings.example.json      检查用文件夹的 hook 配置
    tests/                           run-plan.sh 和 guard 的测试

用 `bash tests/test_run_plan.sh` 和 `python3 tests/test_guard.py` 运行测试。

## 关于翻译

**英文版本为基准。** 如果某个译本与 `prompts/disk-cleanup.en.md` 不一致，以英文版为准。
先改英文提示词，再改其他语言。欢迎新的翻译：所有命令原样保留，只翻译说明文字，文件名
使用 BCP 47 语言代码。

## 作者与支持

由 **Rıza Sabuncu** 编写。如果它帮你省下了一个周末的磁盘考古，欢迎请我喝杯咖啡。

[![X](https://img.shields.io/badge/X-%40rizasabuncu-000000?style=flat&logo=x&logoColor=white)](https://x.com/rizasabuncu) [![Buy Me a Coffee](https://img.shields.io/badge/Buy%20Me%20a%20Coffee-FFDD00?style=flat&logo=buymeacoffee&logoColor=black)](https://buymeacoffee.com/rizasabuncu)
