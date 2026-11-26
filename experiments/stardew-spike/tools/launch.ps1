param([ValidatePattern('^[a-zA-Z0-9_-]+$')][string]$Session='manual')
$ErrorActionPreference = 'Stop'
$repo = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
$root = Join-Path $repo 'artifacts/stardew-spike'
$runtime = Join-Path $root 'runtime'
$sessionPath = Join-Path $root ('sessions/' + $Session)
New-Item -ItemType Directory -Path $sessionPath -Force | Out-Null
$exe = Join-Path $runtime 'TidehavenBootstrap.exe'
if (-not (Test-Path -LiteralPath $exe)) { throw 'Run build.ps1 first.' }
$active = Get-CimInstance Win32_Process -Filter "Name='TidehavenBootstrap.exe'" | Where-Object { $_.ExecutablePath -eq $exe -and $_.CommandLine -like ('*"' + $sessionPath + '"*') }
if ($active) { throw ('This isolated session is already running: ' + $Session) }
$history = Join-Path $sessionPath ('history/' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
New-Item -ItemType Directory -Path $history -Force | Out-Null
foreach ($relative in @('stdout.log','stderr.log','state.json','probe.json','appdata/ErrorLogs/SMAPI-latest.txt')) {
    $old = Join-Path $sessionPath $relative
    if (Test-Path -LiteralPath $old) { Copy-Item -LiteralPath $old -Destination (Join-Path $history ([IO.Path]::GetFileName($relative))) }
}
Get-FileHash -LiteralPath (Join-Path $runtime 'Mods/TidehavenSpike/TidehavenSpike.dll') -Algorithm SHA256 | Select-Object Hash | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $history 'build.json') -Encoding utf8
$process = Start-Process -FilePath $exe -WorkingDirectory $runtime -ArgumentList @('--session-root',('"'+$sessionPath+'"'),'--mods-path',('"'+(Join-Path $runtime 'Mods')+'"')) -WindowStyle Hidden -RedirectStandardOutput (Join-Path $sessionPath 'stdout.log') -RedirectStandardError (Join-Path $sessionPath 'stderr.log') -PassThru
[pscustomobject]@{ Pid=$process.Id; Session=$sessionPath; Executable=$exe } | ConvertTo-Json
