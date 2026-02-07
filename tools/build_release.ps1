param(
  [string]$ProjectRoot = "E:\quan-ly-tap-hoa",
  [switch]$NoBump
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $ProjectRoot)) {
  throw "Project root not found: $ProjectRoot"
}

$ProjectRoot = (Resolve-Path $ProjectRoot).Path
Set-Location $ProjectRoot

$pubspecPath = Join-Path $ProjectRoot "pubspec.yaml"
if (-not (Test-Path $pubspecPath)) {
  throw "pubspec.yaml not found at $pubspecPath"
}

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  throw "Flutter CLI not found in PATH. Install Flutter or add it to PATH."
}

$keyPropsPath = Join-Path $ProjectRoot "android\\key.properties"
if (-not (Test-Path $keyPropsPath)) {
  throw "Missing android/key.properties. Create it from android/key.properties.example before release build."
}

$props = @{}
Get-Content $keyPropsPath | ForEach-Object {
  $line = $_.Trim()
  if (-not $line) { return }
  if ($line.StartsWith("#")) { return }
  $pair = $line -split "=", 2
  if ($pair.Length -eq 2) {
    $props[$pair[0].Trim()] = $pair[1].Trim()
  }
}

$storeFile = $props["storeFile"]
if (-not $storeFile) {
  throw "storeFile is missing in android/key.properties"
}

if ([System.IO.Path]::IsPathRooted($storeFile)) {
  $storePath = $storeFile
} else {
  $storePath = Join-Path (Join-Path $ProjectRoot "android") $storeFile
}

if (-not (Test-Path $storePath)) {
  throw "Keystore not found at $storePath"
}

$pubspec = Get-Content $pubspecPath -Raw
$versionMatch = [regex]::Match($pubspec, '^[\t ]*version:\s*(\S+)\s*$', 'Multiline')
if (-not $versionMatch.Success) {
  throw "Could not find a 'version:' line in pubspec.yaml"
}

$versionValue = $versionMatch.Groups[1].Value
$parts = $versionValue -split '\+'
if ($parts.Length -ne 2) {
  throw "Version format must be name+buildNumber (e.g., 1.0.0+1). Found: $versionValue"
}

$versionName = $parts[0]
$buildNumber = [int]$parts[1]

if (-not $NoBump) {
  $newBuildNumber = $buildNumber + 1
  $newVersionValue = "$versionName+$newBuildNumber"
  $updatedPubspec = $pubspec -replace '(?m)^[\t ]*version:\s*\S+\s*$', "version: $newVersionValue"
  Set-Content -Path $pubspecPath -Value $updatedPubspec -Encoding utf8
  Write-Host "Updated version: $versionValue -> $newVersionValue"
} else {
  Write-Host "Using version: $versionValue"
}

flutter pub get
flutter build appbundle --release

$aabPath = Join-Path $ProjectRoot "build\\app\\outputs\\bundle\\release\\app-release.aab"
if (Test-Path $aabPath) {
  Write-Host "AAB output: $aabPath"
} else {
  $altAab = Join-Path $ProjectRoot "build\\app\\outputs\\bundle\\release\\app.aab"
  if (Test-Path $altAab) {
    Write-Host "AAB output: $altAab"
  }
}
