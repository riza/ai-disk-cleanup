#!/usr/bin/env bash
# run-plan.sh — carry out an ai-disk-cleanup plan, one confirmed item at a time.
#
#   bash run-plan.sh [--dry-run] [--only 1,4,7] cleanup-plan.txt
#
# Every item is checked before anything happens and you answer y/N for each one.
# Nothing is deleted on an empty answer, on end of input, or on any refusal.
# Works with the bash 3.2 that ships with macOS. Never run it as root.

set -u

usage() {
  cat <<'EOF'
Usage: bash run-plan.sh [--dry-run] [--only 1,4,7] cleanup-plan.txt

  --dry-run   check every item and show what would happen; change nothing
  --only IDS  handle only these item IDs (comma-separated)

Plan lines:  ID | TIER | KIND | NOTE | TARGET
  KIND path        delete this file or directory (absolute path)
  KIND quarantine  move it to ~/.ai-disk-cleanup-quarantine (reversible, frees nothing yet)
  KIND cmd         run this single tool-native cleanup command
EOF
}

DRY=0
ONLY=""
PLAN=""
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY=1 ;;
    --only) shift; ONLY="${1:-}" ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "run-plan: unknown option: $1" >&2; usage >&2; exit 64 ;;
    *) PLAN="$1" ;;
  esac
  shift
done

[ -n "$PLAN" ] || { usage >&2; exit 64; }
[ -f "$PLAN" ] || { echo "run-plan: no such plan file: $PLAN" >&2; exit 66; }
if [ "$(id -u)" -eq 0 ]; then
  echo "run-plan: refusing to run as root. Run it as your normal user;" >&2
  echo "items that need elevation are printed at the end for you to run by hand." >&2
  exit 77
fi

OS=$(uname -s)
H=$(cd -P -- "$HOME" 2>/dev/null && pwd -P) || { echo "run-plan: cannot resolve \$HOME" >&2; exit 70; }
QDIR="$H/.ai-disk-cleanup-quarantine/$(date +%Y%m%d-%H%M%S)"

free_kb() { df -Pk "$H" | awk 'NR==2 {print $4}'; }
human() { awk -v k="$1" 'BEGIN { split("KB MB GB TB", u, " "); i = 1; while (k >= 1024 && i < 4) { k /= 1024; i++ } printf "%.1f %s", k, u[i] }'; }
trim() { local s=$1; s="${s#"${s%%[![:space:]]*}"}"; s="${s%"${s##*[![:space:]]}"}"; printf '%s' "$s"; }
dev_of() { if [ "$OS" = Darwin ]; then stat -f %d "$1"; else stat -c %d "$1"; fi; }

# Locations that are never deleted, whatever the plan says.
is_protected() {
  local p=$1
  case "$p" in
    /|/System|/Library|/Applications|/Users|/usr|/bin|/sbin|/etc|/var|/private|/opt|/home|/root|/boot|/dev|/proc|/sys|/tmp|/Volumes|/mnt|/media|/snap|/srv) return 0 ;;
    /System/*|/usr/*|/bin/*|/sbin/*|/etc/*|/boot/*|/dev/*|/proc/*|/sys/*|/private/etc/*|/private/var/db/*) return 0 ;;
    *.photoslibrary|*.photoslibrary/*) return 0 ;;
  esac
  case "$p" in
    "$H"|"$H/Library"|"$H/Library/Caches"|"$H/Library/Application Support"|"$H/Library/Containers"|"$H/Library/Group Containers") return 0 ;;
    "$H/Documents"|"$H/Desktop"|"$H/Downloads"|"$H/Pictures"|"$H/Movies"|"$H/Music"|"$H/Videos"|"$H/Public"|"$H/Applications") return 0 ;;
    "$H/.config"|"$H/.local"|"$H/.local/share") return 0 ;;
    "$H/.ssh"|"$H/.ssh/"*|"$H/.gnupg"|"$H/.gnupg/"*|"$H/.aws"|"$H/.aws/"*|"$H/.kube"|"$H/.kube/"*|"$H/.password-store"|"$H/.password-store/"*) return 0 ;;
    "$H/Library/Keychains"|"$H/Library/Keychains/"*|"$H/Library/Mobile Documents"|"$H/Library/Mobile Documents/"*) return 0 ;;
    "$H/Library/CloudStorage"|"$H/Library/CloudStorage/"*|"$H/Library/Mail"|"$H/Library/Mail/"*|"$H/Library/Messages"|"$H/Library/Messages/"*) return 0 ;;
    "$H/Dropbox"|"$H/Dropbox/"*|"$H/OneDrive"|"$H/OneDrive/"*|"$H/Google Drive"|"$H/Google Drive/"*|"$H/iCloud Drive"|"$H/iCloud Drive/"*) return 0 ;;
    "$H/.ai-disk-cleanup-quarantine") return 0 ;;
  esac
  return 1
}

# Prints a reason and returns 1 if the path must not be touched,
# returns 2 if it is fine but needs elevated rights, 0 if it may proceed.
check_path() {
  local p=$1 parent real depth top
  case "$p" in /*) ;; *) echo "not an absolute path"; return 1 ;; esac
  case "$p" in *'
'*) echo "contains a newline"; return 1 ;; esac
  case "$p" in */../*|*/..|*/./*|*/.) echo "contains . or .. segments"; return 1 ;; esac
  if [ -L "$p" ]; then echo "is a symbolic link; refusing to follow it"; return 1; fi
  if [ ! -e "$p" ]; then echo "does not exist (already gone?)"; return 1; fi
  parent=$(cd -P -- "$(dirname -- "$p")" 2>/dev/null && pwd -P) || { echo "cannot resolve its parent folder"; return 1; }
  if [ "$parent" = / ]; then real="/$(basename -- "$p")"; else real="$parent/$(basename -- "$p")"; fi
  if [ "$real" != "$p" ]; then echo "a parent folder is a symlink (really $real)"; return 1; fi
  depth=$(printf '%s' "$p" | tr -cd '/' | wc -c | tr -d ' ')
  if [ "$depth" -lt 3 ]; then echo "too close to the filesystem root"; return 1; fi
  if is_protected "$p"; then echo "protected location"; return 1; fi
  if [ -e "$p/.git" ]; then echo "is a git repository or worktree root (remove worktrees with git worktree remove)"; return 1; fi
  if top=$(git -C "$parent" rev-parse --show-toplevel 2>/dev/null) && [ -n "$top" ]; then
    if ! git -C "$parent" check-ignore -q -- "$p" 2>/dev/null; then
      echo "inside git repo $top and not git-ignored, so it may be your work"; return 1
    fi
  fi
  if [ ! -w "$parent" ]; then echo "needs elevated rights"; return 2; fi
  return 0
}

check_cmd() {
  local c=$1 w first="" force=0 worktree=0
  case "$c" in
    *'|'*|*';'*|*'&'*|*'>'*|*'<'*|*'`'*|*'$('*|*'*'*|*'
'*) echo "contains shell operators or wildcards; one plain command per item"; return 1 ;;
  esac
  set -f
  for w in $c; do
    [ -z "$first" ] && first=$w
    case "$w" in
      sudo|doas|su|rm|rmdir|unlink|shred|dd|mkfs*|diskutil|eval|exec|bash|sh|zsh|fish|python*|perl|ruby|node|osascript|find|xargs)
        set +f; echo "uses '$w', which is not allowed in a cmd item (use a path item to delete files)"; return 1 ;;
      --volumes) set +f; echo "--volumes deletes data volumes; list each volume with docker volume rm instead"; return 1 ;;
      -f|--force) force=1 ;;
      worktree) worktree=1 ;;
    esac
  done
  set +f
  if [ "$worktree" -eq 1 ] && [ "$force" -eq 1 ]; then
    echo "git worktree remove --force can discard uncommitted work; use it without --force"; return 1
  fi
  [ -n "$first" ] || { echo "empty command"; return 1; }
  return 0
}

shq() { printf '%q' "$1"; }

START_KB=$(free_kb)
n_done=0; n_skip=0; n_refused=0
MANUAL=""
REFUSED=""

echo "ai-disk-cleanup run-plan  ($([ "$DRY" -eq 1 ] && echo "dry run, nothing will change" || echo "live"))"
echo "plan: $PLAN"
echo "free space now: $(human "$START_KB")"
echo

line_no=0
while IFS= read -r line <&3 || [ -n "$line" ]; do
  line_no=$((line_no + 1))
  line=$(trim "$line")
  case "$line" in ''|'#'*) continue ;; esac

  pipes=$(printf '%s' "$line" | tr -cd '|' | wc -c | tr -d ' ')
  if [ "$pipes" -lt 4 ]; then
    echo "line $line_no: malformed (need ID | TIER | KIND | NOTE | TARGET), skipped"
    n_refused=$((n_refused + 1)); continue
  fi
  rest=$line
  id=$(trim "${rest%%|*}");   rest=${rest#*|}
  tier=$(trim "${rest%%|*}"); rest=${rest#*|}
  kind=$(trim "${rest%%|*}"); rest=${rest#*|}
  note=$(trim "${rest%%|*}"); rest=${rest#*|}
  target=$(trim "$rest")
  target=${target%/}
  [ -z "$target" ] && target=/

  case "$id" in ''|*[!0-9]*) echo "line $line_no: ID '$id' is not a number, skipped"; n_refused=$((n_refused + 1)); continue ;; esac
  if [ -n "$ONLY" ]; then case ",$ONLY," in *",$id,"*) ;; *) continue ;; esac; fi

  echo "──────────────────────────────────────────────"
  echo "#$id  tier $tier  $kind"
  echo "  $note"
  echo "  $target"

  case "$kind" in
    path|quarantine)
      reason=$(check_path "$target"); rc=$?
      if [ "$rc" -eq 1 ]; then
        echo "  REFUSED: $reason"
        REFUSED="$REFUSED#$id $target: $reason
"
        n_refused=$((n_refused + 1)); continue
      fi
      if [ "$rc" -eq 2 ]; then
        echo "  NEEDS ELEVATION: skipped. Check it, then run it yourself:"
        echo "    sudo rm -rf -- $(shq "$target")"
        MANUAL="${MANUAL}sudo rm -rf -- $(shq "$target")
"
        n_skip=$((n_skip + 1)); continue
      fi
      size_kb=$(du -sk -- "$target" 2>/dev/null | cut -f1)
      echo "  size: $(human "${size_kb:-0}")"
      if [ "$kind" = quarantine ]; then
        if [ "$(dev_of "$target")" != "$(dev_of "$H")" ]; then
          echo "  REFUSED: on a different volume than your home folder; quarantine would copy it"
          n_refused=$((n_refused + 1)); continue
        fi
      fi
      ;;
    cmd)
      reason=$(check_cmd "$target") || {
        echo "  REFUSED: $reason"
        REFUSED="$REFUSED#$id $target: $reason
"
        n_refused=$((n_refused + 1)); continue
      }
      ;;
    *)
      echo "  REFUSED: unknown kind '$kind'"
      n_refused=$((n_refused + 1)); continue ;;
  esac

  if [ "$DRY" -eq 1 ]; then
    case "$kind" in
      path) echo "  would delete" ;;
      quarantine) echo "  would move to $QDIR/" ;;
      cmd) echo "  would run: $target" ;;
    esac
    continue
  fi

  case "$kind" in
    path) prompt="Delete it?" ;;
    quarantine) prompt="Move it to quarantine?" ;;
    cmd) prompt="Run this command?" ;;
  esac
  printf '  %s [y/N/q] ' "$prompt"
  ans=""
  read -r ans || ans=""
  echo
  case "$ans" in
    y|Y|yes|YES) ;;
    q|Q) echo "  stopped."; break ;;
    *) echo "  skipped."; n_skip=$((n_skip + 1)); continue ;;
  esac

  before=$(free_kb)
  case "$kind" in
    path) rm -rf -- "$target" ;;
    quarantine) mkdir -p -- "$QDIR" && mv -- "$target" "$QDIR/$id-$(basename -- "$target")" ;;
    cmd) bash -c "$target" ;;
  esac
  rc=$?
  after=$(free_kb)
  if [ "$rc" -eq 0 ]; then
    n_done=$((n_done + 1))
    gained=$((after - before)); [ "$gained" -lt 0 ] && gained=0
    echo "  done. freed now: $(human "$gained")   free space: $(human "$after")"
  else
    echo "  FAILED (exit $rc). Stopping so you can look at it."
    n_refused=$((n_refused + 1)); break
  fi
done 3< "$PLAN"

END_KB=$(free_kb)
echo
echo "══════════════════════════════════════════════"
echo "done: $n_done   skipped: $n_skip   refused or failed: $n_refused"
echo "free space: $(human "$START_KB") → $(human "$END_KB")"
if [ -n "$REFUSED" ]; then
  echo
  echo "Refused items (nothing was done to them):"
  printf '%s' "$REFUSED" | sed 's/^/  /'
fi
if [ -n "$MANUAL" ]; then
  echo
  echo "Needs elevation. Check each one, then run it yourself if you still want it:"
  printf '%s' "$MANUAL" | sed 's/^/  /'
fi
if [ -d "$QDIR" ]; then
  echo
  echo "Quarantined items are in: $QDIR"
  echo "They still use disk space. When you are sure, free it with:"
  echo "  rm -rf -- $(shq "$QDIR")"
fi
