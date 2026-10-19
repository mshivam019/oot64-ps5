param(
    [Parameter(Mandatory=$true)][string]$Src,
    [Parameter(Mandatory=$true)][string]$Console,
    [string]$RemoteDir = '',
    [string]$InstallRoot = '',
    [int]$FtpPort = 2121,
    [string]$FtpUser = 'anonymous',
    [string]$Data = '',
    [switch]$Closed,
    [switch]$ReplaceExisting,
    [switch]$EbootOnly,
    [switch]$NoLaunch,
    [string]$Engine = ''
)
$ErrorActionPreference = 'Stop'
if (-not $RemoteDir -and -not $InstallRoot) {
    throw 'Choose -RemoteDir (full installed title path) or -InstallRoot (loader parent folder). See INSTALL.md; M.2 is optional.'
}
if ($RemoteDir -and $InstallRoot) { throw 'Choose only one destination form.' }
$arguments = @("$PSScriptRoot/install.py", '--src', $Src, '--console', $Console,
               '--ftp-port', $FtpPort, '--ftp-user', $FtpUser)
if ($RemoteDir) { $arguments += @('--remote-dir', $RemoteDir) }
if ($InstallRoot) { $arguments += @('--install-root', $InstallRoot) }
if ($Data) { $arguments += @('--data', $Data) }
if ($Closed) { $arguments += '--closed' }
if ($ReplaceExisting) { $arguments += '--replace-existing' }
if ($EbootOnly) { $arguments += '--eboot-only' }
if (Get-Command py -ErrorAction SilentlyContinue) { & py -3 @arguments }
elseif (Get-Command python -ErrorAction SilentlyContinue) { & python @arguments }
else { throw 'Python 3.9+ is required for this optional helper. You can copy the prepared folder manually instead.' }
if ($LASTEXITCODE -ne 0) { throw 'File transfer stopped; read the error above. No registration/launch was attempted.' }
