# Build a Microsoft Store–ready MSIX for Orbita (unsigned; Store signs on upload).
# Prerequisites: Flutter Windows desktop, VS Build Tools, Partner Center identity
# already pasted into pubspec.yaml msix_config (see comments there).
#
# Usage (from apps/windows_client):
#   powershell -ExecutionPolicy Bypass -File .\scripts\build_store_msix.ps1
# Optional:
#   -ApiBaseUrl https://api.example.com
#   -SkipBuild   (pack existing Release output only)

param(
  [string]$ApiBaseUrl = "",
  [string]$ProProductId = "pro_monthly",
  [switch]$SkipBuild
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$RepoRoot = Split-Path -Parent (Split-Path -Parent $Root)
Set-Location $Root

# Release INSTALL fails if chatai.exe is still running (file lock).
Get-Process -Name chatai -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 1

$defines = @(
  "--dart-define=MS_STORE_PRO_PRODUCT_ID=$ProProductId"
)
if ($ApiBaseUrl) {
  $defines += "--dart-define=API_BASE_URL=$ApiBaseUrl"
}

$outDir = Join-Path $RepoRoot "dist\msix"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

Write-Host "Output directory: $outDir"
Write-Host "Product id: $ProProductId"
if ($ApiBaseUrl) { Write-Host "API_BASE_URL: $ApiBaseUrl" }

$buildArgs = ($defines -join " ")
$extra = @("--store", "--output-path=$outDir", "--output-name=Orbita")
if ($SkipBuild) {
  $extra += "--build-windows=false"
} else {
  $extra += "--windows-build-args=$buildArgs"
}

dart run msix:create @extra
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

# Partner Center accepts a bare .msix; .msixupload is a zip wrapping it.
$upload = Join-Path $outDir "Orbita.msixupload"
Remove-Item $upload -Force -ErrorAction SilentlyContinue
$zip = Join-Path $outDir "Orbita.zip"
Compress-Archive -Path (Join-Path $outDir "Orbita.msix") -DestinationPath $zip -CompressionLevel NoCompression -Force
Rename-Item $zip "Orbita.msixupload"

Get-ChildItem $outDir -Filter "Orbita*.msix*" | ForEach-Object {
  Write-Host "ARTIFACT: $($_.FullName) ($([math]::Round($_.Length/1MB, 2)) MB)"
}
