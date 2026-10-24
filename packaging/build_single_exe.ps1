param(
  [string]$Flutter = 'flutter',
  [switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'
$workspace = Split-Path $PSScriptRoot -Parent
$packager = Join-Path $workspace 'flutter\tool\package_windows.ps1'
& $packager -Flutter $Flutter -SkipBuild:$SkipBuild
$zip = Join-Path $workspace 'release\AstraPathing-Windows.zip'
if (-not (Test-Path -LiteralPath $zip)) { throw 'Windows bundle packaging failed.' }

$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not (Test-Path -LiteralPath $compiler)) { throw 'The .NET Framework C# compiler was not found.' }
$source = Join-Path $PSScriptRoot 'AstraPathLauncher.cs'
$icon = Join-Path $workspace 'flutter\windows\runner\resources\app_icon.ico'
$output = Join-Path $workspace 'release\AstraPathing.exe'
$compilerArgs = @(
  '/nologo', '/target:winexe', '/platform:x64', '/optimize+',
  "/out:$output", "/resource:$zip,AstraPathPayload.zip", "/win32icon:$icon",
  '/reference:System.IO.Compression.dll',
  '/reference:System.IO.Compression.FileSystem.dll',
  '/reference:System.Windows.Forms.dll',
  $source
)
& $compiler @compilerArgs
if ($LASTEXITCODE -ne 0) { throw 'Single-file launcher compilation failed.' }
Write-Output "Built $output"
