# release-kit: unified CLI entry (Windows)
# Usage:
#   .\release-kit.ps1 init [-p <project-root>]                       # copy config template + install hook
#   .\release-kit.ps1 publish <platform> [args] [-p <project-root>]  # windows|android|macos|linux|ios
#
# All commands run against the current directory. Pass -p <project-root>
# (anywhere in the args) to target another project from any directory.

param(
  [Parameter(Position = 0)][string]$Command = "",
  [Parameter(ValueFromRemainingArguments = $true)]$RemainingArgs
)

$ErrorActionPreference = "Stop"
$kitRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

function Show-Usage {
  @"
release-kit <command>

  init                        copy config template (release-kit.yaml) + install hook
  publish <platform> [args]   build & package (windows|android|macos|linux|ios)

  -p <project-root>           optional, any command: target another project from anywhere
"@ | Write-Host
  exit 1
}

function Extract-Project {
  param([string[]]$ArgsList)
  $script:ProjectArg = ""
  $rest = @()
  for ($i = 0; $i -lt $ArgsList.Count; $i++) {
    if (($ArgsList[$i] -eq "-p" -or $ArgsList[$i] -eq "--project") -and $i + 1 -lt $ArgsList.Count) {
      $script:ProjectArg = $ArgsList[$i + 1]; $i++
    } else {
      $rest += $ArgsList[$i]
    }
  }
  return $rest
}

if (-not $Command) { Show-Usage }
$argsList = @($RemainingArgs)
$argsList = @(Extract-Project -ArgsList $argsList)

if ($ProjectArg) {
  if (-not (Test-Path $ProjectArg)) { throw "Project root not found: $ProjectArg" }
  Push-Location $ProjectArg
}
try {
  switch ($Command) {
    "init" {
      $cfg = Join-Path (Get-Location) "release-kit.yaml"
      if (-not (Test-Path $cfg)) {
        Copy-Item (Join-Path $kitRoot "config.yaml") $cfg
        Write-Host "==> created $cfg (edit it to match your app)"
      } else {
        Write-Host "==> $cfg already exists, keeping it"
      }
      & (Join-Path $kitRoot "scripts\install_hook.ps1")
      break
    }
    "publish" {
      if ($argsList.Count -lt 1) { Show-Usage }
      $platform = $argsList[0]
      $rest = @()
      if ($argsList.Count -gt 1) { $rest = $argsList[1..($argsList.Count - 1)] }
      switch ($platform) {
        "windows" { & (Join-Path $kitRoot "scripts\publish_windows.ps1") @rest }
        "android" { & (Join-Path $kitRoot "scripts\publish_android.sh") @rest }
        "macos"   { & (Join-Path $kitRoot "scripts\publish_macos.sh") @rest }
        "linux"   { & (Join-Path $kitRoot "scripts\publish_linux.sh") @rest }
        "ios"     { & (Join-Path $kitRoot "scripts\publish_ios.sh") @rest }
        default   { Write-Host "unknown platform: $platform" -ForegroundColor Red; Show-Usage }
      }
      break
    }
    default { Show-Usage }
  }
} finally {
  if ($ProjectArg) { Pop-Location }
}
