param(
    [Parameter(Mandatory = $true)]
    [string]$ArchivePath,
    [string]$ProjectPath = (Split-Path -Parent $PSScriptRoot)
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem

# Import only the two reviewed images, without extracting arbitrary ZIP paths.
$projectRoot = (Resolve-Path -LiteralPath $ProjectPath).Path
if (-not (Test-Path -LiteralPath (Join-Path $projectRoot 'project.godot') -PathType Leaf)) {
    throw 'ProjectPath must be a Tidehaven project directory.'
}
$archiveFile = (Resolve-Path -LiteralPath $ArchivePath).Path
$required = @(
    @{ Source = 'Male/Male 02-1.png'; File = 'Male-02-1.png'; Hash = '01EA45B6EF95596A64FD24A7325EE3E113ADC0519FBE56AB4B9AD46318DA20A4' },
    @{ Source = 'Female/Female 02-1.png'; File = 'Female-02-1.png'; Hash = '2DEF5256B265E18A3185CEC887238A113607EED6958FE2F8F4151312E02333E3' }
)
$destination = Join-Path $projectRoot 'assets/vendor/pipoya'
$pending = @()
$archive = [IO.Compression.ZipFile]::OpenRead($archiveFile)
try {
    foreach ($item in $required) {
        $matches = @($archive.Entries | Where-Object {
            $entryName = $_.FullName.Replace('\', '/')
            $entryName -eq $item.Source -or $entryName.EndsWith('/' + $item.Source, [StringComparison]::Ordinal)
        })
        if ($matches.Count -ne 1 -or $matches[0].Length -gt 1MB) {
            throw ('Expected exactly one small character image: ' + $item.Source)
        }
        $stream = $matches[0].Open()
        $memory = [IO.MemoryStream]::new()
        try { $stream.CopyTo($memory); $bytes = $memory.ToArray() }
        finally { $stream.Dispose(); $memory.Dispose() }
        $hasher = [Security.Cryptography.SHA256]::Create()
        try { $hash = [BitConverter]::ToString($hasher.ComputeHash($bytes)).Replace('-', '') }
        finally { $hasher.Dispose() }
        if ($hash -ne $item.Hash) { throw ('Unreviewed character image; original pack may have changed: ' + $item.File) }
        $target = Join-Path $destination $item.File
        if ((Test-Path -LiteralPath $target) -and (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash -ne $item.Hash) {
            throw ('Preserving an existing modified image; back it up before replacing: ' + $target)
        }
        $pending += @{ Target = $target; Bytes = $bytes }
    }
} finally { $archive.Dispose() }

# Validate both files before writing either one. Existing matching files are kept.
New-Item -ItemType Directory -Path $destination -Force | Out-Null
foreach ($item in $pending) {
    if (-not (Test-Path -LiteralPath $item.Target)) { [IO.File]::WriteAllBytes($item.Target, $item.Bytes) }
}
Write-Output 'PIPOYA characters restored and SHA256 verified. Raw images remain Git-ignored.'
