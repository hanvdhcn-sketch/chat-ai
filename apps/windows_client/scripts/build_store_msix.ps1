# Build a Microsoft Store-ready MSIX for Orbita (unsigned; Store signs on upload).
# Prerequisites: Flutter Windows desktop, VS Build Tools, Partner Center identity
# already pasted into pubspec.yaml msix_config (see comments there).
#
# A Store build talks to a real, deployed API and a real Supabase project, so
# these three are REQUIRED and the script fails loudly on localhost / plain http
# / placeholder values:
#   -ApiBaseUrl      https://<your-api-host>        (see docs/deploy-fly.md)
#   -SupabaseUrl     https://<ref>.supabase.co
#   -SupabaseAnonKey <public anon key>
#
# Usage (from apps/windows_client):
#   powershell -ExecutionPolicy Bypass -File .\scripts\build_store_msix.ps1 `
#     -ApiBaseUrl https://orbita-api.fly.dev `
#     -SupabaseUrl https://abcd1234.supabase.co `
#     -SupabaseAnonKey eyJ...
# Optional:
#   -AllowLocalApi   local sideload/smoke build only (never upload to the Store)
#   -SkipBuild       pack existing Release output only (config cannot be verified)

param(
  [string]$ApiBaseUrl = "",
  [string]$SupabaseUrl = "",
  [string]$SupabaseAnonKey = "",
  [string]$ProProductId = "pro_monthly",
  [switch]$AllowLocalApi,
  [switch]$SkipBuild
)

$ErrorActionPreference = "Stop"

function Fail([string]$message) {
  Write-Host ""
  Write-Host "BUILD REFUSED: $message" -ForegroundColor Red
  exit 2
}

function Test-LocalHost([string]$hostName) {
  $h = $hostName.ToLowerInvariant()
  if ($h -in @("localhost", "0.0.0.0", "::1", "[::1]")) { return $true }
  if ($h.EndsWith(".local") -or $h.EndsWith(".internal") -or $h.EndsWith(".localhost")) { return $true }
  if ($h -match '^127\.' -or $h -match '^10\.' -or $h -match '^192\.168\.' -or $h -match '^169\.254\.') { return $true }
  if ($h -match '^172\.(1[6-9]|2[0-9]|3[0-1])\.') { return $true }
  return $false
}

function Assert-PublicUrl([string]$name, [string]$value, [bool]$requireHttps) {
  if ([string]::IsNullOrWhiteSpace($value)) {
    Fail "$name is required for a Store build."
  }
  $uri = $null
  if (-not [Uri]::TryCreate($value, [UriKind]::Absolute, [ref]$uri)) {
    Fail "$name is not a valid absolute URL: '$value'"
  }
  if ($value -match 'YOUR_|<|>|example\.com') {
    Fail "$name still contains a placeholder: '$value'"
  }
  if ($requireHttps -and $uri.Scheme -ne "https") {
    Fail "$name must use https for a Store build (got '$($uri.Scheme)'): $value"
  }
  if (Test-LocalHost $uri.Host) {
    Fail "$name points at a local/private host ('$($uri.Host)'). A Store build must use the deployed URL."
  }
}

$strict = -not $AllowLocalApi
if ($strict) {
  Assert-PublicUrl "-ApiBaseUrl" $ApiBaseUrl $true
  Assert-PublicUrl "-SupabaseUrl" $SupabaseUrl $true
  if ([string]::IsNullOrWhiteSpace($SupabaseAnonKey) -or $SupabaseAnonKey -match '^your_|YOUR_|<') {
    Fail "-SupabaseAnonKey is required (the public anon key from Supabase > Project Settings > API)."
  }
  if ($SupabaseAnonKey -match 'service_role') {
    Fail "-SupabaseAnonKey looks like a service_role key. Never ship that; use the anon key."
  }
  if ($SkipBuild) {
    Fail "-SkipBuild cannot prove the existing Release build uses these URLs. Rebuild, or add -AllowLocalApi for a non-Store pack."
  }
} else {
  Write-Host "WARNING: -AllowLocalApi set. This package must NOT be uploaded to the Store." -ForegroundColor Yellow
}

$Root = Split-Path -Parent $PSScriptRoot
$RepoRoot = Split-Path -Parent (Split-Path -Parent $Root)
Set-Location $Root

# Release INSTALL fails if chatai.exe is still running (file lock).
Get-Process -Name chatai -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 1

$defines = @("--dart-define=MS_STORE_PRO_PRODUCT_ID=$ProProductId")
if ($ApiBaseUrl) { $defines += "--dart-define=API_BASE_URL=$ApiBaseUrl" }
if ($SupabaseUrl) { $defines += "--dart-define=SUPABASE_URL=$SupabaseUrl" }
if ($SupabaseAnonKey) { $defines += "--dart-define=SUPABASE_ANON_KEY=$SupabaseAnonKey" }

$outDir = Join-Path $RepoRoot "dist\msix"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

Write-Host "Output directory: $outDir"
Write-Host "Product id: $ProProductId"
if ($ApiBaseUrl) { Write-Host "API_BASE_URL: $ApiBaseUrl" }
if ($SupabaseUrl) { Write-Host "SUPABASE_URL: $SupabaseUrl" }

$buildArgs = ($defines -join " ")
$extra = @("--store", "--output-path=$outDir", "--output-name=Orbita")
if ($SkipBuild) {
  $extra += "--build-windows=false"
} else {
  $extra += "--windows-build-args=$buildArgs"
}

dart run msix:create @extra
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

# Prove the compiled app carries the requested public config (const-folded
# dart-defines are stored as plain strings inside the AOT snapshot).
if ($strict) {
  $appSo = Join-Path $Root "build\windows\x64\runner\Release\data\app.so"
  if (-not (Test-Path $appSo)) { Fail "Cannot verify build: $appSo not found." }
  $bytes = [IO.File]::ReadAllBytes($appSo)
  $text = [Text.Encoding]::ASCII.GetString($bytes)
  foreach ($needle in @($ApiBaseUrl, $SupabaseUrl)) {
    if (-not $text.Contains($needle)) {
      Fail "Built app does not contain '$needle'. Delete build\windows and retry."
    }
  }
  if ($text.Contains("http://localhost:3001") -or $text.Contains("stub:user_demo")) {
    Fail "Built app still embeds the localhost default or the dev stub token. Delete build\windows and retry."
  }
  Write-Host "VERIFIED: Release app.so contains the API and Supabase URLs."
}

# Partner Center accepts a bare .msix; .msixupload is a zip wrapping it.
$upload = Join-Path $outDir "Orbita.msixupload"
Remove-Item $upload -Force -ErrorAction SilentlyContinue
$zip = Join-Path $outDir "Orbita.zip"
Compress-Archive -Path (Join-Path $outDir "Orbita.msix") -DestinationPath $zip -CompressionLevel NoCompression -Force
Rename-Item $zip "Orbita.msixupload"

Get-ChildItem $outDir -Filter "Orbita*.msix*" | ForEach-Object {
  Write-Host "ARTIFACT: $($_.FullName) ($([math]::Round($_.Length/1MB, 2)) MB)"
}
