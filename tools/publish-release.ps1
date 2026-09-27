<#
.SYNOPSIS
Create a GitHub Release and upload locally built packages with the GitHub CLI.

.DESCRIPTION
Game data stays off GitHub: build with tools/release.sh (without --with-assets)
or tools/release.sh --from-dir, then upload the resulting archive and checksum.
Requires the GitHub CLI (gh) logged in.

.EXAMPLE
./tools/publish-release.ps1 v1.0.0 .\dist\soh-ps5-2160p120-v1.0.0.zip .\dist\soh-ps5-2160p120-v1.0.0.zip.sha256
#>
param(
    [Parameter(Mandatory = $true)][string]$Tag,
    [Parameter(Mandatory = $true, ValueFromRemainingArguments = $true)][string[]]$Files
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot

foreach ($file in $Files) {
    if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { throw "no such file: $file" }
}
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    throw "GitHub CLI (gh) is required: https://cli.github.com"
}

Push-Location $repo
try {
    gh release view $Tag 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Uploading to existing release $Tag"
        gh release upload $Tag @Files --clobber
    } else {
        Write-Host "Creating release $Tag"
        # An empty notes file keeps the description empty on every PowerShell version.
        $notes = New-TemporaryFile
        try { gh release create $Tag @Files --title $Tag --notes-file $notes.FullName }
        finally { Remove-Item -LiteralPath $notes.FullName }
    }
    gh release view $Tag --json url --jq .url
} finally {
    Pop-Location
}
