#!/usr/bin/env python3
"""disk_guard.py — Claude Code PreToolUse guard for ai-disk-cleanup.

Plan mode (default): Bash may run measurement commands only, and the file tools
may write nothing but cleanup-plan*.txt in the working folder.

Execute mode (AI_DISK_CLEANUP_MODE=execute in the environment Claude Code was
started from): additionally, a fixed set of deletion command shapes is passed
to you as a permission prompt, after the target path has been checked. This
only happens in Manual ("default") permission mode; in any other mode the
deletion is refused.

Exit 2 blocks the tool call. Exit 0 with no output leaves the normal
permission flow in charge. The guard fails closed: if it cannot understand a
command, the command is refused.
"""

import json
import os
import re
import shlex
import subprocess
import sys

PLAN_FILE = re.compile(r"^cleanup-plan[\w.-]*\.txt$")
FILE_TOOLS = {"Write", "Edit", "MultiEdit", "NotebookEdit"}
SEPARATORS = {"|", "||", "&&", ";"}


def deny(reason):
    sys.stderr.write("ai-disk-cleanup guard: " + reason + "\n")
    sys.exit(2)


def ask(reason):
    print(json.dumps({"hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "ask",
        "permissionDecisionReason": "ai-disk-cleanup guard: " + reason,
    }}))
    sys.exit(0)


# ---------------------------------------------------------------- paths

def real_home():
    return os.path.realpath(os.path.expanduser("~"))


def is_protected(p):
    h = real_home()
    exact = {"/", "/System", "/Library", "/Applications", "/Users", "/usr", "/bin", "/sbin",
             "/etc", "/var", "/private", "/opt", "/home", "/root", "/boot", "/dev", "/proc",
             "/sys", "/tmp", "/Volumes", "/mnt", "/media", "/snap", "/srv"}
    exact |= {h} | {os.path.join(h, d) for d in (
        "Library", "Library/Caches", "Library/Application Support", "Library/Containers",
        "Library/Group Containers", "Documents", "Desktop", "Downloads", "Pictures", "Movies",
        "Music", "Videos", "Public", "Applications", ".config", ".local", ".local/share",
        ".ai-disk-cleanup-quarantine")}
    if p in exact:
        return True
    trees = ["/System", "/usr", "/bin", "/sbin", "/etc", "/boot", "/dev", "/proc", "/sys",
             "/private/etc", "/private/var/db"]
    trees += [os.path.join(h, d) for d in (
        ".ssh", ".gnupg", ".aws", ".kube", ".password-store", "Library/Keychains",
        "Library/Mobile Documents", "Library/CloudStorage", "Library/Mail", "Library/Messages",
        "Dropbox", "OneDrive", "Google Drive", "iCloud Drive")]
    if any(p == t or p.startswith(t + "/") for t in trees):
        return True
    return ".photoslibrary" in p


def git_repo_top(folder):
    try:
        r = subprocess.run(["git", "-C", folder, "rev-parse", "--show-toplevel"],
                           capture_output=True, text=True, timeout=20)
    except FileNotFoundError:
        d = folder
        while d != "/":
            if os.path.exists(os.path.join(d, ".git")):
                return "?"  # inside a repo but git is unavailable: treat as not ignored
            d = os.path.dirname(d)
        return None
    return r.stdout.strip() if r.returncode == 0 and r.stdout.strip() else None


def git_ignored(folder, p):
    try:
        r = subprocess.run(["git", "-C", folder, "check-ignore", "-q", "--", p],
                           capture_output=True, timeout=20)
    except FileNotFoundError:
        return False
    return r.returncode == 0


def path_problem(p):
    """Return why p must not be deleted, or None."""
    if not p.startswith("/"):
        return "not an absolute path"
    if "\n" in p:
        return "contains a newline"
    if any(c in p for c in "*?[]{}~$`\\"):
        return "contains shell special characters (wildcards, ~ or variables); give the literal absolute path"
    norm = p.rstrip("/") or "/"
    if any(seg in (".", "..") for seg in norm.split("/")[1:]):
        return "contains . or .. segments"
    if os.path.islink(norm):
        return "is a symbolic link; refusing to follow it"
    if not os.path.exists(norm):
        return "does not exist"
    parent = os.path.realpath(os.path.dirname(norm))
    real = os.path.join(parent, os.path.basename(norm))
    if real != norm:
        return "a parent folder is a symlink (really %s)" % real
    if norm.count("/") < 3:
        return "too close to the filesystem root"
    if is_protected(norm):
        return "protected location"
    if os.path.exists(os.path.join(norm, ".git")):
        return "is a git repository or worktree root"
    top = git_repo_top(parent)
    if top and not git_ignored(parent, norm):
        return "inside git repo %s and not git-ignored, so it may be your work" % top
    return None


# ---------------------------------------------------------------- read-only commands

ALWAYS = {"du", "df", "ls", "stat", "wc", "head", "tail", "cut", "grep", "egrep", "fgrep",
          "cat", "echo", "printf", "pwd", "cd", "whoami", "id", "uname", "sw_vers", "basename",
          "dirname", "realpath", "readlink", "test", "[", "true", "tr", "column", "nproc",
          "lsblk", "findmnt", "vm_stat", "pgrep", "ps", "uptime", "numfmt", "which", "getconf",
          "system_profiler", "lsof"}

HINT = ("Plan mode allows measurement commands only (du, df, ls, find without -delete/-exec, "
        "git status, docker system df, ...). Put deletions in cleanup-plan.txt for the user "
        "to run with run-plan. Do not try another way.")


def git_args(args):
    """Strip leading git global options; return (subcommand args) or None if unsupported."""
    i = 0
    while i < len(args):
        a = args[i]
        if a == "-C" and i + 1 < len(args):
            i += 2
        elif a in ("--no-pager", "-P"):
            i += 1
        elif a.startswith("-"):
            return None
        else:
            break
    return args[i:]


def readonly_ok(name, args):
    if any(a.startswith("--output") for a in args):
        return False
    if name in ALWAYS:
        return True
    if name == "sort":
        return not any(a == "-o" or a.startswith("-o") for a in args)
    if name == "uniq":
        return len([a for a in args if not a.startswith("-")]) <= 1
    if name == "date":
        return all(a.startswith("+") or a in ("-u", "-R") for a in args)
    if name == "file":
        return not any(a in ("-C", "--compile") for a in args)
    if name == "find":
        bad = {"-delete", "-exec", "-execdir", "-ok", "-okdir", "-fprint", "-fprint0",
               "-fprintf", "-fls"}
        return not any(a in bad for a in args)
    if name == "xargs":
        value_opts = {"-I", "-n", "-P", "-L", "-s", "-d", "-E", "-a"}
        i = 0
        while i < len(args):
            a = args[i]
            if a in ("-0", "--null", "-r", "--no-run-if-empty", "-t"):
                i += 1
            elif a in value_opts:
                i += 2
            elif a[:2] in value_opts and len(a) > 2:
                i += 1
            else:
                break
        rest = args[i:]
        return bool(rest) and rest[0] in {"du", "ls", "stat", "wc"} and readonly_ok(rest[0], rest[1:])
    if name == "diskutil":
        return args[:1] in (["info"], ["list"]) or args[:2] in (["apfs", "list"], ["apfs", "listSnapshots"])
    if name == "tmutil":
        return args[:1] in (["listlocalsnapshots"], ["listlocalsnapshotdates"])
    if name == "xcrun":
        return args[:2] == ["simctl", "list"] or args[:3] == ["simctl", "runtime", "list"]
    if name in ("docker", "podman"):
        return (args[:1] in (["ps"], ["images"], ["info"], ["version"]) or
                args[:2] in (["system", "df"], ["volume", "ls"], ["volume", "inspect"],
                             ["image", "ls"], ["container", "ls"], ["builder", "du"]))
    if name in ("orb", "orbctl"):
        return args[:1] in (["status"], ["list"], ["info"], ["version"])
    if name == "git":
        sub = git_args(args)
        if not sub:
            return False
        if sub[0] in ("status", "rev-parse", "check-ignore", "log", "ls-files", "count-objects"):
            return True
        if sub[0] == "worktree":
            return sub[1:2] == ["list"]
        if sub[0] == "branch":
            ro = {"--list", "-a", "-r", "-v", "-vv", "--all", "--remotes", "--merged",
                  "--no-merged", "--show-current", "--contains"}
            return all(a in ro for a in sub[1:])
        if sub[0] == "remote":
            return sub[1:] in ([], ["-v"])
        return False
    if name == "journalctl":
        return set(args) <= {"--disk-usage", "--user"} and "--disk-usage" in args
    if name == "snap":
        return args in (["list"], ["list", "--all"])
    if name == "flatpak":
        return args[:1] == ["list"]
    if name == "brew":
        return (args[:1] in (["--cache"], ["--prefix"], ["list"], ["info"], ["config"], ["--version"]) or
                (args[:1] == ["cleanup"] and ("-n" in args or "--dry-run" in args)))
    if name == "npm":
        return args[:2] == ["config", "get"] or args in (["--version"], ["-v"])
    if name == "pnpm":
        return args[:2] == ["store", "path"]
    if name == "yarn":
        return args[:2] == ["cache", "dir"]
    if name == "go":
        return args[:1] == ["env"]
    if name in ("pip", "pip3"):
        return args[:2] in (["cache", "dir"], ["cache", "info"], ["cache", "list"])
    if name == "uv":
        return args[:2] == ["cache", "dir"]
    return False


# ---------------------------------------------------------------- deletion shapes (execute mode)

def deletion_problem(name, args):
    """None if this is an allowed deletion shape; otherwise a reason string."""
    if name == "rm":
        operands, end = [], False
        for a in args:
            if not end and a == "--":
                end = True
            elif not end and re.fullmatch(r"-[rRf]+|--recursive|--force", a):
                continue
            elif not end and a.startswith("-"):
                return "rm option %s is not allowed" % a
            else:
                operands.append(a)
        if len(operands) != 1:
            return "rm must name exactly one absolute path"
        return path_problem(operands[0])
    if name == "git":
        sub = git_args(args) or []
        if sub[:2] == ["worktree", "prune"] and len(sub) == 2:
            return None
        if sub[:2] == ["worktree", "remove"]:
            if any(a in ("-f", "--force") for a in sub[2:]):
                return "git worktree remove --force can discard uncommitted work"
            return None if len(sub) == 3 else "git worktree remove takes exactly one path"
        return "only git worktree remove (without --force) and git worktree prune are allowed"
    if name == "npm" and args == ["cache", "clean", "--force"]:
        return None
    if name == "pnpm" and args == ["store", "prune"]:
        return None
    if name == "yarn" and args == ["cache", "clean"]:
        return None
    if name == "go" and args and args[0] == "clean" and set(args[1:]) <= {"-modcache", "-cache", "-testcache", "-fuzzcache"} and args[1:]:
        return None
    if name in ("pip", "pip3") and args == ["cache", "purge"]:
        return None
    if name == "uv" and args in (["cache", "clean"], ["cache", "prune"]):
        return None
    if name == "brew" and args[:1] == ["cleanup"]:
        return None
    if name == "flatpak" and args == ["uninstall", "--unused"]:
        return None
    if name == "xcrun" and (args == ["simctl", "delete", "unavailable"] or
                            (args[:3] == ["simctl", "runtime", "delete"] and len(args) == 4)):
        return None
    if name in ("docker", "podman"):
        if "--volumes" in args:
            return "--volumes deletes data volumes; remove volumes one by one by name"
        if args[:2] in (["image", "prune"], ["container", "prune"], ["builder", "prune"], ["system", "prune"]):
            return None
        if args[:2] in (["volume", "rm"], ["image", "rm"]) and len(args) > 2:
            return None
        if args[:1] == ["rmi"] and len(args) > 1:
            return None
    return "not a known cleanup command"


# ---------------------------------------------------------------- bash parsing

def split_segments(cmd):
    if "\n" in cmd.strip() or "\r" in cmd:
        deny("one command per line please; multi-line commands are not accepted. " + HINT)
    for pat, what in (("`", "backticks"), ("$(", "command substitution"),
                      ("<(", "process substitution"), (">(", "process substitution"),
                      ("<<", "here-documents")):
        if pat in cmd:
            deny(what + " is not allowed. " + HINT)
    lex = shlex.shlex(cmd, posix=True, punctuation_chars=True)
    lex.whitespace_split = True
    lex.commenters = ""
    try:
        tokens = list(lex)
    except ValueError as e:
        deny("could not parse the command (%s)" % e)

    segments, cur, i = [], [], 0
    while i < len(tokens):
        t = tokens[i]
        if t in SEPARATORS:
            segments.append(cur)
            cur = []
            i += 1
            continue
        if t in (">", ">>", "&>"):
            nxt = tokens[i + 1] if i + 1 < len(tokens) else ""
            if nxt != "/dev/null":
                deny("writing to files with redirection is not allowed (only to /dev/null). " + HINT)
            if cur and cur[-1].isdigit():
                cur.pop()
            i += 2
            continue
        if t == ">&":
            nxt = tokens[i + 1] if i + 1 < len(tokens) else ""
            if nxt not in ("1", "2"):
                deny("only 2>&1 style redirection is allowed")
            if cur and cur[-1].isdigit():
                cur.pop()
            i += 2
            continue
        if t == "<":
            i += 2  # reading a file is fine
            continue
        if t and all(c in "();<>|&" for c in t):
            deny("shell operator %r is not allowed. " % t + HINT)
        cur.append(t)
        i += 1
    segments.append(cur)
    return segments


def check_bash(cmd, mode, permission_mode):
    if not cmd.strip():
        sys.exit(0)
    segments = split_segments(cmd)
    deletions = []
    for seg in segments:
        words = list(seg)
        while words and re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*=.*", words[0]):
            words.pop(0)
        if not words:
            deny("empty command segment")
        name, args = words[0], words[1:]
        if "/" in name:
            deny("run commands by name, not by path (%s). " % name + HINT)
        if name in ("sudo", "doas", "su", "pkexec"):
            deny("elevated commands are never run by the agent. Add it to the plan as a "
                 "command for the user to run by hand.")
        if readonly_ok(name, args):
            continue
        if mode == "execute":
            problem = deletion_problem(name, args)
            if problem is None:
                deletions.append(" ".join(shlex.quote(w) for w in words))
                continue
            deny("refused: %s (%s). Report this to the user and stop; do not try another way."
                 % (" ".join(words), problem))
        deny("'%s' is not a measurement command. " % name + HINT)

    if not deletions:
        sys.exit(0)
    if len(segments) != 1:
        deny("one deletion per command, with nothing chained to it")
    if permission_mode != "default":
        deny("execute mode deletes only in Manual (default) permission mode, so the user "
             "confirms every deletion. Current mode: %s. Tell the user and stop." % permission_mode)
    ask("deletion requested: %s" % deletions[0])


def check_write(tool_input, cwd):
    path = tool_input.get("file_path") or tool_input.get("notebook_path") or ""
    if not path:
        deny("file tool call without a path")
    full = os.path.realpath(os.path.join(cwd, path))
    if os.path.dirname(full) == os.path.realpath(cwd) and PLAN_FILE.match(os.path.basename(full)):
        sys.exit(0)
    deny("the only file the agent may write is cleanup-plan.txt in the working folder")


def main():
    mode = os.environ.get("AI_DISK_CLEANUP_MODE", "plan").strip().lower() or "plan"
    if mode not in ("plan", "execute"):
        deny("AI_DISK_CLEANUP_MODE must be 'plan' or 'execute'")
    try:
        data = json.load(sys.stdin)
    except Exception:
        deny("could not read the hook input")
    tool = data.get("tool_name", "")
    tool_input = data.get("tool_input") or {}
    cwd = data.get("cwd") or os.getcwd()
    if tool in FILE_TOOLS:
        check_write(tool_input, cwd)
    elif tool == "Bash":
        check_bash(tool_input.get("command", ""), mode, data.get("permission_mode"))
    elif tool == "PowerShell":
        deny("this guard understands Bash only. On Windows use plan mode and run-plan.ps1.")
    sys.exit(0)


if __name__ == "__main__":
    main()
