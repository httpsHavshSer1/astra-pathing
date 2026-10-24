param(
  [string]$Flutter = 'flutter',
  [switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'
$project = Split-Path $PSScriptRoot -Parent
$workspace = Split-Path $project -Parent
$bundle = Join-Path $project 'build\windows\x64\runner\Release'
$zip = Join-Path $workspace 'release\AstraPathing-Windows.zip'

if (-not $SkipBuild) {
  Push-Location $project
  try {
    & $Flutter build windows --release
    if ($LASTEXITCODE -ne 0) { throw 'Flutter release build failed.' }
  } finally {
    Pop-Location
  }
}

if (-not (Test-Path -LiteralPath (Join-Path $bundle 'AstraPathing.exe'))) {
  throw "Windows release build is missing: $bundle"
}

# Flutter's Windows build does not put the Visual C++ runtime beside the exe.
# A portable ZIP needs the x64 runtime from the same Visual Studio installation.
$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
if (-not (Test-Path -LiteralPath $vswhere)) { throw 'Visual Studio vswhere.exe was not found.' }
$vsInstall = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath | Select-Object -First 1
if (-not $vsInstall) { throw 'Visual Studio C++ build tools were not found.' }
$vsInstall = $vsInstall.Trim()
$redist = Join-Path $vsInstall 'VC\Redist\MSVC'
$version = Get-ChildItem -LiteralPath $redist -Directory |
  Where-Object { $_.Name -match '^\d+\.\d+\.\d+$' } |
  Sort-Object { [version]$_.Name } -Descending |
  Select-Object -First 1
if (-not $version) { throw "Visual C++ redistributable files were not found in $redist" }
$crt = Get-ChildItem -LiteralPath (Join-Path $version.FullName 'x64') -Directory -Filter 'Microsoft.VC*.CRT' | Select-Object -First 1
if (-not $crt) { throw 'The x64 Visual C++ runtime directory was not found.' }
$dlls = Get-ChildItem -LiteralPath $crt.FullName -File -Filter '*.dll'
if (-not $dlls) { throw "The x64 Visual C++ runtime is empty: $($crt.FullName)" }
$dlls | Copy-Item -Destination $bundle -Force

New-Item -ItemType Directory -Path (Split-Path $zip -Parent) -Force | Out-Null
Compress-Archive -Path (Join-Path $bundle '*') -DestinationPath $zip -Force
Write-Output "Packaged $zip with $($dlls.Count) Visual C++ runtime DLLs."
