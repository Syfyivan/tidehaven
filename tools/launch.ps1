$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$playable = Join-Path $projectRoot 'build\Tidehaven-0.10.1.exe'
if (Test-Path -LiteralPath $playable) {
    Start-Process -FilePath $playable -WorkingDirectory (Split-Path -Parent $playable)
    exit
}
$engines = @(Get-ChildItem -LiteralPath "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Filter '*godot*' -Directory | ForEach-Object {
    Get-ChildItem -LiteralPath $_.FullName -Recurse -Filter 'Godot*.exe' | Where-Object { $_.Name -notlike '*console*' }
})
if ($engines.Count -eq 0) { throw 'No exported game or Godot installation found.' }
Start-Process -FilePath $engines[0].FullName -ArgumentList @('--path', ('"' + $projectRoot + '"')) -WorkingDirectory $projectRoot
