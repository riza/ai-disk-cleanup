#!/usr/bin/env python3
"""Feeds hook inputs to guard/disk_guard.py and checks its decisions.
Run: python3 tests/test_guard.py"""

import json
import os
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.realpath(__file__))
GUARD = os.path.join(HERE, "..", "guard", "disk_guard.py")

T = os.path.realpath(tempfile.mkdtemp())
HOME = os.path.join(T, "home")
WORK = os.path.join(T, "audit")
PROJ = os.path.join(HOME, "proj")
for d in (WORK, os.path.join(PROJ, "src"), os.path.join(PROJ, "node_modules", "pkg"),
          os.path.join(HOME, "Documents"), os.path.join(T, "elsewhere", "deep")):
    os.makedirs(d, exist_ok=True)
open(os.path.join(PROJ, "src", "main.c"), "w").write("x")
open(os.path.join(PROJ, ".gitignore"), "w").write("node_modules/\n")
subprocess.run(["git", "init", "-q"], cwd=PROJ, check=True)
os.symlink(os.path.join(T, "elsewhere"), os.path.join(HOME, "link"))

passed = failed = 0


def run(tool, tool_input, mode="plan", permission_mode="default"):
    env = dict(os.environ, HOME=HOME, AI_DISK_CLEANUP_MODE=mode)
    payload = {"tool_name": tool, "tool_input": tool_input, "cwd": WORK,
               "permission_mode": permission_mode, "hook_event_name": "PreToolUse"}
    r = subprocess.run([sys.executable, GUARD], input=json.dumps(payload),
                       capture_output=True, text=True, env=env)
    if r.returncode == 2:
        return "deny", r.stderr
    if r.returncode == 0 and r.stdout.strip():
        return json.loads(r.stdout)["hookSpecificOutput"]["permissionDecision"], r.stdout
    if r.returncode == 0:
        return "pass", ""
    return "error", r.stderr


def expect(label, want, tool, tool_input, **kw):
    global passed, failed
    got, detail = run(tool, tool_input, **kw)
    if got == want:
        passed += 1
        print("  ok   %s" % label)
    else:
        failed += 1
        print("  FAIL %s: wanted %s, got %s %s" % (label, want, got, detail.strip()[:160]))


def bash(c):
    return {"command": c}


print("plan mode: measurement passes through")
for c in ["du -xsh ~/* 2>/dev/null | sort -rh | head -20",
          "df -h",
          "find ~/lab -name node_modules -type d -prune -print0 | xargs -0 du -sk",
          "git -C %s status --porcelain" % PROJ,
          "git -C %s worktree list" % PROJ,
          "git -C %s check-ignore -q node_modules && echo ignored" % PROJ,
          "docker system df",
          "xcrun simctl runtime list",
          "tmutil listlocalsnapshots /",
          "brew cleanup -n",
          "LC_ALL=C sort -k2 /dev/null",
          "du -sk ~/Library/Caches/* 2>&1 | sort -rn | head"]:
    expect(c, "pass", "Bash", bash(c))

print("plan mode: anything that changes the disk is denied")
for c in ["rm -rf %s/node_modules" % PROJ,
          "sudo du -sh /",
          "find ~ -name '*.log' -delete",
          "find ~ -name x -exec rm {} +",
          "python3 -c 'import shutil; shutil.rmtree(\"/tmp/x\")'",
          "echo hi > %s/f" % WORK,
          "du -sh $(rm -rf /tmp/x)",
          "du -sh `rm -rf /tmp/x`",
          "ls; rm -rf /tmp/x",
          "ls && /bin/rm -rf /tmp/x",
          "xargs rm < list.txt",
          "sort -o out.txt in.txt",
          "awk 'BEGIN{system(\"rm -rf /tmp/x\")}'",
          "git branch -D old",
          "git worktree remove %s" % PROJ,
          "npm cache clean --force",
          "docker system prune -a",
          "bash -c 'rm -rf /tmp/x'",
          "cat <<EOF > x\nhi\nEOF",
          "du -sh x &",
          "du -sh ~\nrm -rf /tmp/x",
          "git log --output=/tmp/x"]:
    expect(c.splitlines()[0], "deny", "Bash", bash(c))

print("file tools: only cleanup-plan.txt in the working folder")
expect("write plan", "pass", "Write", {"file_path": os.path.join(WORK, "cleanup-plan.txt"), "content": "x"})
expect("write relative plan", "pass", "Write", {"file_path": "cleanup-plan-2.txt", "content": "x"})
expect("write elsewhere", "deny", "Write", {"file_path": os.path.join(HOME, ".zshrc"), "content": "x"})
expect("write plan name in other folder", "deny", "Write", {"file_path": os.path.join(HOME, "cleanup-plan.txt"), "content": "x"})
expect("edit settings", "deny", "Edit", {"file_path": os.path.join(WORK, ".claude", "settings.json")})
expect("powershell tool", "deny", "PowerShell", {"command": "Get-ChildItem"})
expect("read is untouched", "pass", "Read", {"file_path": "/etc/hosts"})

print("execute mode: allowed deletion shapes ask, in default mode only")
nm = os.path.join(PROJ, "node_modules")
expect("rm ignored node_modules asks", "ask", "Bash", bash("rm -rf -- '%s'" % nm), mode="execute")
expect("npm cache clean asks", "ask", "Bash", bash("npm cache clean --force"), mode="execute")
expect("worktree remove asks", "ask", "Bash", bash("git -C %s worktree remove %s/wt" % (PROJ, T)), mode="execute")
expect("simctl runtime delete asks", "ask", "Bash", bash("xcrun simctl runtime delete 0CD5E098-C20E"), mode="execute")
expect("measurement still passes", "pass", "Bash", bash("du -sh %s" % nm), mode="execute")
for pm in ("bypassPermissions", "acceptEdits", "auto", "dontAsk", "plan", None):
    expect("rm denied in permission mode %s" % pm, "deny", "Bash", bash("rm -rf -- '%s'" % nm),
           mode="execute", permission_mode=pm)

print("execute mode: path checks")
for label, c in [("tracked source", "rm -rf %s/src" % PROJ),
                 ("repo root", "rm -rf %s" % PROJ),
                 ("home", "rm -rf %s" % HOME),
                 ("Documents", "rm -rf %s/Documents" % HOME),
                 ("symlink", "rm -rf %s/link" % HOME),
                 ("through symlinked parent", "rm -rf %s/link/deep" % HOME),
                 ("relative", "rm -rf proj/node_modules"),
                 ("tilde", "rm -rf ~/proj/node_modules"),
                 ("variable", "rm -rf $HOME/proj/node_modules"),
                 ("glob", "rm -rf %s/node_modules/*" % PROJ),
                 ("two paths", "rm -rf %s %s/src" % (nm, PROJ)),
                 ("missing", "rm -rf %s/nope" % HOME),
                 ("root", "rm -rf /"),
                 ("chained", "rm -rf %s && echo done" % nm),
                 ("worktree --force", "git worktree remove --force %s/wt" % T),
                 ("docker --volumes", "docker system prune -a --volumes"),
                 ("sudo", "sudo rm -rf %s" % nm),
                 ("unknown tool", "shred -u %s/x" % HOME)]:
    expect(label, "deny", "Bash", bash(c), mode="execute")

print()
print("passed: %d   failed: %d" % (passed, failed))
sys.exit(1 if failed else 0)
