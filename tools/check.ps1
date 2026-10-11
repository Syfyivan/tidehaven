param([string]$Godot = '')
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not $Godot) {
    $engineCandidates = @(Get-ChildItem -LiteralPath "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Filter '*godot*' -Directory | ForEach-Object {
        Get-ChildItem -LiteralPath $_.FullName -Recurse -Filter '*_console.exe' | Where-Object Name -Like 'Godot*'
    })
    if ($engineCandidates.Count -eq 0) { throw 'Godot not found. Pass -Godot with the installed executable path.' }
    $Godot = $engineCandidates[0].FullName
}
$runRoot = Join-Path $projectRoot ('artifacts\checks-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Path $runRoot -Force | Out-Null
$stateLog = Join-Path $runRoot 'state.log'
& $Godot --headless --path $projectRoot --script res://tests/state_test.gd *> $stateLog
if ($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath $stateLog -Pattern '^(SCRIPT ERROR|ERROR:|FAIL )')) {
    Get-Content -LiteralPath $stateLog
    throw 'State tests failed.'
}
Get-Content -LiteralPath $stateLog
$inventoryLog = Join-Path $runRoot 'inventory.log'
& $Godot --headless --path $projectRoot --script res://tests/inventory_test.gd *> $inventoryLog
Get-Content -LiteralPath $inventoryLog
if ($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath $inventoryLog -Pattern '^(SCRIPT ERROR|ERROR:|FAIL )')) { throw 'Inventory tests failed.' }
$persistenceLog = Join-Path $runRoot 'persistence.log'
$survivalLog = Join-Path $runRoot 'survival.log'
& $Godot --headless --path $projectRoot --script res://tests/survival_test.gd *> $survivalLog
Get-Content -LiteralPath $survivalLog
if ($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath $survivalLog -Pattern '^(SCRIPT ERROR|ERROR:|FAIL )')) { throw 'Survival tests failed.' }
$progressionLog = Join-Path $runRoot 'progression.log'
& $Godot --headless --path $projectRoot --script res://tests/progression_test.gd *> $progressionLog
Get-Content -LiteralPath $progressionLog
if ($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath $progressionLog -Pattern '^(SCRIPT ERROR|ERROR:|FAIL )')) { throw 'Progression tests failed.' }
$oceanLog = Join-Path $runRoot 'ocean.log'
& $Godot --headless --path $projectRoot --script res://tests/ocean_test.gd *> $oceanLog
Get-Content -LiteralPath $oceanLog
if ($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath $oceanLog -Pattern '^(SCRIPT ERROR|ERROR:|FAIL )')) { throw 'Ocean tests failed.' }
$navigationLog = Join-Path $runRoot 'navigation.log'
& $Godot --headless --path $projectRoot --script res://tests/navigation_test.gd *> $navigationLog
Get-Content -LiteralPath $navigationLog
if ($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath $navigationLog -Pattern '^(SCRIPT ERROR|ERROR:|FAIL )')) { throw 'Navigation tests failed.' }
$islandLog = Join-Path $runRoot 'island.log'
& $Godot --headless --path $projectRoot --script res://tests/island_checks.gd *> $islandLog
Get-Content -LiteralPath $islandLog
if ($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath $islandLog -Pattern '^(SCRIPT ERROR|ERROR:|FAIL )')) { throw 'Island tests failed.' }
$motionLog = Join-Path $runRoot 'view-motion.log'
& $Godot --headless --path $projectRoot --script res://tests/view_motion_test.gd *> $motionLog
Get-Content -LiteralPath $motionLog
if ($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath $motionLog -Pattern '^(SCRIPT ERROR|ERROR:|FAIL )')) { throw 'View motion tests failed.' }
foreach ($visualContract in @('character','viewport')) {
    $contractLog = Join-Path $runRoot ($visualContract + '.log')
    & $Godot --headless --path $projectRoot --script ('res://tests/' + $visualContract + '_test.gd') *> $contractLog
    Get-Content -LiteralPath $contractLog
    if ($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath $contractLog -Pattern '^(SCRIPT ERROR|ERROR:|FAIL )')) { throw "$visualContract tests failed." }
}
& $Godot --headless --path $projectRoot --script res://tests/persistence_test.gd *> $persistenceLog
Get-Content -LiteralPath $persistenceLog
if ($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath $persistenceLog -Pattern '^(SCRIPT ERROR|ERROR:|FAIL )')) { throw 'Persistence tests failed.' }
$propLog = Join-Path $runRoot 'prop-art.log'
& $Godot --headless --path $projectRoot --script res://tests/prop_art_checks.gd *> $propLog
Get-Content -LiteralPath $propLog
if ($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath $propLog -Pattern '^(SCRIPT ERROR|ERROR:|FAIL )')) { throw 'Prop art tests failed.' }
foreach ($contract in @('farming_checks','island_map_checks','island_town_checks','island_migration_10_checks','sailing_skill_checks','hook_multi_checks','underwater_actions_checks','exploration_ui_checks','island_ui_checks','held_item_ui_checks')) {
    $contractLog = Join-Path $runRoot ($contract + '.log')
    & $Godot --headless --path $projectRoot --script ('res://tests/' + $contract + '.gd') *> $contractLog
    Get-Content -LiteralPath $contractLog
    if ($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath $contractLog -Pattern '^(SCRIPT ERROR|ERROR:|FAIL )')) { throw "$contract failed." }
}
$testSave = Join-Path $runRoot 'network-world.json'
$udpProbe = [System.Net.Sockets.UdpClient]::new(0)
$testPort = $udpProbe.Client.LocalEndPoint.Port
$udpProbe.Dispose()
$hostProcess = $null
$clientProcess = $null
try {
    $baseArguments = @('--headless', '--path', ('"' + $projectRoot + '"'), '--max-fps', '30', '--')
    $hostArguments = $baseArguments + @('--test-role=host', ('--save-path="' + $testSave + '"'), ('--port=' + $testPort), ('--report="' + (Join-Path $runRoot 'host.json') + '"'))
    $hostProcess = Start-Process -FilePath $Godot -ArgumentList $hostArguments -PassThru -WindowStyle Hidden -RedirectStandardOutput (Join-Path $runRoot 'host.log') -RedirectStandardError (Join-Path $runRoot 'host.err')
    $null = $hostProcess.Handle
    Start-Sleep -Milliseconds 1200
    $clientArguments = $baseArguments + @('--test-role=client', ('--save-path="' + (Join-Path $runRoot 'unused-client.json') + '"'), ('--port=' + $testPort), ('--report="' + (Join-Path $runRoot 'client.json') + '"'))
    $clientProcess = Start-Process -FilePath $Godot -ArgumentList $clientArguments -PassThru -WindowStyle Hidden -RedirectStandardOutput (Join-Path $runRoot 'client.log') -RedirectStandardError (Join-Path $runRoot 'client.err')
    $null = $clientProcess.Handle
    $watch = [System.Diagnostics.Stopwatch]::StartNew()
    while ((-not $hostProcess.HasExited -or -not $clientProcess.HasExited) -and $watch.Elapsed.TotalSeconds -lt 85) { Start-Sleep -Milliseconds 500 }
    if (-not $hostProcess.HasExited -or -not $clientProcess.HasExited) { throw 'Network validation timed out.' }
    foreach ($role in @('host','client')) {
        Get-Content -LiteralPath (Join-Path $runRoot ($role + '.log'))
        $errors = Get-Content -LiteralPath (Join-Path $runRoot ($role + '.err')) -Raw
        if ($errors -match '(SCRIPT ERROR|ERROR:)') { Write-Output $errors; throw "$role reported engine errors." }
        if (-not (Test-Path -LiteralPath (Join-Path $runRoot ($role + '.json')))) { throw "$role produced no passing report." }
    }
    if ($hostProcess.ExitCode -ne 0 -or $clientProcess.ExitCode -ne 0) { throw 'A network validator exited unsuccessfully.' }
} finally {
    foreach ($validator in @($hostProcess,$clientProcess)) {
        if ($null -ne $validator -and -not $validator.HasExited) { Stop-Process -Id $validator.Id -Force }
    }
}
$resumeLog = Join-Path $runRoot 'resume.log'
& $Godot --headless --path $projectRoot --max-fps 30 -- --test-role=resume "--save-path=$testSave" "--report=$(Join-Path $runRoot 'resume.json')" *> $resumeLog
Get-Content -LiteralPath $resumeLog
if ($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath $resumeLog -Pattern '^(SCRIPT ERROR|ERROR:|FAIL )') -or -not (Test-Path -LiteralPath (Join-Path $runRoot 'resume.json'))) { throw 'Solo resume test failed.' }
Write-Output "CHECKS PASSED. Evidence: $runRoot"
