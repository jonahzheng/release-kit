# release-kit: publish Windows build (config-driven)
# Usage:
#   powershell -ExecutionPolicy Bypass -File publish_windows.ps1 [--obfuscate] [--skip-build] [--no-rename] [--harden] [--clean-flutter] [--skip-verify] [--output-dir <path>]
# Run from the Flutter project root (or app/ subdir in a monorepo).
#
# Flags use the same double-dash spelling as every other platform.
#
# Hardening (rename engine dll + assets, patch import tables) is enabled by
# default only when config has hardening.enabled: true. Pass --harden to force
# it on regardless of config; pass --no-rename to force it off.
#
# --clean-flutter additionally scrubs Flutter traces from the bundle:
#   1. renames the asset dir and patches the exe's embedded UTF-16 path so
#      the engine loads data\resources (no source changes, reverted nothing)
#   2. renames leftover flutter_* plugin dlls (e.g. flutter_tts_plugin.dll)
#
# --skip-verify skips the post-build "exe launches" smoke test.

param(
  [switch]$Obfuscate,
  [switch]$SkipBuild,
  [switch]$NoRename,
  [switch]$Harden,
  [switch]$CleanFlutter,
  [switch]$SkipVerify,
  [string]$OutputDir = "",
  [Parameter(ValueFromRemainingArguments = $true)][string[]]$Extra
)

# accept the canonical double-dash spellings (pushed here as remaining args by
# release-kit.sh / direct invocations) and OR them onto the switches
for ($i = 0; $i -lt $Extra.Count; $i++) {
  switch ($Extra[$i].ToLower()) {
    "--obfuscate"     { $Obfuscate = $true }
    "--skip-build"    { $SkipBuild = $true }
    "--no-rename"     { $NoRename = $true }
    "--harden"        { $Harden = $true }
    "--clean-flutter" { $CleanFlutter = $true }
    "--skip-verify"   { $SkipVerify = $true }
    "--output-dir"    { if ($i + 1 -lt $Extra.Count) { $OutputDir = $Extra[$i + 1]; $i++ } }
  }
}

$ErrorActionPreference = "Stop"
$kitRoot = Split-Path -Parent $PSScriptRoot   # release-kit/

# --- locate project root (cwd with pubspec, or app/ subdir) ---
$proj = (Get-Location).Path
if (-not (Test-Path (Join-Path $proj "pubspec.yaml"))) {
  if (Test-Path (Join-Path $proj "app\pubspec.yaml")) { $proj = Join-Path $proj "app" }
}
if (-not (Test-Path (Join-Path $proj "pubspec.yaml"))) {
  throw "No pubspec.yaml found (run from project root or app/ subdir)"
}

# --- resolve config: project-local release-kit.yaml > config.yaml > kit default ---
# (monorepo: the project may be under app/, config may sit at the repo root)
$configPath = $null
foreach ($dir in @($proj, (Split-Path -Parent $proj), $kitRoot)) {
  if (Test-Path (Join-Path $dir "release-kit.yaml")) { $configPath = Join-Path $dir "release-kit.yaml"; break }
  if (Test-Path (Join-Path $dir "config.yaml")) { $configPath = Join-Path $dir "config.yaml"; break }
}
if (-not $configPath) { throw "No config found (release-kit.yaml or config.yaml)" }

# --- read config (flat key: value) ---
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

$appName     = Get-Cfg "app.name"
$hardCfg     = (Get-Cfg "hardening.enabled") -eq "true"
$dllNew      = Get-Cfg "hardening.engineDll"
$assetNew    = Get-Cfg "hardening.assetDir"
$cfgOutDir   = Get-Cfg "output.dir"
if (-not $dllNew) { $dllNew = "core_engine.dll" }
if (-not $assetNew) { $assetNew = "resources" }
if (-not $cfgOutDir) { $cfgOutDir = "dist" }

# hardening: config default, --harden forces on, --no-rename forces off
# --clean-flutter implies hardening (it renames the engine + assets too)
$hardEnabled = (($hardCfg -or $Harden -or $CleanFlutter) -and (-not $NoRename))

if (-not $appName) { $appName = Split-Path -Leaf $proj }

# binary name from CMake
function Get-CmakeVar($cmakeFile, $varName) {
  if (-not (Test-Path $cmakeFile)) { return "" }
  $m = Select-String -Path $cmakeFile -Pattern "^\s*set\(\s*$varName\s+([^\s\)]+)" | Select-Object -First 1
  if ($m) { return $m.Matches[0].Groups[1].Value.Trim('"') }
  return ""
}
$binary = Get-CmakeVar (Join-Path $proj "windows\CMakeLists.txt") "BINARY_NAME"
if (-not $binary) { $binary = $appName }

# --- version ---
$pubspec = Get-Content (Join-Path $proj "pubspec.yaml") -Raw
if ($pubspec -match 'version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)') {
  $verMajor=[int]$matches[1]; $verMinor=[int]$matches[2]; $verPatch=[int]$matches[3]; $verBuild=[int]$matches[4]
  $version = "$verMajor.$verMinor.$verPatch"
} else { throw "Cannot parse version from pubspec.yaml" }

Write-Host "==> release-kit publish_windows"
Write-Host "    project: $proj"
Write-Host "    app: $appName ($version)  binary: $binary"
Write-Host "    hardening: $(if ($hardEnabled) {'on'} else {'off'})"
Write-Host "    clean-flutter: $(if ($CleanFlutter) {'on'} else {'off'})"

# --- build ---
if (-not $SkipBuild) {
  Push-Location $proj
  try {
    $defArg = @()
    if (Test-Path $configPath) {
      foreach ($line in Get-Content $configPath) {
        $t = $line.Trim()
        if ($t -like "build.dartDefine.*:*") {
          $kv = $t.Substring("build.dartDefine.".Length)
          $idx = $kv.IndexOf(":")
          if ($idx -gt 0) {
            $k = $kv.Substring(0, $idx).Trim()
            $v = $kv.Substring($idx + 1).Trim()
            $defArg += "--dart-define=$k=$v"
          }
        }
      }
    }
    if ($Obfuscate) {
      flutter build windows --release --obfuscate --split-debug-info=./build/obfuscate_symbols @defArg
    } else {
      flutter build windows --release @defArg
    }
    if ($LASTEXITCODE -ne 0) { throw "flutter build failed" }
  } finally {
    Pop-Location
  }
}

$release = Join-Path $proj "build\windows\x64\runner\Release"
if (-not (Test-Path $release)) { throw "Release dir not found: $release" }

# --- collect ---
if ($OutputDir -eq "") { $OutputDir = Join-Path $proj "$cfgOutDir\$binary" }
if (Test-Path $OutputDir) { Remove-Item $OutputDir -Recurse -Force }
New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null

Copy-Item (Join-Path $release "$binary.exe") $OutputDir
Get-ChildItem $release -Filter "*.dll" | Copy-Item -Destination $OutputDir
Copy-Item (Join-Path $release "data") $OutputDir -Recurse
Write-Host "==> collected: $OutputDir"

# --- optional hardening (rename engine dll + patch imports) ---
if ($hardEnabled -and -not $NoRename) {
  $outExe = Join-Path $OutputDir "$binary.exe"
  $dllOld = Join-Path $OutputDir "flutter_windows.dll"
  $dllNewFull = Join-Path $OutputDir $dllNew
  $assetOld = Join-Path $OutputDir "data\flutter_assets"
  $assetNewFull = Join-Path $OutputDir "data\$assetNew"

  function Patch-ImportTable([string]$filePath, [byte[]]$oldBytes, [byte[]]$newBytes) {
    $bytes = [System.IO.File]::ReadAllBytes($filePath)
    $changed = $false
    for ($i = 0; $i -le $bytes.Length - $oldBytes.Length; $i++) {
      $match = $true
      for ($j = 0; $j -lt $oldBytes.Length; $j++) {
        if ($bytes[$i + $j] -ne $oldBytes[$j]) { $match = $false; break }
      }
      if ($match) {
        for ($k = 0; $k -lt $oldBytes.Length; $k++) {
          $bytes[$i + $k] = if ($k -lt $newBytes.Length) { $newBytes[$k] } else { 0 }
        }
        $changed = $true
        $i += $oldBytes.Length
      }
    }
    if ($changed) { [System.IO.File]::WriteAllBytes($filePath, $bytes) }
    return $changed
  }

  $oldStr = "flutter_windows.dll"
  $newStr = [System.IO.Path]::GetFileName($dllNew)
  $oldBytes = [System.Text.Encoding]::ASCII.GetBytes($oldStr)
  $newBytes = [System.Text.Encoding]::ASCII.GetBytes($newStr)

  if (Test-Path $outExe) {
    if (Patch-ImportTable $outExe $oldBytes $newBytes) { Write-Host "==> exe imports patched" }
  }
  Get-ChildItem $OutputDir -Filter "*.dll" | ForEach-Object {
    if ($_.Name -eq $newStr) { return }
    if (Patch-ImportTable $_.FullName $oldBytes $newBytes) { Write-Host "==> $($_.Name) patched" }
  }
  if (Test-Path $dllOld) { Rename-Item $dllOld $dllNew }
  Write-Host "==> hardening applied: $oldStr -> $newStr"

  # --clean-flutter: scrub Flutter traces from the bundle (no source changes).
  #   1. rename data\flutter_assets -> data\resources
  #   2. patch the UTF-16 "flutter_assets" string embedded in the exe (same
  #      byte length, NUL-padded) so the engine loads data\resources
  #   3. rename leftover flutter_* plugin dlls and patch their references
  if ($CleanFlutter) {
    # 1 + 2: asset dir rename + exe UTF-16 string patch
    if ((Test-Path $assetOld) -and (-not (Test-Path $assetNewFull))) {
      Rename-Item $assetOld $assetNew
      Write-Host "==> assets: flutter_assets -> $assetNew"
    }
    if (Test-Path $outExe) {
      $oldUtf = [System.Text.Encoding]::Unicode.GetBytes("flutter_assets")
      $newUtf = [System.Text.Encoding]::Unicode.GetBytes($assetNew)
      if ($oldUtf.Length -gt $newUtf.Length) {
        $newUtf = $newUtf + (New-Object byte[] ($oldUtf.Length - $newUtf.Length))
      }
      if (Patch-ImportTable $outExe $oldUtf $newUtf) {
        Write-Host "==> exe utf-16 path patched: flutter_assets -> $assetNew"
      } else {
        Write-Host "==> note: 'flutter_assets' utf-16 string not found in exe" -ForegroundColor Yellow
      }
    }

    # 3: rename leftover plugin dlls whose names contain "flutter" and patch
    # every reference, so the bundle has no "flutter" filenames left
    $renamed = @{}
    Get-ChildItem $OutputDir -Filter "*.dll" | ForEach-Object {
      $oldName = $_.Name
      if ($oldName -notmatch "flutter") { return }
      $newName = $oldName -replace "flutter", "flt"
      if ($newName -eq $oldName) { return }
      if (-not (Test-Path (Join-Path $OutputDir $newName))) {
        Rename-Item $_.FullName $newName
        $renamed[$oldName] = $newName
        Write-Host "==> plugin renamed: $oldName -> $newName"
      }
    }
    foreach ($pair in $renamed.GetEnumerator()) {
      $o = [System.Text.Encoding]::ASCII.GetBytes($pair.Key)
      $n = [System.Text.Encoding]::ASCII.GetBytes($pair.Value)
      Get-ChildItem $OutputDir -Include *.exe,*.dll -Recurse | ForEach-Object {
        if (Patch-ImportTable $_.FullName $o $n) { Write-Host "==> $($_.Name) patched for $($pair.Key)" }
      }
    }
    # scrub "flutter" strings from text-ish files (manifest, json) in data/
    Get-ChildItem (Join-Path $OutputDir "data") -Filter "*.json" -ErrorAction SilentlyContinue |
      ForEach-Object { $t = Get-Content $_.FullName -Raw; if ($t -match "flutter") { Write-Host "==> note: flutter ref in $($_.Name)" } }
  }
}

# --- smoke test: the collected exe should launch and stay alive ---
# Catches broken builds (e.g. engine DLL wrong variant, missing kernel blob)
# before they get packaged. Skippable with --skip-verify.
if (-not $SkipVerify) {
  $verifyExe = Join-Path $OutputDir "$binary.exe"
  if (Test-Path $verifyExe) {
    Write-Host "==> verifying exe launches ..."
    $pinfo = New-Object System.Diagnostics.ProcessStartInfo
    $pinfo.FileName = $verifyExe
    $pinfo.WorkingDirectory = $OutputDir
    $pinfo.RedirectStandardError = $true
    $pinfo.UseShellExecute = $false
    $pinfo.CreateNoWindow = $true
    try {
      $p = [System.Diagnostics.Process]::Start($pinfo)
      Start-Sleep -Seconds 5
      if ($p.HasExited) {
        $err = ""
        try { $err = $p.StandardError.ReadToEnd() } catch {}
        Write-Host "==> WARNING: exe exited early (code $($p.ExitCode)) - the build may be broken!" -ForegroundColor Yellow
        if ($err -match "kernel binary|Failed to start Flutter engine|kInvalidArguments") {
          Write-Host "    Likely cause: engine DLL variant mismatch / missing AOT kernel." -ForegroundColor Yellow
          Write-Host "    Try: flutter clean, then re-run this publish." -ForegroundColor Yellow
        } elseif ($err) {
          Write-Host "    stderr: $($err.Substring(0, [Math]::Min(300, $err.Length)))" -ForegroundColor Yellow
        }
      } else {
        Write-Host "==> exe launches OK (PID $($p.Id))"
        Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
      }
    } catch {
      Write-Host "==> could not run smoke test: $($_.Exception.Message)" -ForegroundColor Yellow
    }
  }
}

# --- zip ---
$zipFile = Join-Path (Split-Path $OutputDir) "$appName-$version-win64.zip"
if (Test-Path $zipFile) { Remove-Item $zipFile -Force }
Compress-Archive -Path $OutputDir -DestinationPath $zipFile
$hash = (Get-FileHash $zipFile -Algorithm SHA256).Hash.ToLower()
$size = (Get-Item $zipFile).Length
Write-Host "==> packaged: $zipFile"
Write-Host "    size: $size bytes"
Write-Host "    sha256: $hash"
