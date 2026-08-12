# ZShell release-kit: install pre-commit hook + core.hooksPath (Windows)
# Usage: powershell -ExecutionPolicy Bypass -File install_hook.ps1 [-ProjectRoot <path>]
param(
  [string]$ProjectRoot = ""
)
$ErrorActionPreference = "Stop"

# Locate the release-kit root (scripts/.. = repo root)
$kitRoot = Split-Path -Parent $PSScriptRoot
if ($ProjectRoot -eq "") { $ProjectRoot = (Get-Location).Path }

Write-Host "==> release-kit: $kitRoot"
Write-Host "==> project root: $ProjectRoot"

# Detect pubspec location: app/pubspec.yaml (monorepo) or <root>/pubspec.yaml
$pubspec = ""
if (Test-Path (Join-Path $ProjectRoot "app\pubspec.yaml")) {
  $pubspec = "app/pubspec.yaml"
} elseif (Test-Path (Join-Path $ProjectRoot "pubspec.yaml")) {
  $pubspec = "pubspec.yaml"
} else {
  Write-Error "No pubspec.yaml found under $ProjectRoot (expected <root>/pubspec.yaml or <root>/app/pubspec.yaml)"
}

$pubspecAbs = (Join-Path $ProjectRoot $pubspec).Replace("\", "/")
$bumpAbs = (Join-Path $kitRoot "bin\bump_version.dart").Replace("\", "/")
$repoAbs = $ProjectRoot.Replace("\", "/")

# Read template and substitute placeholders
$template = Get-Content (Join-Path $kitRoot "bin\pre-commit.hook") -Raw
$hook = $template.Replace("{SMART_BUMP_PATH}", $bumpAbs)
$hook = $hook.Replace("{PUBSPEC_PATH}", $pubspecAbs)
$hook = $hook.Replace("{REPO_ROOT}", $repoAbs)

# Write hook into the project's .githooks directory
$hookDir = Join-Path $ProjectRoot ".githooks"
New-Item -ItemType Directory -Path $hookDir -Force | Out-Null
$hookFile = Join-Path $hookDir "pre-commit"
[System.IO.File]::WriteAllText($hookFile, $hook, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "==> hook written: $hookFile"

# Configure core.hooksPath
Push-Location $ProjectRoot
try {
  git config core.hooksPath ".githooks"
  Write-Host "==> core.hooksPath set to .githooks"
} finally {
  Pop-Location
}

Write-Host ""
Write-Host "Done. Version auto-bump enabled on every git commit."
Write-Host "Skip with: git commit --no-verify"
