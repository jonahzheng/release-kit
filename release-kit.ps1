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

# decode native-command output (flutter/dart) as UTF-8 so box-drawing and
# emoji progress characters don't get mangled by the legacy console codepage
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$OutputEncoding = [System.Text.UTF8Encoding]::new($false)

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

# Run a shell script via bash (Windows has no native .sh execution).
function Invoke-Sh {
  param(
    [string]$Script,
    [string[]]$ArgList
  )
  $bash = $null
  foreach ($cand in @("C:\Program Files\Git\bin\bash.exe", "C:\Program Files\Git\usr\bin\bash.exe", "bash")) {
    if (Get-Command $cand -ErrorAction SilentlyContinue) { $bash = $cand; break }
  }
  if (-not $bash) { throw "bash not found (needed for shell scripts). Install Git for Windows." }
  # quote each arg so bash receives them verbatim (paths with spaces etc.)
  $parts = @()
  foreach ($a in $ArgList) { $parts += "'" + ($a -replace "\\", "/" -replace "'", "'\''") + "'" }
  $scriptPath = $Script -replace "\\", "/"
  $cmd = "'$scriptPath'" + $(if ($parts.Count) { " " + ($parts -join " ") } else { "" })
  & $bash -c $cmd
  return $LASTEXITCODE
}

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
      if (-not $skipIcons) { & (Join-Path $kitRoot "scripts\generate_icons.ps1") -Platform $platform }
      switch ($platform) {
        "windows" {
          # publish_windows.ps1 takes switch params; pass them explicitly so a
          # string-array splat can't mis-bind "-Obfuscate" onto $OutputDir
          $obf = $false; $skp = $false; $nor = $false; $hrd = $false; $cln = $false; $srv = $false; $outDir = ""
          for ($i = 0; $i -lt $rest.Count; $i++) {
            switch ($rest[$i]) {
              "-Obfuscate"   { $obf = $true }
              "-SkipBuild"   { $skp = $true }
              "-NoRename"    { $nor = $true }
              "-Harden"      { $hrd = $true }
              "-CleanFlutter"{ $cln = $true }
              "-SkipVerify"  { $srv = $true }
              "-OutputDir"   { if ($i + 1 -lt $rest.Count) { $outDir = $rest[$i + 1]; $i++ } }
            }
          }
          & (Join-Path $kitRoot "scripts\publish_windows.ps1") -Obfuscate:$obf -SkipBuild:$skp -NoRename:$nor -Harden:$hrd -CleanFlutter:$cln -SkipVerify:$srv -OutputDir $outDir
        }
        "android" {
          # map the common -Obfuscate spelling to the android --obfuscate flag
          $androidArgs = @()
          foreach ($a in $rest) { if ($a -eq "-Obfuscate") { $androidArgs += "--obfuscate" } else { $androidArgs += $a } }
          Invoke-Sh -Script (Join-Path $kitRoot "scripts\publish_android.sh") -ArgList $androidArgs
        }
        "macos"   { Invoke-Sh -Script (Join-Path $kitRoot "scripts\publish_macos.sh") -ArgList $rest }
        "linux"   { Invoke-Sh -Script (Join-Path $kitRoot "scripts\publish_linux.sh") -ArgList $rest }
        "ios"     { Invoke-Sh -Script (Join-Path $kitRoot "scripts\publish_ios.sh") -ArgList $rest }
        default   { Write-Host "unknown platform: $platform" -ForegroundColor Red; Show-Usage }
      }
      break
    }
    default { Show-Usage }
  }
} finally {
  if ($ProjectArg) { Pop-Location }
}
