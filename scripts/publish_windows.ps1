# release-kit: publish Windows build (config-driven)
# Usage:
#   powershell -ExecutionPolicy Bypass -File publish_windows.ps1 [-Obfuscate] [-SkipBuild] [-OutputDir <path>]
# Run from the Flutter project root (or app/ subdir in a monorepo).

param(
  [switch]$Obfuscate,
  [switch]$SkipBuild,
  [switch]$NoRename,
  [string]$OutputDir = ""
)

$ErrorActionPreference = "Stop"
$kitRoot = Split-Path -Parent $PSScriptRoot   # release-kit/
$configPath = Join-Path $kitRoot "config.yaml"

# --- read config (flat key: value) ---
function Get-Cfg($key) {
  if (-not (Test-Path $configPath)) { return "" }
  foreach ($line in Get-Content $configPath) {
    $t = $line.Trim()
    if ($t -eq "" -or $t.StartsWith("#")) { continue }
    if ($t.StartsWith("${key}:")) {
      return ($t.Substring($key.Length + 1).Trim())
    }
  }
  return ""
}

$appName    = Get-Cfg "app.name"
$display    = Get-Cfg "app.displayName"
$icon       = Get-Cfg "app.icon"
$bundleId   = Get-Cfg "app.bundleId"
$hardEnabled = (Get-Cfg "hardening.enabled") -eq "true"
$dllNew     = Get-Cfg "hardening.engineDll"
$assetNew   = Get-Cfg "hardening.assetDir"
if (-not $dllNew) { $dllNew = "core_engine.dll" }
if (-not $assetNew) { $assetNew = "resources" }

# --- locate project root (cwd with pubspec, or app/ subdir) ---
$proj = (Get-Location).Path
if (-not (Test-Path (Join-Path $proj "pubspec.yaml"))) {
  if (Test-Path (Join-Path $proj "app\pubspec.yaml")) { $proj = Join-Path $proj "app" }
}
if (-not (Test-Path (Join-Path $proj "pubspec.yaml"))) {
  throw "No pubspec.yaml found (run from project root or app/ subdir)"
}
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
  } finally { Pop-Location }
}

$release = Join-Path $proj "build\windows\x64\runner\Release"
if (-not (Test-Path $release)) { throw "Release dir not found: $release" }

# --- collect ---
if ($OutputDir -eq "") { $OutputDir = Join-Path $proj "dist\$binary" }
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
  if ((Test-Path $assetOld) -and -not (Test-Path $assetNewFull)) { Rename-Item $assetOld $assetNew }
  Write-Host "==> hardening applied: $oldStr -> $newStr, flutter_assets -> $assetNew"
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
