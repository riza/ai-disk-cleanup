#Requires -Version 7.0
<#
run-plan.ps1 — carry out an ai-disk-cleanup plan on Windows, one confirmed item at a time.

    pwsh -File run-plan.ps1 [-DryRun] [-Only 1,4,7] cleanup-plan.txt

Every item is checked before anything happens and you answer y/N for each one.
Nothing is deleted on an empty answer or on any refusal. Run it from a normal,
non-elevated PowerShell 7 window.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)] [string] $Plan,
    [switch] $DryRun,
    [int[]] $Only
)

Set-StrictMode -Version 3
$ErrorActionPreference = 'Stop'

if (-not $IsWindows) { Write-Host 'run-plan.ps1 is for Windows. On macOS and Linux use run-plan.sh.'; exit 64 }
if (-not (Test-Path -LiteralPath $Plan -PathType Leaf)) { Write-Host "run-plan: no such plan file: $Plan"; exit 66 }

$principal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if ($principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host 'run-plan: refusing to run elevated. Use a normal PowerShell window;'
    Write-Host 'items that need elevation are printed at the end for you to run by hand.'
    exit 77
}

$H = (Get-Item -LiteralPath ([Environment]::GetFolderPath('UserProfile'))).FullName.TrimEnd('\')
$Drive = $H.Substring(0, 1)
$QDir = Join-Path $H ('.ai-disk-cleanup-quarantine\' + (Get-Date -Format 'yyyyMMdd-HHmmss'))

function Get-FreeBytes { (Get-PSDrive -Name $Drive).Free }
function Format-Size([double] $b) {
    $u = 'B', 'KB', 'MB', 'GB', 'TB'; $i = 0
    while ($b -ge 1024 -and $i -lt 4) { $b /= 1024; $i++ }
    '{0:N1} {1}' -f $b, $u[$i]
}

function Test-Protected([string] $p) {
    $exact = @(
        "$env:SystemDrive\Users", $env:ProgramData, $H,
        "$H\Documents", "$H\Desktop", "$H\Downloads", "$H\Pictures", "$H\Music", "$H\Videos",
        "$H\AppData", "$H\AppData\Local", "$H\AppData\Roaming", "$H\AppData\LocalLow",
        "$H\Favorites", "$H\Contacts", "$H\Links", "$H\Saved Games", "$H\Searches",
        "$H\.ai-disk-cleanup-quarantine"
    )
    foreach ($e in $exact) { if ($e -and $p -ieq $e) { return $true } }
    $trees = @(
        $env:SystemRoot, $env:ProgramFiles, ${env:ProgramFiles(x86)},
        "$env:SystemDrive\`$Recycle.Bin", "$env:SystemDrive\System Volume Information",
        "$H\.ssh", "$H\.gnupg", "$H\.aws", "$H\.kube", "$H\iCloudDrive", "$H\Dropbox", "$H\Google Drive",
        "$H\AppData\Roaming\Microsoft\Credentials", "$H\AppData\Local\Microsoft\Credentials",
        "$H\AppData\Roaming\Microsoft\Protect", "$H\AppData\Roaming\Microsoft\Crypto"
    )
    if ($env:OneDrive) { $trees += $env:OneDrive }
    foreach ($t in $trees) {
        if (-not $t) { continue }
        $t = $t.TrimEnd('\')
        if ($p -ieq $t -or $p.StartsWith("$t\", [StringComparison]::OrdinalIgnoreCase)) { return $true }
    }
    if ($p.StartsWith("$H\OneDrive", [StringComparison]::OrdinalIgnoreCase)) { return $true }
    return $false
}

# Returns @(code, reason): code 0 = fine, 1 = refused.
function Test-PlanPath([string] $p) {
    $ErrorActionPreference = 'Continue'  # git writes to stderr; do not turn that into an exception
    if ($p -notmatch '^[A-Za-z]:\\') { return 1, 'not an absolute path with a drive letter (network and \\?\ paths are refused)' }
    if ($p -match '[*?\[\]/]') { return 1, 'contains wildcards or forward slashes; give the literal path' }
    if ($p -match '(^|\\)\.{1,2}(\\|$)') { return 1, 'contains . or .. segments' }
    if (-not (Test-Path -LiteralPath $p)) { return 1, 'does not exist (already gone?)' }
    $item = Get-Item -LiteralPath $p -Force
    if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { return 1, 'is a link, junction or cloud placeholder; refusing to follow it' }
    $parent = Split-Path -LiteralPath $p -Parent
    while ($parent) {
        $pi = Get-Item -LiteralPath $parent -Force -ErrorAction SilentlyContinue
        if (-not $pi) { return 1, "cannot inspect parent folder $parent" }
        if ($pi.Attributes -band [IO.FileAttributes]::ReparsePoint) { return 1, "a parent folder is a link or junction ($parent)" }
        $next = Split-Path -LiteralPath $parent -Parent
        if ($next -eq $parent) { break }
        $parent = $next
    }
    if (($p.Split('\').Count - 1) -lt 3) { return 1, 'too close to the drive root' }
    if (Test-Protected $p) { return 1, 'protected location' }
    if (Test-Path -LiteralPath (Join-Path $p '.git')) { return 1, 'is a git repository or worktree root (remove worktrees with git worktree remove)' }
    $dir = Split-Path -LiteralPath $p -Parent
    if (Get-Command git -ErrorAction SilentlyContinue) {
        $top = & git -C $dir rev-parse --show-toplevel 2>$null
        if ($LASTEXITCODE -eq 0 -and $top) {
            & git -C $dir check-ignore -q -- $p 2>$null
            if ($LASTEXITCODE -ne 0) { return 1, "inside git repo $top and not git-ignored, so it may be your work" }
        }
    } else {
        $d = $dir
        while ($d) {
            if (Test-Path -LiteralPath (Join-Path $d '.git')) { return 1, 'inside a git repo and git is not installed to check it' }
            $n = Split-Path -LiteralPath $d -Parent; if ($n -eq $d) { break }; $d = $n
        }
    }
    if ($item.PSIsContainer) {
        $link = Get-ChildItem -LiteralPath $p -Recurse -Force -Attributes ReparsePoint -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($link) { return 1, "contains a link or junction ($($link.FullName)); check it and delete it by hand" }
    }
    return 0, ''
}

function Test-PlanCmd([string] $c) {
    if ($c -match '[|;&<>`*\r\n]' -or $c.Contains('$(')) { return 1, 'contains shell operators or wildcards; one plain command per item' }
    $banned = 'remove-item', 'rm', 'del', 'erase', 'rd', 'rmdir', 'ri', 'clear-content', 'set-content', 'out-file',
              'format-volume', 'format', 'diskpart', 'cipher', 'vssadmin', 'wmic', 'invoke-expression', 'iex',
              'start-process', 'cmd', 'cmd.exe', 'powershell', 'pwsh', 'bash', 'wsl', 'node', 'sudo', 'runas',
              'takeown', 'icacls', 'sdelete', 'python', 'python3', 'py'
    $words = $c -split '\s+' | Where-Object { $_ }
    if (-not $words) { return 1, 'empty command' }
    foreach ($w in $words) {
        if ($banned -contains $w.ToLowerInvariant()) { return 1, "uses '$w', which is not allowed in a cmd item (use a path item to delete files)" }
    }
    if ($words -contains '--volumes') { return 1, '--volumes deletes data volumes; list each volume with docker volume rm instead' }
    if (($words -contains 'worktree') -and (($words -contains '--force') -or ($words -contains '-f'))) {
        return 1, 'git worktree remove --force can discard uncommitted work; use it without --force'
    }
    return 0, ''
}

$start = Get-FreeBytes
$done = 0; $skipped = 0; $refused = 0
$manual = [Collections.Generic.List[string]]::new()
$refusedList = [Collections.Generic.List[string]]::new()

Write-Host ("ai-disk-cleanup run-plan  ({0})" -f $(if ($DryRun) { 'dry run, nothing will change' } else { 'live' }))
Write-Host "plan: $Plan"
Write-Host "free space now: $(Format-Size $start)"
Write-Host ''

$lineNo = 0
foreach ($raw in Get-Content -LiteralPath $Plan) {
    $lineNo++
    $line = $raw.Trim()
    if (-not $line -or $line.StartsWith('#')) { continue }
    $parts = $line -split '\|', 5
    if ($parts.Count -lt 5) { Write-Host "line ${lineNo}: malformed (need ID | TIER | KIND | NOTE | TARGET), skipped"; $refused++; continue }
    $id = $parts[0].Trim(); $tier = $parts[1].Trim(); $kind = $parts[2].Trim(); $note = $parts[3].Trim()
    $target = $parts[4].Trim()
    if ($kind -ne 'cmd') { $target = $target.TrimEnd('\') }
    if ($id -notmatch '^\d+$') { Write-Host "line ${lineNo}: ID '$id' is not a number, skipped"; $refused++; continue }
    if ($Only -and ($Only -notcontains [int]$id)) { continue }

    Write-Host '──────────────────────────────────────────────'
    Write-Host "#$id  tier $tier  $kind"
    Write-Host "  $note"
    Write-Host "  $target"

    # Checks. No switch here: in PowerShell, continue inside switch does not move the loop on.
    if ($kind -eq 'path' -or $kind -eq 'quarantine') {
        $code, $reason = Test-PlanPath $target
        if ($code -ne 0) { Write-Host "  REFUSED: $reason"; $refusedList.Add("#$id ${target}: $reason"); $refused++; continue }
        $item = Get-Item -LiteralPath $target -Force
        if ($item.PSIsContainer) {
            $size = (Get-ChildItem -LiteralPath $target -Recurse -Force -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
        } else { $size = $item.Length }
        Write-Host "  size: $(Format-Size ([double]$size))"
        if ($kind -eq 'quarantine' -and $target.Substring(0, 1) -ine $Drive) {
            Write-Host '  REFUSED: on a different drive than your user folder; quarantine would copy it'; $refused++; continue
        }
    } elseif ($kind -eq 'cmd') {
        $code, $reason = Test-PlanCmd $target
        if ($code -ne 0) { Write-Host "  REFUSED: $reason"; $refusedList.Add("#$id ${target}: $reason"); $refused++; continue }
    } else {
        Write-Host "  REFUSED: unknown kind '$kind'"; $refused++; continue
    }

    if ($DryRun) {
        if ($kind -eq 'path') { Write-Host '  would delete' }
        elseif ($kind -eq 'quarantine') { Write-Host "  would move to $QDir\" }
        else { Write-Host "  would run: $target" }
        continue
    }

    $question = @{ path = 'Delete it?'; quarantine = 'Move it to quarantine?'; cmd = 'Run this command?' }[$kind]
    $ans = ''
    try { $ans = Read-Host "  $question [y/N/q]" } catch { $ans = '' }
    if ($ans -match '^(q|Q)$') { Write-Host '  stopped.'; break }
    if ($ans -notmatch '^(y|Y|yes|YES)$') { Write-Host '  skipped.'; $skipped++; continue }

    $before = Get-FreeBytes
    try {
        if ($kind -eq 'path') {
            Remove-Item -LiteralPath $target -Recurse -Force
        } elseif ($kind -eq 'quarantine') {
            New-Item -ItemType Directory -Path $QDir -Force | Out-Null
            Move-Item -LiteralPath $target -Destination (Join-Path $QDir ("$id-" + (Split-Path -LiteralPath $target -Leaf)))
        } else {
            $global:LASTEXITCODE = 0
            & ([ScriptBlock]::Create($target))
            if ($LASTEXITCODE -ne 0) { throw "exit code $LASTEXITCODE" }
        }
    } catch {
        Write-Host "  FAILED: $($_.Exception.Message)"
        if ($_.Exception -is [UnauthorizedAccessException] -or "$($_.Exception.Message)" -match 'denied|elevat|administrator') {
            Write-Host '  It probably needs elevation. Check it, then run it yourself in an elevated window.'
            $manual.Add($(if ($kind -eq 'cmd') { $target } else { "Remove-Item -LiteralPath '$($target -replace "'", "''")' -Recurse -Force" }))
        }
        Write-Host '  Stopping so you can look at it.'
        $refused++
        break
    }
    $after = Get-FreeBytes
    $done++
    Write-Host "  done. freed now: $(Format-Size ([math]::Max(0, $after - $before)))   free space: $(Format-Size $after)"
}

$end = Get-FreeBytes
Write-Host ''
Write-Host '══════════════════════════════════════════════'
Write-Host "done: $done   skipped: $skipped   refused or failed: $refused"
Write-Host "free space: $(Format-Size $start) -> $(Format-Size $end)"
if ($refusedList.Count) { Write-Host ''; Write-Host 'Refused items (nothing was done to them):'; $refusedList | ForEach-Object { Write-Host "  $_" } }
if ($manual.Count) { Write-Host ''; Write-Host 'Needs elevation. Check each one, then run it yourself if you still want it:'; $manual | ForEach-Object { Write-Host "  $_" } }
if (Test-Path -LiteralPath $QDir) {
    Write-Host ''
    Write-Host "Quarantined items are in: $QDir"
    Write-Host 'They still use disk space. When you are sure, free it with:'
    Write-Host "  Remove-Item -LiteralPath '$($QDir -replace "'", "''")' -Recurse -Force"
}
