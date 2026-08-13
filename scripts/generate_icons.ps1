# release-kit: generate platform launcher icons from a single source image (Windows)
#
# Reads `app.logo` from the resolved config (release-kit.yaml > config.yaml
# > kit default). If unset or the file is missing, warns and continues
# (icons are optional). Otherwise drives flutter_launcher_icons to
# regenerate icons for the target platform only (or all, if none given).
#
# Usage: .\generate_icons.ps1 [-Platform windows|android|ios|macos|linux|all]

param(
  [string]$Platform = ""
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$OutputEncoding = [System.Text.UTF8Encoding]::new($false)

Add-Type -AssemblyName System.Drawing

# Rebuild an .ico with multiple size frames (16..256) from a source PNG, so
# Windows uses a dedicated frame for taskbar/explorer/titlebar small icons
# instead of scaling down a single 256px frame.
function Expand-Icon {
  param(
    [string]$IcoPath,
    [string]$SourcePng
  )
  if (-not (Test-Path $SourcePng)) { return }
  try {
    $src = [System.Drawing.Image]::FromFile($SourcePng)
    $sizes = @(256, 128, 64, 48, 32, 24, 16)
    $frames = @()
    foreach ($s in $sizes) {
      $bmp = New-Object System.Drawing.Bitmap($s, $s)
      $g = [System.Drawing.Graphics]::FromImage($bmp)
      $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
      $g.DrawImage($src, 0, 0, $s, $s)
      $g.Dispose()
      $ms = New-Object System.IO.MemoryStream
      $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
      $frames += ,@($bmp, $ms.ToArray())
      $bmp.Dispose()
      $ms.Dispose()
    }
    $src.Dispose()

    $fs = [System.IO.File]::Create($IcoPath)
    $bw = New-Object System.IO.BinaryWriter($fs)
    $bw.Write([uint16]0); $bw.Write([uint16]1); $bw.Write([uint16]$sizes.Count)
    $dataStart = 6 + 16 * $sizes.Count
    $cur = $dataStart
    $entryData = @()
    for ($i = 0; $i -lt $sizes.Count; $i++) {
      $s = $sizes[$i]; $bytes = $frames[$i][1]
      $dim = if ($s -ge 256) { 0 } else { $s }
      $bw.Write([byte]$dim); $bw.Write([byte]$dim); $bw.Write([byte]0); $bw.Write([byte]0)
      $bw.Write([uint16]1); $bw.Write([uint16]32)
      $bw.Write([uint32]$bytes.Length); $bw.Write([uint32]$cur)
      $entryData += ,@($cur, $bytes)
      $cur += $bytes.Length
    }
    foreach ($e in $entryData) { $bw.Write($e[1]) }
    $bw.Close(); $fs.Close()
    Write-Host "==> expanded $IcoPath to $($sizes.Count) frames (16..256)"
  } catch {
    Write-Host "==> could not expand icon: $($_.Exception.Message)" -ForegroundColor Yellow
  }
}
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

  # normalize target platform ("" -> all)
  $p = if ($Platform) { $Platform.ToLower() } else { "all" }
  if ($p -eq "linux") {
    Write-Host "==> flutter_launcher_icons has no Linux icon targets - skipping"
    exit 0
  }

  # platform representative icon path(s) used to decide freshness
  $targetIcons = @()
  if ($p -eq "all" -or $p -eq "windows") { $targetIcons += Join-Path $proj "windows\runner\resources\app_icon.ico" }
  if ($p -eq "all" -or $p -eq "android") { $targetIcons += (Get-ChildItem (Join-Path $proj "android\app\src\main\res\mipmap-xxxhdpi\ic_launcher.png") -ErrorAction SilentlyContinue | Select-Object -First 1).FullName }
  if ($p -eq "all" -or $p -eq "ios")     { $targetIcons += Join-Path $proj "ios\Runner\Assets.xcassets\AppIcon.appiconset\Contents.json" }
  if ($p -eq "all" -or $p -eq "macos")   { $targetIcons += Join-Path $proj "macos\Runner\Assets.xcassets\AppIcon.appiconset\Contents.json" }
  $targetIcons = @($targetIcons | Where-Object { $_ })

  # skip if icons are already newer than the source logo (nothing changed)
  $logoTime = (Get-Item $logo).LastWriteTime
  $needGen = $false
  foreach ($ti in $targetIcons) {
    if (-not (Test-Path $ti)) { $needGen = $true; break }
    if ((Get-Item $ti).LastWriteTime -lt $logoTime) { $needGen = $true; break }
  }
  if (-not $needGen) {
    Write-Host "==> icons already up to date (newer than $logo) - skipping"
    exit 0
  }

  # if the target windows icon is locked (e.g. the app is running via
  # flutter run, or an editor has it mapped), skip icon regeneration with a
  # clear hint instead of letting flutter_launcher_icons throw a cryptic
  # FileSystemException
  $icoPath = Join-Path $proj "windows\runner\resources\app_icon.ico"
  if (($p -eq "all" -or $p -eq "windows") -and (Test-Path $icoPath)) {
    $icoLocked = $false
    try {
      $fs = [System.IO.File]::Open($icoPath, 'Open', 'ReadWrite', 'None')
      $fs.Close()
    } catch {
      $icoLocked = $true
    }
    if ($icoLocked) {
      Write-Host ""
      Write-Host "==> app_icon.ico is locked by another process." -ForegroundColor Yellow
      Write-Host "    Is the app running via 'flutter run -d windows'?" -ForegroundColor Yellow
      Write-Host "    Stop it (e.g. press 'q' in the flutter run console), then re-run." -ForegroundColor Yellow
      Write-Host "    Skipping icon regeneration for now." -ForegroundColor Yellow
      Write-Host ""
      exit 0
    }
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
  $sb = New-Object System.Text.StringBuilder
  [void]$sb.Append("$topKey`:`n")
  # android / ios are enabled with true/false; windows / macos need a block
  if ($p -eq "all" -or $p -eq "android") {
    [void]$sb.Append("  android: true`n")
  } else {
    [void]$sb.Append("  android: false`n")
  }
  if ($p -eq "all" -or $p -eq "ios") {
    [void]$sb.Append("  ios: true`n")
  } else {
    [void]$sb.Append("  ios: false`n")
  }
  [void]$sb.Append("  image_path: `"$logo`"`n")
  if ($p -eq "all" -or $p -eq "windows") {
    [void]$sb.Append("  windows:`n    generate: true`n    image_path: `"$logo`"`n    icon_size: 256`n")
  }
  if ($p -eq "all" -or $p -eq "macos") {
    [void]$sb.Append("  macos:`n    generate: true`n    image_path: `"$logo`"`n")
  }
  $cfgText = $sb.ToString()
  [System.IO.File]::WriteAllText((Join-Path $proj $flic), $cfgText, (New-Object System.Text.UTF8Encoding($false)))
  Write-Host "==> target platform: $p"

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

  # flutter_launcher_icons writes a single-frame .ico; expand it to a
  # multi-size ico (16..256) so small icons stay crisp on Windows
  if ($p -eq "all" -or $p -eq "windows") {
    $icoPath = Join-Path $proj "windows\runner\resources\app_icon.ico"
    if (Test-Path $icoPath) {
      Expand-Icon -IcoPath $icoPath -SourcePng (Join-Path $proj $logo)
    }
  }
  Write-Host "==> icons regenerated"
} finally {
  Pop-Location
}
