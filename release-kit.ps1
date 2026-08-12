# release-kit: unified CLI entry (Windows)
# Usage:
#   .\release-kit.ps1 init                      # copy config template + install hook
#   .\release-kit.ps1 install                   # install hook only
#   .\release-kit.ps1 publish <platform> [args] # windows|android|macos|linux|ios
#   .\release-kit.ps1 bump [--build-only]       # manually bump version
#
# Run from the Flutter project root (or app/ subdir in a monorepo).

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
  install                     install version-bump pre-commit hook
  publish <platform> [args]   build & package (windows|android|macos|linux|ios)
  bump [--build-only]         manually bump pubspec version
"@ | Write-Host
  exit 1
}

if (-not $Command) { Show-Usage }
$argsList = @($RemainingArgs)

switch ($Command) {
  "init" {
    $cfg = Join-Path (Get-Location) "release-kit.yaml"
    if (-not (Test-Path $cfg)) {
      Copy-Item (Join-Path $kitRoot "config.yaml") $cfg
      Write-Host "==> created $cfg (edit it to match your app)"
    } else {
      Write-Host "==> $cfg already exists, keeping it"
    }
    & (Join-Path $kitRoot "scripts\install_hook.ps1") @argsList
    break
  }
  "install" {
    & (Join-Path $kitRoot "scripts\install_hook.ps1") @argsList
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
  "bump" {
    & dart run (Join-Path $kitRoot "bin\bump_version.dart") @argsList
    break
  }
  default { Show-Usage }
}
