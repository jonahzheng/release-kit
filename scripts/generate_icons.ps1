# release-kit: generate platform launcher icons from a single source image (Windows)
#
# Reads `app.logo` from the resolved config (release-kit.yaml > config.yaml
# > kit default). If unset or the file is missing, warns and continues
# (icons are optional). Otherwise drives flutter_launcher_icons to
# regenerate Android / iOS / macOS / Windows icons.
#
# Usage: .\generate_icons.ps1  (run from the project root)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$kitRoot = Split-Path -Parent $PSScriptRoot

# --- locate project root (cwd with pubspec, or app/ subdir) ---
$proj = (Get-Location).Path
if (-not (Test-Path (Join-Path $proj "pubspec.yaml"))) {
  if (Test-Path (Join-Path $proj "app\pubspec.yaml")) { $proj = Join-Path $proj "app" }
}
if (-not (Test-Path (Join-Path $proj "pubspec.yaml"))) {
  throw "No pubspec.yaml found (run from project root or app/ subdir)"
}

# --- resolve config: project-local release-kit.yaml > config.yaml > kit default ---
$configPath = $null
foreach ($dir in @($proj, (Split-Path -Parent $proj), $kitRoot)) {
  if (Test-Path (Join-Path $dir "release-kit.yaml")) { $configPath = Join-Path $dir "release-kit.yaml"; break }
  if (Test-Path (Join-Path $dir "config.yaml")) { $configPath = Join-Path $dir "config.yaml"; break }
}
if (-not $configPath) { throw "No config found (release-kit.yaml or config.yaml)" }

function Get-Cfg($key) {
  foreach ($line in Get-Content $configPath) {
    $t = $line.Trim()
    if ($t -eq "" -or $t.StartsWith("#")) { continue }
    if ($t.StartsWith("${key}:")) {
      $v = $t.Substring($key.Length + 1).Trim()
      $idx = $v.IndexOf(" #")
      if ($idx -ge 0) { $v = $v.Substring(0, $idx).Trim() }
      return $v
    }
  }
  return ""
}

$logo = Get-Cfg "app.logo"
if (-not $logo) {
  Write-Host "==> app.logo not set in config - skipping icon generation"
  exit 0
}

Push-Location $proj
try {
  if (-not (Test-Path $logo)) {
    throw "app.logo not found: $logo (fix the path in your config, or remove app.logo to skip icons)"
  }

  if (-not (Select-String -Path "pubspec.yaml" -Pattern "flutter_launcher_icons" -Quiet)) {
    Write-Host "==> adding flutter_launcher_icons dev dependency..."
    flutter pub add --dev flutter_launcher_icons
    if ($LASTEXITCODE -ne 0) { throw "flutter pub add failed" }
  }

  # prefer the dart.exe inside the resolved flutter SDK (avoids a stray
  # standalone dart-sdk shadowing it on PATH, and avoids dart.bat mangling
  # UTF-8 output in the PowerShell pipeline)
  function Get-DartCmd {
    $f = Get-Command flutter -ErrorAction SilentlyContinue
    if ($f -and $f.Source) {
      $dir = Split-Path -Parent $f.Source
      $cached = Join-Path $dir "cache\dart-sdk\bin\dart.exe"
      if (Test-Path $cached) { return $cached }
      foreach ($cand in @("$dir\dart.bat", "$dir\dart.exe")) {
        if (Test-Path $cand) { return $cand }
      }
    }
    return "dart"
  }
  $dartCmd = Get-DartCmd
  Write-Host "==> dart: $dartCmd"

  # top-level key differs by package version: 0.11 uses "flutter_icons",
  # 0.14+ uses "flutter_launcher_icons". Detect from pubspec.lock.
  $ver = ""
  if (Test-Path "pubspec.lock") {
    $lock = Get-Content "pubspec.lock" -Raw
    $m = [regex]::Match($lock, "flutter_launcher_icons:\r?\n(?:.*\r?\n)*?.*?version: .([0-9.]+).")
    if ($m.Success) { $ver = $m.Groups[1].Value }
  }
  $topKey = "flutter_launcher_icons"
  if ($ver -and [version]$ver -lt [version]"0.12.0") { $topKey = "flutter_icons" }
  Write-Host "==> flutter_launcher_icons $ver (config key: $topKey)"

  $flic = "flutter_launcher_icons.yaml"
  $cfgText = "$topKey`:`n" + @"
  android: true
  ios: true
  image_path: "$logo"
  windows:
    generate: true
    image_path: "$logo"
    icon_size: 256
  macos:
    generate: true
    image_path: "$logo"
"@
  [System.IO.File]::WriteAllText((Join-Path $proj $flic), $cfgText, (New-Object System.Text.UTF8Encoding($false)))

  Write-Host "==> generating icons from $logo ..."
  # redirect stderr so flutter_launcher_icons' "skipped" warnings don't
  # trip $ErrorActionPreference=Stop; judge success by exit code only
  $prevEAP = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  try {
    & $dartCmd run flutter_launcher_icons -f $flic 2>&1 | ForEach-Object { Write-Host $_ }
  } finally {
    $ErrorActionPreference = $prevEAP
  }
  if ($LASTEXITCODE -ne 0) { throw "icon generation failed (exit $LASTEXITCODE)" }
  Remove-Item $flic -Force
  Write-Host "==> icons regenerated"
} finally {
  Pop-Location
}
