param([string]$Godot = '')
$ErrorActionPreference = 'Stop'
$watch = [System.Diagnostics.Stopwatch]::StartNew()
$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not $Godot) {
    $candidates = @(Get-ChildItem -LiteralPath "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Filter '*godot*' -Directory | ForEach-Object {
        Get-ChildItem -LiteralPath $_.FullName -Recurse -Filter '*_console.exe' | Where-Object Name -Like 'Godot*'
    })
    if ($candidates.Count -eq 0) { throw 'Godot not found. Pass -Godot with the installed console executable.' }
    $Godot = $candidates[0].FullName
}
if (-not (Test-Path -LiteralPath $Godot -PathType Leaf)) { throw 'Godot executable does not exist.' }
$suffix = (Get-Date -Format 'yyyyMMdd-HHmmss-fff') + '-' + [Guid]::NewGuid().ToString('N').Substring(0, 8)
$runRoot = Join-Path $projectRoot ('artifacts\progression-network-' + $suffix)
New-Item -ItemType Directory -Path $runRoot | Out-Null
$testSave = Join-Path $runRoot 'world-v7.json'
$udpProbe = [System.Net.Sockets.UdpClient]::new(0)
try { $testPort = $udpProbe.Client.LocalEndPoint.Port } finally { $udpProbe.Dispose() }
$baseArguments = @('--headless', '--path', ('"' + $projectRoot + '"'), '--max-fps', '30', '--', '--progression-net')
$processes = @{}

function Show-ValidatorLogs([string]$Role) {
    foreach ($extension in @('log', 'err')) {
        $logPath = Join-Path $runRoot ($Role + '.' + $extension)
        if (Test-Path -LiteralPath $logPath) { Get-Content -LiteralPath $logPath -Tail 100 }
    }
}

function Start-Validator([string]$Role, [string]$SavePath) {
    if ($watch.Elapsed.TotalSeconds -ge 88) { throw 'Progression network deadline reached before launch.' }
    $arguments = $baseArguments + @(('--test-role=' + $Role), ('--save-path="' + $SavePath + '"'), ('--port=' + $testPort), ('--report="' + (Join-Path $runRoot ($Role + '.json')) + '"'))
    $process = Start-Process -FilePath $Godot -ArgumentList $arguments -PassThru -WindowStyle Hidden -RedirectStandardOutput (Join-Path $runRoot ($Role + '.log')) -RedirectStandardError (Join-Path $runRoot ($Role + '.err'))
    $processes[$Role] = $process
    return $process
}

function Assert-Validator([string]$Role) {
    $process = $processes[$Role]
    $process.WaitForExit()
    Show-ValidatorLogs $Role
    if ($process.ExitCode -ne 0) { throw "$Role exited with code $($process.ExitCode)." }
    foreach ($extension in @('log', 'err')) {
        $content = Get-Content -LiteralPath (Join-Path $runRoot ($Role + '.' + $extension)) -Raw
        if ($content -match '(SCRIPT ERROR|ERROR:|PROGRESSION NETWORK FAIL)') { throw "$Role reported engine or validation errors." }
    }
    $reportPath = Join-Path $runRoot ($Role + '.json')
    if (-not (Test-Path -LiteralPath $reportPath)) { throw "$Role produced no passing report." }
    $report = Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json
    if (-not $report.passed -or $report.role -ne $Role -or $report.checks.Count -lt 3) { throw "$Role report was incomplete or did not pass." }
}

try {
    Write-Output "Controlled progression RPC regression on UDP $testPort. Evidence: $runRoot"
    $hostProcess = Start-Validator 'host' $testSave
    $readyPath = Join-Path $runRoot 'host.json.ready'
    while (-not (Test-Path -LiteralPath $readyPath)) {
        if ($hostProcess.HasExited) { Show-ValidatorLogs 'host'; throw 'Host stopped before its controlled fixture was ready.' }
        if ($watch.Elapsed.TotalSeconds -ge 88) { throw 'Progression network validation timed out during host setup.' }
        Start-Sleep -Milliseconds 100
    }
    $clientProcess = Start-Validator 'client' (Join-Path $runRoot 'unused-client.json')
    while (-not $hostProcess.HasExited -or -not $clientProcess.HasExited) {
        foreach ($role in @('host', 'client')) {
            $process = $processes[$role]
            if ($process.HasExited -and $process.ExitCode -ne 0) { Show-ValidatorLogs $role; throw "$role failed during network validation." }
        }
        if ($watch.Elapsed.TotalSeconds -ge 88) { throw 'Progression network validation timed out.' }
        Start-Sleep -Milliseconds 200
    }
    Assert-Validator 'host'
    Assert-Validator 'client'
    $resumeProcess = Start-Validator 'resume' $testSave
    while (-not $resumeProcess.HasExited) {
        if ($watch.Elapsed.TotalSeconds -ge 88) { throw 'Progression network validation timed out during solo restore.' }
        Start-Sleep -Milliseconds 100
    }
    Assert-Validator 'resume'
    Write-Output "PROGRESSION NETWORK PASSED. Evidence: $runRoot"
} finally {
    # Only process objects launched by this invocation are eligible for cleanup.
    foreach ($validator in $processes.Values) {
        if (-not $validator.HasExited) { Stop-Process -Id $validator.Id -Force -ErrorAction SilentlyContinue }
        $validator.Dispose()
    }
}
