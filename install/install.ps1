param(
    [string]$MpvConfigDir = "",
    [switch]$Force
)

$ErrorActionPreference = "Stop"

$Root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
if ([string]::IsNullOrWhiteSpace($MpvConfigDir)) {
    $MpvConfigDir = Join-Path $env:APPDATA "mpv"
}

$Target = [System.IO.Path]::GetFullPath($MpvConfigDir)
$ScriptsDir = Join-Path $Target "scripts"
$OptsDir = Join-Path $Target "script-opts"

New-Item -ItemType Directory -Force -Path $ScriptsDir | Out-Null
New-Item -ItemType Directory -Force -Path $OptsDir | Out-Null

$ScriptSource = Join-Path $Root "scripts\ddys-mpv.lua"
$ConfigSource = Join-Path $Root "script-opts\ddys-mpv.conf"
$ScriptTarget = Join-Path $ScriptsDir "ddys-mpv.lua"
$ConfigTarget = Join-Path $OptsDir "ddys-mpv.conf"

Copy-Item -LiteralPath $ScriptSource -Destination $ScriptTarget -Force
if ((-not (Test-Path -LiteralPath $ConfigTarget)) -or $Force) {
    Copy-Item -LiteralPath $ConfigSource -Destination $ConfigTarget -Force
}

[pscustomobject]@{
    ok = $true
    mpvConfigDir = $Target
    script = $ScriptTarget
    config = $ConfigTarget
    configOverwritten = [bool]$Force
} | ConvertTo-Json
