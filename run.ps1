# Lee .env y arranca `flutter run` con las variables como --dart-define.
#
# Uso:
#   .\run.ps1                       # elige dispositivo automaticamente
#   .\run.ps1 -Device emulator-5554 # dispositivo concreto
#   .\run.ps1 -ExtraArgs "-d","chrome","--release"
#
# Formato .env: una VARIABLE=valor por linea. # inicia comentario.
# Valores con espacios pueden ir entre comillas.

[CmdletBinding()]
param(
    [string]$Device = "",
    [string]$EnvFile = ".env",
    [string[]]$ExtraArgs = @()
)

if (-not (Test-Path $EnvFile)) {
    Write-Error "No existe '$EnvFile'. Copia .env.example a .env y rellenalo."
    exit 1
}

$dartDefines = @()
Get-Content $EnvFile | ForEach-Object {
    $line = $_.Trim()
    if ($line -eq "" -or $line.StartsWith("#")) { return }
    $eq = $line.IndexOf("=")
    if ($eq -lt 1) { return }
    $key = $line.Substring(0, $eq).Trim()
    $val = $line.Substring($eq + 1).Trim().Trim('"').Trim("'")
    $dartDefines += "--dart-define=$key=$val"
}

if ($dartDefines.Count -eq 0) {
    Write-Warning "'$EnvFile' esta vacio o solo tiene comentarios."
}

$flutterArgs = @("run")
if ($Device -ne "") { $flutterArgs += @("-d", $Device) }
$flutterArgs += $dartDefines
$flutterArgs += $ExtraArgs

Write-Host "flutter $($flutterArgs -join ' ')" -ForegroundColor DarkGray
& flutter @flutterArgs
