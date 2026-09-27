<#
.SYNOPSIS
Create oot.o2r from your own Ocarina of Time ROM with the official Ship of
Harkinian Windows build, and drop it into the PS5 title folder.

.DESCRIPTION
The PS5 port cannot read a ROM, so oot.o2r has to be extracted on a PC. This
script uses the official Ship of Harkinian build (the same version as the port,
9.2.3) to do that, so no Linux and no compiling are needed.

Download the Ship of Harkinian 9.2.3 Windows build from
https://github.com/HarbourMasters/Shipwright/releases and extract it first.

.EXAMPLE
./tools/make-assets.ps1 -Rom C:\dump\oot.z64 -SoH .\soh-windows -Title .\PPSA99620

.EXAMPLE
# oot.o2r already exists next to soh.exe; just copy it.
./tools/make-assets.ps1 -Rom .\oot.z64 -SoH .\soh-windows -Title .\PPSA99620 -SkipRun
#>
param(
    [Parameter(Mandatory = $true)][string]$Rom,
    [string]$Title,
    [string]$SoH,
    [string]$SoHExe,
    [switch]$SkipRun,
    [int]$TimeoutSec = 900
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot

function Resolve-FullPath([string]$Path) {
    return (Resolve-Path -LiteralPath $Path).ProviderPath
}

if (-not (Test-Path -LiteralPath $Rom -PathType Leaf)) { throw "ROM not found: $Rom" }
$Rom = Resolve-FullPath $Rom

if (-not $Title) {
    $candidate = Join-Path $root 'output\PPSA99620'
    if (Test-Path -LiteralPath (Join-Path $candidate 'eboot.bin')) { $Title = $candidate }
}
if (-not $Title) {
    $found = Get-ChildItem -Path $root -Filter eboot.bin -Recurse -Depth 3 -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Directory.Name -eq 'PPSA99620' } | Select-Object -First 1
    if ($found) { $Title = $found.Directory.FullName }
}
if (-not $Title -or -not (Test-Path -LiteralPath (Join-Path $Title 'eboot.bin'))) {
    throw "Title folder not found (pass -Title pointing at the PPSA99620 folder)."
}
$Title = Resolve-FullPath $Title

if (-not $SoHExe) {
    $roots = @()
    if ($SoH) { $roots += $SoH }
    $roots += @('.\soh-windows', '.', '..')
    foreach ($dir in $roots) {
        $exe = Join-Path $dir 'soh.exe'
        if (Test-Path -LiteralPath $exe -PathType Leaf) { $SoHExe = $exe; break }
    }
}
if (-not $SoHExe -or -not (Test-Path -LiteralPath $SoHExe -PathType Leaf)) {
    throw "soh.exe not found. Pass -SoH <extracted Ship of Harkinian 9.2.3 folder> or -SoHExe <path to soh.exe>."
}
$SoHExe = Resolve-FullPath $SoHExe
$sohDir = Split-Path -Parent $SoHExe
$o2r = Join-Path $sohDir 'oot.o2r'

Write-Host "ROM:    $Rom"
Write-Host "soh:    $SoHExe"
Write-Host "title:  $Title"
Write-Host ""

if (-not (Test-Path -LiteralPath $o2r -PathType Leaf)) {
    if ($SkipRun) { throw "oot.o2r not found next to soh.exe and -SkipRun was given." }
    # Ship of Harkinian looks for ROMs in its own folder, so put a copy there.
    $romCopy = Join-Path $sohDir (Split-Path -Leaf $Rom)
    $copied = $false
    if (-not (Test-Path -LiteralPath $romCopy -PathType Leaf)) {
        Copy-Item -LiteralPath $Rom -Destination $romCopy
        $copied = $true
    }
    Write-Host "Launching Ship of Harkinian to extract oot.o2r from your ROM."
    Write-Host "Follow its prompts (it may ask to extract assets and about Master Quest),"
    Write-Host "then this script continues automatically. Close the game once it starts."
    try {
        $proc = Start-Process -FilePath $SoHExe -WorkingDirectory $sohDir -PassThru
        $deadline = (Get-Date).AddSeconds($TimeoutSec)
        while (-not (Test-Path -LiteralPath $o2r -PathType Leaf) -and (Get-Date) -lt $deadline) {
            if ($proc.HasExited) {
                throw ("Ship of Harkinian closed before creating oot.o2r. If it said it is running " +
                    "from a temporary folder, extract its zip to a normal folder (for example " +
                    "Documents\soh-windows) and pass that folder with -SoH.")
            }
            Start-Sleep -Seconds 2
        }
        # The archive appears as soon as extraction starts; wait until SoH has
        # finished writing it (it can then be opened without sharing).
        while ((Test-Path -LiteralPath $o2r -PathType Leaf) -and (Get-Date) -lt $deadline) {
            try {
                [System.IO.File]::Open($o2r, 'Open', 'Read', 'None').Close()
                $before = (Get-Item -LiteralPath $o2r).Length
                Start-Sleep -Seconds 3
                if ((Get-Item -LiteralPath $o2r).Length -eq $before) { break }
            } catch {
                Start-Sleep -Seconds 2
            }
        }
    } finally {
        if ($copied) { Remove-Item -LiteralPath $romCopy -ErrorAction SilentlyContinue }
    }
}

if (-not (Test-Path -LiteralPath $o2r -PathType Leaf)) {
    throw "oot.o2r was not created within $TimeoutSec seconds. Finish the extraction in Ship of Harkinian and re-run this script."
}

$stream = [System.IO.File]::OpenRead($o2r)
$magic = New-Object byte[] 4
$stream.Read($magic, 0, 4) | Out-Null
$stream.Close()
if ($magic[0] -ne 0x50 -or $magic[1] -ne 0x4b) { throw "oot.o2r does not look like a valid archive: $o2r" }
Add-Type -AssemblyName System.IO.Compression.FileSystem
try {
    $zip = [System.IO.Compression.ZipFile]::OpenRead($o2r)
    $entries = $zip.Entries.Count
    $zip.Dispose()
} catch {
    throw "oot.o2r is incomplete or corrupt ($o2r). Delete it and run this script again."
}
Write-Host "oot.o2r: $entries entries"

$assets = Join-Path $Title 'assets'
if (-not (Test-Path -LiteralPath $assets)) { New-Item -ItemType Directory -Path $assets | Out-Null }
Copy-Item -LiteralPath $o2r -Destination (Join-Path $assets 'oot.o2r') -Force

Write-Host ""
Write-Host "Copied oot.o2r into $assets"
$missing = @()
foreach ($name in @('soh.o2r', 'gamecontrollerdb.txt')) {
    if (-not (Test-Path -LiteralPath (Join-Path $assets $name))) { $missing += $name }
}
if ($missing.Count) { Write-Warning "Title assets folder is missing: $($missing -join ', ')" }
Write-Host "Next: upload the title to the console with tools\install.ps1."
