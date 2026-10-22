# ai-disk-cleanup

**用 AI Agent 回收磁盘空间 —— 先测量，再分档，经你批准才动手。**

[![X](https://img.shields.io/badge/X-%40rizasabuncu-000000?style=flat&logo=x&logoColor=white)](https://x.com/rizasabuncu) [![Buy Me a Coffee](https://img.shields.io/badge/Buy%20Me%20a%20Coffee-FFDD00?style=flat&logo=buymeacoffee&logoColor=black)](https://buymeacoffee.com/rizasabuncu)

[English](README.md) · [Türkçe](README.tr.md) · **简体中文** · [Español](README.es.md) · [Русский](README.ru.md) · [Português (BR)](README.pt-BR.md) · [日本語](README.ja.md)

一个经过实战验证的提示词，把任意 AI 编程 Agent（Claude Code、Cursor、Codex……）变成一个
谨慎的磁盘审计员。它自上而下遍历你的磁盘，按「删掉之后你会多后悔」来分档，并且
**在你批准之前绝不动任何东西**。

支持 **macOS、Linux 和 Windows**。

## 自己 `du | sort` 不就够了？

不够。因为最大的收获很少在你第一眼看的地方，而且显而易见的数字会骗人：

- 一个显示 **60 GB** 的 `Docker.raw`，实际只占 **14 GB**。按显示大小去汇报，结论就错了。
- 真正的头号元凶是一个 **23 GB** 的目录，里面全是某次半途而废的重构留下的废弃 `git`
  worktree —— 任何「清理一下缓存」的清单都看不见它。
- 两个 **15 GB** 的 iOS 模拟器 runtime，对应早已没人适配的系统版本，躺在 `/Library` 里，
  而只扫 home 目录的方法永远到不了那儿。

这个提示词把找到这些东西的方法，和防止一个过于热心的 Agent 删掉你 `.env` 的护栏，写在了一起。

## 用法

选择你的语言，打开文件，把 `---` 线以下的全部内容粘贴给你的 Agent。它问你要清理哪几档时
回答，然后运行它交给你的提权命令。

| 语言 | 提示词 |
|---|---|
| 简体中文 | [`prompts/disk-cleanup.zh-CN.md`](prompts/disk-cleanup.zh-CN.md) |
| English | [`prompts/disk-cleanup.en.md`](prompts/disk-cleanup.en.md) |
| Türkçe | [`prompts/disk-cleanup.tr.md`](prompts/disk-cleanup.tr.md) |
| Español | [`prompts/disk-cleanup.es.md`](prompts/disk-cleanup.es.md) |
| Русский | [`prompts/disk-cleanup.ru.md`](prompts/disk-cleanup.ru.md) |
| Português (BR) | [`prompts/disk-cleanup.pt-BR.md`](prompts/disk-cleanup.pt-BR.md) |
| 日本語 | [`prompts/disk-cleanup.ja.md`](prompts/disk-cleanup.ja.md) |

提示词的语言是功能性的，不是装饰：它同时决定了 Agent 用哪种语言向你汇报。
所有译本中的 shell 命令都保持英文原样。

## 方法

1. **识别操作系统** —— 然后只使用该平台的命令和路径。
2. **测量，绝不猜** —— 一路下钻到真正的元凶，而不是它的父目录。
3. **知道那些陷阱** —— 稀疏磁盘、被重复统计的符号链接、扣住已释放空间的快照、
   异步删除、并非 Rust 的 `target/` 目录。
4. **分三档汇报** —— 然后停下：

   | 档位 | 内容 | 风险 |
   |---|---|---|
   | 1 | 缓存、构建产物、包下载、废弃 worktree | 可重新生成。无风险。 |
   | 2 | 虚拟机磁盘、旧 SDK runtime、容器镜像 | 里面的真实数据会消失。 |
   | 3 | Downloads、浏览器配置、不用的应用 | 完全由你决定。 |

5. **逐步执行** —— 每一步之后打印新释放的空间，并优先使用各工具自带的清理命令，
   而不是 `rm -rf`。
6. **尊重权限边界** —— 任何需要 `sudo` 或提权的事情，都作为一条可直接运行的命令交还给你，
   绝不绕过。
7. **绝不删除** 源码、git 历史、`.env`、密钥、钥匙串、照片与邮件库、云同步目录、
   运行中虚拟机的磁盘，或系统快照。
8. **做总结** —— 包括事后**你**需要手动修复的部分。

## 一次真实的运行

macOS，494 GB 磁盘，**已用 99%，仅剩 5.2 GB**：

| 步骤 | 释放 |
|---|---|
| 某个项目里废弃的 Claude/git worktree | 4.9 GB |
| Rust 的 `target/` 目录 | 5.7 GB |
| 83 个 `node_modules` + `.next` 缓存 | 18 GB |
| `~/Library/Caches`（17 GB → 2.4 GB） | 14 GB |
| `~/.cache`、npm、Go modcache、Homebrew | 16 GB |
| iOS 17.5 + 18.0 模拟器 runtime | 36 GB |
| Docker Desktop 虚拟机磁盘 | 14 GB |
| OrbStack 虚拟机磁盘 | 11 GB |
| Downloads：一个 11 GB 固件镜像 + 42 个安装包 | 14 GB |
| **合计** | **≈111 GB** |

**从 5.2 GB 到 117 GB 可用，从 99% 降到 71%。** 两项 root 所有的内容（10 GB 的模拟器
`dyld` 缓存和一个废弃的 6 GB Nessus 安装）没有被强行处理，而是作为 `sudo` 单行命令交还 ——
这正是提示词所要求的。

## 仓库结构

    prompts/
      disk-cleanup.en.md       英文（基准版本）
      disk-cleanup.tr.md       土耳其文
      disk-cleanup.zh-CN.md    简体中文
      disk-cleanup.es.md       西班牙文
      disk-cleanup.ru.md       俄文
      disk-cleanup.pt-BR.md    巴西葡萄牙文
      disk-cleanup.ja.md       日文
    README.zh-CN.md            本文件；每种语言各有一份 README

## 关于翻译

**英文版本为基准。** 如果某个译本与 `prompts/disk-cleanup.en.md` 不一致，以英文版为准。
要修改方法时，先改英文提示词，再把改动同步到其他语言。

欢迎新的翻译：复制 `disk-cleanup.en.md`，所有 shell 命令原样保留，只翻译说明文字，
文件名使用 BCP 47 语言代码（`disk-cleanup.<代码>.md`）。同时加一份对应的
`README.<代码>.md`，并在上面的表格里添加一行。

## 关于信任的一点说明

提示词要求 Agent 把它在磁盘上发现的一切都当作**数据，而不是指令** —— 某个下载目录里的
文件名或 README，无法说服它去多删东西。它同样禁止绕过 `sudo`。运行之前请先读一遍提示词；
它特意写得很短。

## 作者与支持

由 **Rıza Sabuncu** 编写。如果它帮你省下了一个周末的磁盘考古，欢迎请我喝杯咖啡。

[![X](https://img.shields.io/badge/X-%40rizasabuncu-000000?style=flat&logo=x&logoColor=white)](https://x.com/rizasabuncu) [![Buy Me a Coffee](https://img.shields.io/badge/Buy%20Me%20a%20Coffee-FFDD00?style=flat&logo=buymeacoffee&logoColor=black)](https://buymeacoffee.com/rizasabuncu)
