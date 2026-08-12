# release-kit: generate platform launcher icons from a single source image (Windows)
#
# Reads `app.logo` from the resolved config (release-kit.yaml > config.yaml
# > kit default). If unset or the file is missing, warns and continues
# (icons are optional). Otherwise drives flutter_launcher_icons to
# regenerate Android / iOS / macOS / Windows icons.
#
# Usage: .\generate_icons.ps1  (run from the project root)

$ErrorActionPreference = "Stop"
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
      return ($t.Substring($key.Length + 1).Trim())
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

  $flic = "flutter_launcher_icons.yaml"
  @"
flutter_launcher_icons:
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
"@ | Set-Content -Path $flic -Encoding UTF8

  Write-Host "==> generating icons from $logo ..."
  dart run flutter_launcher_icons:generate -f $flic
  if ($LASTEXITCODE -ne 0) { throw "icon generation failed" }
  Remove-Item $flic -Force
  Write-Host "==> icons regenerated"
} finally {
  Pop-Location
}
