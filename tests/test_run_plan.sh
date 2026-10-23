#!/usr/bin/env bash
# Exercises tools/run-plan.sh against a throwaway HOME. Run: bash tests/test_run_plan.sh
set -u
HERE=$(cd -P -- "$(dirname -- "$0")" && pwd -P)
RUN="$HERE/../tools/run-plan.sh"
T=$(mktemp -d) && T=$(cd -P -- "$T" && pwd -P)
trap 'rm -rf -- "$T"' EXIT
export HOME="$T/home"
pass=0; fail=0
ok()  { pass=$((pass + 1)); echo "  ok   $1"; }
bad() { fail=$((fail + 1)); echo "  FAIL $1"; }
exists()  { if [ -e "$1" ] || [ -L "$1" ]; then ok "$2"; else bad "$2"; fi; }
missing() { if [ -e "$1" ] || [ -L "$1" ]; then bad "$2"; else ok "$2"; fi; }
contains() { if printf '%s' "$1" | grep -qF -- "$2"; then ok "$3"; else bad "$3 (expected: $2)"; fi; }

setup() {
  rm -rf -- "$T/home" "$T/elsewhere"
  mkdir -p "$HOME/Documents" "$HOME/Downloads" "$HOME/proj/src" "$HOME/proj/node_modules/pkg" "$T/elsewhere/deep/dir"
  echo data > "$HOME/proj/src/main.c"
  echo junk > "$HOME/proj/node_modules/pkg/index.js"
  echo dmg  > "$HOME/Downloads/Installer.dmg"
  echo keep > "$HOME/Downloads/notes.txt"
  ( cd "$HOME/proj" && git init -q && printf 'node_modules/\n' > .gitignore && git add .gitignore src && git -c user.email=t@t -c user.name=t commit -qm init )
  ln -s "$HOME/proj/src" "$HOME/link-to-src"
  ln -s "$T/elsewhere/deep" "$HOME/linkdir"
}

plan() { printf '%s\n' "$@" > "$T/plan.txt"; }

echo "1. git-ignored build output is deleted after y"
setup
plan "1 | 1 | path | node_modules | $HOME/proj/node_modules"
out=$(printf 'y\n' | bash "$RUN" "$T/plan.txt" 2>&1)
missing "$HOME/proj/node_modules" "ignored node_modules removed"
contains "$out" "done: 1" "summary counts it"

echo "2. refusals: tracked source, repo root, symlink, symlinked parent, relative, protected, missing"
setup
plan "1 | 1 | path | src | $HOME/proj/src" \
     "2 | 1 | path | repo | $HOME/proj" \
     "3 | 1 | path | link | $HOME/link-to-src" \
     "4 | 1 | path | via link | $HOME/linkdir/dir" \
     "5 | 1 | path | relative | proj/node_modules" \
     "6 | 1 | path | docs | $HOME/Documents" \
     "7 | 1 | path | gone | $HOME/nope" \
     "8 | 1 | path | home | $HOME"
out=$(printf 'y\ny\ny\ny\ny\ny\ny\ny\n' | bash "$RUN" "$T/plan.txt" 2>&1)
exists "$HOME/proj/src/main.c" "tracked source kept"
exists "$HOME/proj/.git" "repo root kept"
exists "$HOME/link-to-src" "symlink kept"
exists "$T/elsewhere/deep/dir" "target behind symlinked parent kept"
exists "$HOME/Documents" "Documents kept"
contains "$out" "not git-ignored" "explains tracked-source refusal"
contains "$out" "git repository or worktree root" "explains repo-root refusal"
contains "$out" "symbolic link" "explains symlink refusal"
contains "$out" "parent folder is a symlink" "explains symlinked-parent refusal"
contains "$out" "not an absolute path" "explains relative-path refusal"
contains "$out" "protected location" "explains protected refusal"
contains "$out" "does not exist" "explains missing-path refusal"
contains "$out" "done: 0" "nothing was done"

echo "3. answers: n skips, empty skips, q stops"
setup
plan "1 | 3 | path | dmg | $HOME/Downloads/Installer.dmg" \
     "2 | 3 | path | notes | $HOME/Downloads/notes.txt" \
     "3 | 1 | path | node_modules | $HOME/proj/node_modules"
out=$(printf 'n\n\nq\n' | bash "$RUN" "$T/plan.txt" 2>&1)
exists "$HOME/Downloads/Installer.dmg" "n keeps the file"
exists "$HOME/Downloads/notes.txt" "empty answer keeps the file"
exists "$HOME/proj/node_modules" "q stops before later items"
out=$(bash "$RUN" "$T/plan.txt" < /dev/null 2>&1)
exists "$HOME/Downloads/Installer.dmg" "end of input deletes nothing"

echo "4. dry run and --only"
setup
plan "1 | 1 | path | node_modules | $HOME/proj/node_modules" \
     "2 | 3 | path | dmg | $HOME/Downloads/Installer.dmg"
out=$(bash "$RUN" --dry-run "$T/plan.txt" 2>&1)
exists "$HOME/proj/node_modules" "dry run keeps everything"
contains "$out" "would delete" "dry run says what it would do"
out=$(printf 'y\ny\n' | bash "$RUN" --only 2 "$T/plan.txt" 2>&1)
exists "$HOME/proj/node_modules" "--only leaves other items"
missing "$HOME/Downloads/Installer.dmg" "--only handles the named item"

echo "5. quarantine moves instead of deleting"
setup
plan "1 | 3 | quarantine | dmg | $HOME/Downloads/Installer.dmg"
out=$(printf 'y\n' | bash "$RUN" "$T/plan.txt" 2>&1)
missing "$HOME/Downloads/Installer.dmg" "original location emptied"
if ls "$HOME"/.ai-disk-cleanup-quarantine/*/1-Installer.dmg >/dev/null 2>&1; then ok "file is in quarantine"; else bad "file is in quarantine"; fi
contains "$out" "still use disk space" "warns that quarantine frees nothing yet"

echo "6. cmd items"
setup
plan "1 | 1 | cmd | sudo | sudo du -sh /" \
     "2 | 1 | cmd | chain | echo a; echo b" \
     "3 | 1 | cmd | force | git -C $HOME/proj worktree remove --force /x" \
     "4 | 1 | cmd | rm | rm -rf $HOME/Downloads" \
     "5 | 2 | cmd | volumes | docker system prune -a --volumes" \
     "6 | 1 | cmd | glob | ls $HOME/*" \
     "7 | 1 | cmd | harmless | touch $HOME/cmd-ran"
out=$(printf 'y\ny\ny\ny\ny\ny\ny\n' | bash "$RUN" "$T/plan.txt" 2>&1)
contains "$out" "uses 'sudo'" "sudo refused"
contains "$out" "shell operators" "chained command refused"
contains "$out" "without --force" "worktree --force refused"
contains "$out" "uses 'rm'" "rm in cmd refused"
contains "$out" "--volumes" "docker --volumes refused"
exists "$HOME/Downloads/notes.txt" "Downloads survived the rm cmd item"
exists "$HOME/cmd-ran" "allowed cmd item ran after y"

echo "7. malformed lines and non-numeric IDs"
setup
plan "this is not a plan line" "x | 1 | path | bad id | $HOME/proj/node_modules"
out=$(printf 'y\n' | bash "$RUN" "$T/plan.txt" 2>&1)
contains "$out" "malformed" "malformed line reported"
contains "$out" "not a number" "bad ID reported"
exists "$HOME/proj/node_modules" "nothing deleted"

echo
echo "passed: $pass   failed: $fail"
[ "$fail" -eq 0 ]
