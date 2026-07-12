param(
    [string]$MpvConfigDir = ""
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($MpvConfigDir)) {
    $MpvConfigDir = Join-Path $env:APPDATA "mpv"
}

$Target = [System.IO.Path]::GetFullPath($MpvConfigDir)
$ScriptTarget = Join-Path $Target "scripts\ddys-mpv.lua"
$ConfigTarget = Join-Path $Target "script-opts\ddys-mpv.conf"

foreach ($file in @($ScriptTarget, $ConfigTarget)) {
    if (Test-Path -LiteralPath $file) {
        Remove-Item -LiteralPath $file -Force
    }
}

[pscustomobject]@{
    ok = $true
    removed = @($ScriptTarget, $ConfigTarget)
} | ConvertTo-Json
