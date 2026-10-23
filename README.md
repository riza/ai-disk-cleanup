# ai-disk-cleanup

**Find what is filling your disk with an AI agent — without letting it delete anything you did not approve.**

[![X](https://img.shields.io/badge/X-%40rizasabuncu-000000?style=flat&logo=x&logoColor=white)](https://x.com/rizasabuncu) [![Buy Me a Coffee](https://img.shields.io/badge/Buy%20Me%20a%20Coffee-FFDD00?style=flat&logo=buymeacoffee&logoColor=black)](https://buymeacoffee.com/rizasabuncu)

**English** · [Türkçe](README.tr.md) · [简体中文](README.zh-CN.md) · [Español](README.es.md) · [Русский](README.ru.md) · [Português (BR)](README.pt-BR.md) · [日本語](README.ja.md)

A prompt and two small tools. The agent (Claude Code, Codex, Cursor, …) measures your
disk on macOS, Linux or Windows, explains every large item and asks you about each one.
By default it **never deletes anything itself**: it writes a plan, and you run the plan
with a script that checks every path again and asks y/N per item.

A prompt is only a request; an agent can ignore it. So this repository does not rely on
the prompt alone. The safety comes from where the deleting happens, and from a sandbox or
a hook that physically blocks the agent.

## Two modes

| | **Plan mode** (default) | **Execute mode** (opt-in) |
|---|---|---|
| Who deletes | You, by running `run-plan` | The agent, one approved item per command |
| What the agent may write | Only `cleanup-plan.txt` | Approved deletions, each one confirmed by you |
| What enforces it | OS sandbox (recommended) + the guard hook | The guard hook + Manual permission mode |
| Works with | Any agent | Claude Code on macOS, Linux or WSL2 |

Use plan mode unless you have a reason not to.

## Quick start — plan mode

**1. Start the agent in an empty folder, inside a sandbox.** The sandbox lets it read
your disk but write only inside that folder, enforced by the operating system.

Claude Code (macOS, Linux, WSL2):

```bash
mkdir -p ~/disk-audit && cd ~/disk-audit
```

```bash
claude --settings '{"sandbox": {"enabled": true, "allowUnsandboxedCommands": false, "failIfUnavailable": true}}'
```

Codex (macOS, Linux, WSL2 and native Windows):

```bash
codex --sandbox workspace-write --ask-for-approval on-request
```

Claude Code has no sandbox on native Windows; there, use Codex, or Claude Code inside WSL2,
or at least the guard hook below.

**2. Paste the prompt** in your language:

| Language | Prompt |
|---|---|
| English | [`prompts/disk-cleanup.en.md`](prompts/disk-cleanup.en.md) |
| Türkçe | [`prompts/disk-cleanup.tr.md`](prompts/disk-cleanup.tr.md) |
| 简体中文 | [`prompts/disk-cleanup.zh-CN.md`](prompts/disk-cleanup.zh-CN.md) |
| Español | [`prompts/disk-cleanup.es.md`](prompts/disk-cleanup.es.md) |
| Русский | [`prompts/disk-cleanup.ru.md`](prompts/disk-cleanup.ru.md) |
| Português (BR) | [`prompts/disk-cleanup.pt-BR.md`](prompts/disk-cleanup.pt-BR.md) |
| 日本語 | [`prompts/disk-cleanup.ja.md`](prompts/disk-cleanup.ja.md) |

The prompt's language also sets the language the agent answers in.

**3. Answer its questions.** It shows a numbered table, one item per row. You reply with
the numbers you want gone. It writes them to `cleanup-plan.txt`.

**4. Read the plan, then run it yourself** with `tools/run-plan.sh` (or `run-plan.ps1`)
from a clone of this repository. Read the script first; it is short.

```bash
bash run-plan.sh --dry-run cleanup-plan.txt
```

```bash
bash run-plan.sh cleanup-plan.txt
```

On Windows, in a normal (not elevated) PowerShell 7 window:

```powershell
pwsh -File run-plan.ps1 cleanup-plan.txt
```

## What run-plan checks

Before each item, and again after you answer y:

- the path is absolute and literal: no `~`, wildcards or `..`;
- it is not a symlink, junction or cloud placeholder, and no parent folder is one;
- it is not a protected location: system folders, your home and its top-level folders,
  keys and keychains, mail, photo libraries, cloud-sync folders;
- it is not the root of a git repository or worktree;
- inside a git repository, it is git-ignored, so it cannot be your source code;
- `cmd` items are a single command with no `sudo`, `rm`, pipes, chaining, redirection,
  `git worktree remove --force` or `docker … --volumes`.

It refuses to run as root or elevated. Items that need elevation are printed at the end
for you to check and run by hand. An empty answer or end of input means no.

## Execute mode (Claude Code)

Only if you want the agent itself to delete. Execute mode cannot use the sandbox, because
the sandbox blocks writes outside the working folder, so the guard hook and your
confirmation of every command are the protection.

1. Install the guard:

   ```bash
   mkdir -p ~/.ai-disk-cleanup && cp guard/disk_guard.py ~/.ai-disk-cleanup/
   ```

2. Put [`guard/settings.example.json`](guard/settings.example.json) into the audit
   folder as `.claude/settings.json`.
3. Start Claude Code there in **Manual** permission mode (not auto, not bypass):

   ```bash
   AI_DISK_CLEANUP_MODE=execute claude
   ```

4. Type "execute mode" in the chat.

The guard runs before every Bash and file-tool call, in every permission mode:

- **Plan mode** (`AI_DISK_CLEANUP_MODE` unset): only measurement commands pass — `du`,
  `df`, `ls`, `find` without `-delete`/`-exec`, `git status`, `docker system df` and
  similar. Everything else is blocked. File tools may write only `cleanup-plan*.txt` in
  the working folder. This is worth installing in plan mode too.
- **Execute mode:** additionally, a fixed set of deletion commands (`rm` of one checked
  path, `git worktree remove` without `--force`, `npm cache clean`, `xcrun simctl runtime
  delete`, …) is shown to you as a permission prompt. In any permission mode other than
  Manual the guard refuses them, so nothing is deleted without your click.
- It blocks `sudo`, interpreters (`python -c`, `awk`, `bash -c`), command substitution,
  redirection into files and multi-line commands. It fails closed: if Python is missing
  or the guard crashes, the hook exits with code 2 and the command is blocked.

Check that it works before you start: ask the agent to run `rm -rf /tmp/probe`. The guard
must refuse it.

## What protects you, and what does not

| Layer | Stops | Does not stop |
|---|---|---|
| Prompt rules | A cooperative agent | An agent that ignores them |
| Plan mode | The agent deleting anything | You approving a wrong item |
| run-plan checks | Symlinks, protected folders, un-ignored files in repos, `sudo`, chained commands | A wrong but valid path you said yes to |
| OS sandbox | Any write outside the folder, by any program the agent starts | Claude's file tools (they run outside it), MCP servers; native Windows for Claude Code |
| Guard hook | Non-measurement commands, writes outside the plan file, deletions you did not confirm | MCP tools, the PowerShell tool, tools other than Claude Code, you removing the hook |

What remains your responsibility:

- **Reading the table before you answer.** Sizes and "regenerable" are the agent's
  judgment, and both can be wrong.
- **Deleting is permanent.** `path` items bypass the trash. `quarantine` is reversible,
  but frees nothing until you purge it.
- **Backups.** A snapshot before cleaning is the best safety net, but a snapshot itself
  holds disk space, which is exactly what you are short of.
- **The Windows runner** (`run-plan.ps1`) has not yet been run on a Windows machine.
  Use `-DryRun` first, and report anything odd.

## Disclaimer

**Nothing is deleted without your explicit approval — not even caches.** If it deletes
anything you did not name, that is a bug: stop it and
[open an issue](https://github.com/riza/ai-disk-cleanup/issues).

This project is provided as is, without warranty. The commands run on your machine and
the outcome is your responsibility.

## Why not just `du | sort`?

Because the biggest wins are rarely where you look first, and the obvious numbers lie. In
the run below, a `Docker.raw` that showed **60 GB** occupied **14 GB**; the top offender was
**23 GB** of git worktrees from an abandoned refactor; and two **15 GB** simulator runtimes
sat in `/Library`, which a home-folder scan never reaches.

## One real run

macOS, 494 GB disk, **99% full with 5.2 GB left**. This run used an earlier version of the
prompt, in which the agent deleted directly:

| Step | Freed |
|---|---|
| Unused git worktrees in one project | 4.9 GB |
| Rust `target/` folders | 5.7 GB |
| 83 × `node_modules` + `.next` caches | 18 GB |
| `~/Library/Caches` (17 GB → 2.4 GB) | 14 GB |
| `~/.cache`, npm, Go module cache, Homebrew | 16 GB |
| iOS 17.5 + 18.0 simulator runtimes | 36 GB |
| Docker Desktop VM disk | 14 GB |
| OrbStack VM disk | 11 GB |
| Downloads: an 11 GB firmware image + 42 installers | 14 GB |
| **Total** | **≈111 GB** |

**5.2 GB → 117 GB free.** It also showed what this version fixes: the worktrees were
removed with `--force` without checking for uncommitted work, and both VM disks were
deleted while their engines were stopped, without looking at which volumes they held.

## Repository layout

    prompts/disk-cleanup.<lang>.md   The prompt, in seven languages (English is the source)
    tools/run-plan.sh                Runs a plan on macOS and Linux
    tools/run-plan.ps1               Runs a plan on Windows (PowerShell 7)
    guard/disk_guard.py              Claude Code PreToolUse guard
    guard/settings.example.json      Hook configuration for the audit folder
    tests/                           Tests for run-plan.sh and the guard

Run the tests with `bash tests/test_run_plan.sh` and `python3 tests/test_guard.py`.

## Translations

**English is the source of truth.** If a translation disagrees with
`prompts/disk-cleanup.en.md`, the English version wins. Change the English prompt first,
then the others. New translations are welcome: keep every command exactly as it is,
translate only the prose, and name the files with a BCP 47 code.

## Author & support

Built by **Rıza Sabuncu**. If this saved you a weekend of disk archaeology, a coffee is appreciated.

[![X](https://img.shields.io/badge/X-%40rizasabuncu-000000?style=flat&logo=x&logoColor=white)](https://x.com/rizasabuncu) [![Buy Me a Coffee](https://img.shields.io/badge/Buy%20Me%20a%20Coffee-FFDD00?style=flat&logo=buymeacoffee&logoColor=black)](https://buymeacoffee.com/rizasabuncu)
