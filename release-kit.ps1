# release-kit: unified CLI entry (Windows)
# Usage:
#   .\release-kit.ps1 init [-p <project-root>]                       # copy config template + install hook
#   .\release-kit.ps1 publish <platform> [args] [-p <project-root>]  # windows|android|macos|linux|ios
#
# All commands run against the current directory. Pass -p <project-root>
# (anywhere in the args) to target another project from any directory.

param(
  [Parameter(Position = 0)][string]$Command = "",
  [Alias("project")][string]$p = "",
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

if (-not $Command) { Show-Usage }
$ProjectArg = $p
$argsList = @($RemainingArgs)

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
      $skipIcons = $false
      if ($argsList.Count -gt 1) {
        for ($i = 1; $i -lt $argsList.Count; $i++) {
          if ($argsList[$i] -eq "--no-icons") { $skipIcons = $true } else { $rest += $argsList[$i] }
        }
      }
      if (-not $skipIcons) { & (Join-Path $kitRoot "scripts\generate_icons.ps1") }
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
