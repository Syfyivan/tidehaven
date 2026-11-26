param([switch]$SkipChecks)
$ErrorActionPreference = 'Stop'
$repo = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
$slice = Join-Path $repo 'experiments/stardew-spike'
$runtime = Join-Path $repo 'artifacts/stardew-spike/runtime'
if (-not (Test-Path -LiteralPath (Join-Path $runtime 'smapi-internal/0Harmony.dll'))) { throw 'Run setup-runtime.ps1 first.' }
if (-not $SkipChecks) {
    & dotnet run --project (Join-Path $slice 'checks/TidehavenSpike.Checks.csproj')
    if ($LASTEXITCODE -ne 0) { throw 'Rule checks failed.' }
}
foreach ($project in @('bootstrap/bootstrap.csproj','mod/TidehavenSpike.csproj')) {
    & dotnet build (Join-Path $slice $project) --nologo -v minimal
    if ($LASTEXITCODE -ne 0) { throw ('Build failed: ' + $project) }
}
$bootstrap = Join-Path $slice 'bootstrap/bin/Debug/net6.0/win-x64'
foreach ($name in @('TidehavenBootstrap.exe','TidehavenBootstrap.dll')) { Copy-Item -LiteralPath (Join-Path $bootstrap $name) -Destination $runtime -Force }
Copy-Item -LiteralPath (Join-Path $runtime 'Stardew Valley.runtimeconfig.json') -Destination (Join-Path $runtime 'TidehavenBootstrap.runtimeconfig.json') -Force
Copy-Item -LiteralPath (Join-Path $runtime 'Stardew Valley.deps.json') -Destination (Join-Path $runtime 'TidehavenBootstrap.deps.json') -Force
Copy-Item -LiteralPath (Join-Path $runtime 'Stardew Valley.deps.json') -Destination (Join-Path $runtime 'StardewModdingAPI.deps.json') -Force
$destination = Join-Path $runtime 'Mods/TidehavenSpike'
New-Item -ItemType Directory -Path (Join-Path $destination 'assets') -Force | Out-Null
foreach ($name in @('TidehavenSpike.dll','manifest.json')) { Copy-Item -LiteralPath (Join-Path $slice ('mod/bin/Debug/net6.0/' + $name)) -Destination $destination -Force }
Copy-Item -LiteralPath (Join-Path $repo 'assets/characters/swimming/diver-hood.png') -Destination (Join-Path $destination 'assets/diver.png') -Force
Write-Output ('Built isolated experiment: ' + $destination)
