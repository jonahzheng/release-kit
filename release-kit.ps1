# release-kit: unified CLI entry (Windows)
# Usage:
#   .\release-kit.ps1 init                      # copy config template + install hook
#   .\release-kit.ps1 install                   # install hook only
#   .\release-kit.ps1 publish <platform> [args] # windows|android|macos|linux|ios
#   .\release-kit.ps1 bump [--build-only]       # manually bump version
#
# All commands run against the current directory. To target another project
# from anywhere, pass -p <project-root> to publish.

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
                              optional: -p <project-root> to target another project
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
    $project = ""
    $rest = @()
    for ($i = 1; $i -lt $argsList.Count; $i++) {
      if ($argsList[$i] -eq "-p" -and $i + 1 -lt $argsList.Count) {
        $project = $argsList[$i + 1]; $i++
      } else {
        $rest += $argsList[$i]
      }
    }
    if ($project) {
      if (-not (Test-Path $project)) { throw "Project root not found: $project" }
      Push-Location $project
    }
    try {
      switch ($platform) {
        "windows" { & (Join-Path $kitRoot "scripts\publish_windows.ps1") @rest }
        "android" { & (Join-Path $kitRoot "scripts\publish_android.sh") @rest }
        "macos"   { & (Join-Path $kitRoot "scripts\publish_macos.sh") @rest }
        "linux"   { & (Join-Path $kitRoot "scripts\publish_linux.sh") @rest }
        "ios"     { & (Join-Path $kitRoot "scripts\publish_ios.sh") @rest }
        default   { Write-Host "unknown platform: $platform" -ForegroundColor Red; Show-Usage }
      }
    } finally {
      if ($project) { Pop-Location }
    }
    break
  }
  "bump" {
    & dart run (Join-Path $kitRoot "bin\bump_version.dart") @argsList
    break
  }
  default { Show-Usage }
}
