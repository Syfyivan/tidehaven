param([string]$InstalledGame='C:\SteamLibrary\steamapps\common\Stardew Valley')
$ErrorActionPreference='Stop'
$repoRoot=Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
$workspace=Join-Path $repoRoot 'artifacts\stardew-spike'
$runtime=Join-Path $workspace 'runtime'
$payload=Join-Path $workspace 'installer\SMAPI 4.2.1 installer\internal\windows\install.dat'
if(-not (Test-Path -LiteralPath $payload)){throw 'Download and extract the official matching SMAPI 4.2.1 installer first.'}
if(-not (Test-Path -LiteralPath (Join-Path $InstalledGame 'Stardew Valley.dll'))){throw 'Installed game is missing.'}
if(Test-Path -LiteralPath $runtime){throw 'Runtime already exists; preserve it and inspect rather than overwrite.'}
New-Item -ItemType Directory -Path $runtime | Out-Null
Get-ChildItem -LiteralPath $InstalledGame -File | ForEach-Object {Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $runtime $_.Name)}
New-Item -ItemType Junction -Path (Join-Path $runtime 'Content') -Target (Join-Path $InstalledGame 'Content') | Out-Null
[IO.Compression.ZipFile]::ExtractToDirectory($payload,$runtime,$true)
Get-ChildItem -LiteralPath $runtime -Directory | Select-Object -ExpandProperty Name
Write-Output "Isolated runtime: $runtime"
