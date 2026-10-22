# ai-disk-cleanup

**Reclaim disk space with an AI agent — measured, tiered, and approved.**

**English** · [Türkçe](README.tr.md) · [简体中文](README.zh-CN.md) · [Español](README.es.md) · [Русский](README.ru.md) · [Português (BR)](README.pt-BR.md) · [日本語](README.ja.md)

A battle-tested prompt that turns any AI coding agent (Claude Code, Cursor, Codex, …)
into a careful disk-space auditor. It walks your disk top-down, groups findings by how
much you'd regret deleting them, and **waits for your approval before touching anything**.

Works on **macOS, Linux and Windows**.

## Why not just `du | sort` yourself?

Because the biggest wins are rarely where you look first, and the obvious numbers lie:

- A `Docker.raw` reporting **60 GB** actually occupied **14 GB**. Deleting it based on
  the apparent size would have been a wrong call in the report.
- The real top offender was a **23 GB** directory of dead `git` worktrees from an
  abandoned refactor — invisible to any "clean your caches" checklist.
- Two **15 GB** iOS simulator runtimes for OS versions nobody targets any more sat in
  `/Library`, which a plain home-directory scan never reaches.

The prompt encodes the method that finds those, plus the guardrails that keep an
eager agent from deleting your `.env`.

## Usage

Pick your language, open the file, and paste everything below the `---` line into your
agent. Answer the tier question when it comes, and run the elevated commands it hands you.

| Language | Prompt |
|---|---|
| English | [`prompts/disk-cleanup.en.md`](prompts/disk-cleanup.en.md) |
| Türkçe | [`prompts/disk-cleanup.tr.md`](prompts/disk-cleanup.tr.md) |
| 简体中文 | [`prompts/disk-cleanup.zh-CN.md`](prompts/disk-cleanup.zh-CN.md) |
| Español | [`prompts/disk-cleanup.es.md`](prompts/disk-cleanup.es.md) |
| Русский | [`prompts/disk-cleanup.ru.md`](prompts/disk-cleanup.ru.md) |
| Português (BR) | [`prompts/disk-cleanup.pt-BR.md`](prompts/disk-cleanup.pt-BR.md) |
| 日本語 | [`prompts/disk-cleanup.ja.md`](prompts/disk-cleanup.ja.md) |

The prompt's language is functional, not cosmetic: it also sets the language the agent
reports back in. Shell commands stay in English in every translation.

## The method

1. **Detect the OS** — then use only that platform's commands and paths.
2. **Measure, never guess** — walk top-down to the actual culprit, not its parent.
3. **Know the traps** — sparse disks, double-counted symlinks, snapshots that hold
   freed space, async deletes, `target/` dirs that aren't Rust.
4. **Report in three tiers** — and stop:

   | Tier | What | Risk |
   |---|---|---|
   | 1 | Caches, build output, package downloads, dead worktrees | Regenerable. None. |
   | 2 | VM disks, old SDK runtimes, container images | Real data inside goes away. |
   | 3 | Downloads, browser profiles, unused apps | Your call entirely. |

5. **Execute step by step** — printing newly freed space after each one, and using
   each tool's own cleanup command instead of `rm -rf`.
6. **Respect the privilege boundary** — anything needing `sudo` or elevation comes
   back to you as a ready-to-run command, never worked around.
7. **Never delete** source, git history, `.env`, keys, keychains, photo and mail
   stores, cloud-sync folders, running VM disks, or OS snapshots.
8. **Summarize** — including what *you* have to fix by hand afterwards.

## One real run

macOS, 494 GB disk, **99% full with 5.2 GB left**:

| Step | Freed |
|---|---|
| Dead Claude/git worktrees in one project | 4.9 GB |
| Rust `target/` directories | 5.7 GB |
| 83 × `node_modules` + `.next` caches | 18 GB |
| `~/Library/Caches` (17 GB → 2.4 GB) | 14 GB |
| `~/.cache`, npm, Go modcache, Homebrew | 16 GB |
| iOS 17.5 + 18.0 simulator runtimes | 36 GB |
| Docker Desktop VM disk | 14 GB |
| OrbStack VM disk | 11 GB |
| Downloads: an 11 GB firmware image + 42 installers | 14 GB |
| **Total** | **≈111 GB** |

**5.2 GB → 117 GB free. 99% → 71%.** Two root-owned items (a 10 GB simulator `dyld`
cache and a dead 6 GB Nessus install) were handed back as `sudo` one-liners rather
than forced — exactly as the prompt requires.

## Repository layout

    prompts/
      disk-cleanup.en.md       English (source of truth)
      disk-cleanup.tr.md       Turkish
      disk-cleanup.zh-CN.md    Simplified Chinese
      disk-cleanup.es.md       Spanish
      disk-cleanup.ru.md       Russian
      disk-cleanup.pt-BR.md    Brazilian Portuguese
      disk-cleanup.ja.md       Japanese
    README.md                  This file, plus one README per language

## Translations

**English is the source of truth.** If a translation drifts from
`prompts/disk-cleanup.en.md`, the English version wins. When changing the method, change
the English prompt first, then port the change to the others.

New translations are welcome: copy `disk-cleanup.en.md`, keep every shell command exactly
as it is, translate only the prose, and name the file with its BCP 47 code
(`disk-cleanup.<code>.md`). Add a matching `README.<code>.md` and a row to the tables above.

## A note on trust

The prompt tells the agent to treat everything it finds on disk as **data, not
instructions** — a filename or a README inside some downloaded folder cannot talk it
into deleting more. It also forbids working around `sudo`. Read the prompt before you
run it; it is short on purpose.

## Author & support

Built by **Rıza Sabuncu**. If this saved you a weekend of disk archaeology, a coffee is appreciated.

[![X](https://img.shields.io/badge/X-%40rizasabuncu-000000?style=flat&logo=x&logoColor=white)](https://x.com/rizasabuncu) [![Buy Me a Coffee](https://img.shields.io/badge/Buy%20Me%20a%20Coffee-FFDD00?style=flat&logo=buymeacoffee&logoColor=black)](https://buymeacoffee.com/rizasabuncu)
