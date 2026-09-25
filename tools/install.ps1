<#
.SYNOPSIS
Upload the PPSA99620 title folder to the console over FTP, register it and launch it.

.DESCRIPTION
Requires the console's FTP server (etaHEN, port 2121). Registration and launch use the
PS5Upload engine HTTP API when it is running on this PC; skip them with -NoLaunch and
register the folder from your usual homebrew launcher instead.

.EXAMPLE
./tools/install.ps1 -Src .\dist\PPSA99620 -Console 192.168.1.50
./tools/install.ps1 -Src .\dist\PPSA99620 -Console 192.168.1.50 -EbootOnly
#>
param(
    [Parameter(Mandatory = $true)][string]$Src,
    [Parameter(Mandatory = $true)][string]$Console,
    [int]$FtpPort = 2121,
    [string]$InstallRoot = '/mnt/ext1/etaHEN/games',
    [string]$Engine = 'http://127.0.0.1:19113',
    [switch]$EbootOnly,
    [switch]$NoLaunch
)
$ErrorActionPreference = 'Stop'
$TitleId = 'PPSA99620'
$Src = (Resolve-Path -LiteralPath $Src).ProviderPath
if (-not (Test-Path -LiteralPath (Join-Path $Src 'eboot.bin') -PathType Leaf)) {
    throw "eboot.bin not found in $Src"
}
$base = "ftp://${Console}:${FtpPort}$InstallRoot/$TitleId"

function Send-File([string]$local, [string]$remote) {
    curl.exe -s -S --ftp-create-dirs --connect-timeout 15 -u anonymous: -T $local "$base/$remote"
    if ($LASTEXITCODE -ne 0) { throw "upload failed: $remote" }
}

$json = 'application/json'
if (-not $NoLaunch) {
    # A running title keeps eboot.bin open, which makes the upload fail; stop it first.
    $list = Invoke-RestMethod "$Engine/api/ps5/process/list"
    $running = @($list.processes | Where-Object { $_.title_id -eq $TitleId })
    foreach ($p in $running) {
        Invoke-RestMethod -Method Post "$Engine/api/ps5/process/kill" -ContentType $json `
            -Body (@{ pid = $p.pid } | ConvertTo-Json) | Out-Null
    }
    if ($running) { Start-Sleep -Seconds 3 }
}

if (-not $EbootOnly) {
    Get-ChildItem -Recurse -File -LiteralPath $Src | Where-Object { $_.Name -ne 'eboot.bin' } |
        Sort-Object FullName | ForEach-Object {
            $rel = $_.FullName.Substring($Src.Length).TrimStart('\').Replace('\', '/')
            Send-File $_.FullName $rel
            "uploaded $rel"
        }
}
# eboot.bin last, so a partial upload never leaves a new executable with old data.
Send-File (Join-Path $Src 'eboot.bin') 'eboot.bin'
'uploaded eboot.bin'

if (-not $NoLaunch) {
    Invoke-RestMethod -Method Post "$Engine/api/ps5/app/register" -ContentType $json `
        -Body (@{ src_path = "$InstallRoot/$TitleId" } | ConvertTo-Json) | Out-Null
    Invoke-RestMethod -Method Post "$Engine/api/ps5/app/launch" -ContentType $json `
        -Body (@{ title_id = $TitleId } | ConvertTo-Json) | Out-Null
    "launched $TitleId"
}
