param([string]$Game = '', [string]$Resolution = '', [switch]$Island, [switch]$Skill)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not $Game) { $Game = Join-Path $projectRoot 'build\Tidehaven-0.10.1.exe' }
if (-not (Test-Path -LiteralPath $Game)) { throw 'Export the Windows game before running this check.' }
$runRoot = Join-Path $projectRoot ('artifacts\playthrough-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
New-Item -ItemType Directory -Path $runRoot | Out-Null
$stdout = Join-Path $runRoot 'playthrough.log'
$stderr = Join-Path $runRoot 'playthrough.err'
$reportPath = Join-Path $runRoot 'report.json'
$arguments = @('--max-fps', '30', '--', '--playthrough', ('--save-path="' + (Join-Path $runRoot 'world.json') + '"'), ('--report="' + $reportPath + '"'), ('--evidence-dir="' + $runRoot + '"'))
if ($Island) { $arguments[3] = '--island-playthrough' }
if ($Skill) { $arguments[3] = '--skill-playthrough' }
if ((Split-Path -Leaf $Game) -like 'Godot*') { $arguments = @('--path', ('"' + $projectRoot + '"')) + $arguments }
if ($Resolution) {
    if ($Resolution -notmatch '^\d{3,5}x\d{3,5}$') { throw 'Resolution must be WIDTHxHEIGHT.' }
    $arguments = @('--resolution', $Resolution) + $arguments
}
$validator = Start-Process -FilePath $Game -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
$null = $validator.Handle
Write-Output "Packaged survival-opening input playthrough (480-second game deadline). Evidence: $runRoot"
$watch = [Diagnostics.Stopwatch]::StartNew()
try {
    while (-not $validator.HasExited -and $watch.Elapsed.TotalSeconds -lt 510) { Start-Sleep -Milliseconds 500 }
    if (-not $validator.HasExited) { throw 'Packaged playthrough timed out.' }
    Get-Content -LiteralPath $stdout
    $errors = Get-Content -LiteralPath $stderr -Raw
    if ($errors -match '(SCRIPT ERROR|ERROR:)') { Write-Output $errors; throw 'Packaged playthrough reported an engine error.' }
    if ($validator.ExitCode -ne 0) { throw "Packaged playthrough failed with exit code $($validator.ExitCode)." }
    if (-not (Test-Path -LiteralPath $reportPath)) { throw 'No playthrough report was written.' }
    $report = Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json
    if (-not $report.passed) { throw 'Playthrough report did not pass.' }
    Write-Output 'PACKAGED PLAYTHROUGH PASSED'
} finally {
    if (-not $validator.HasExited) { Stop-Process -Id $validator.Id }
}


