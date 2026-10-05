param(
    [ValidateSet('beta', 'production')]
    [string]$Channel = 'beta'
)

$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot

function Invoke-Flutter {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments)

    $flutterCommand = Get-Command flutter -ErrorAction SilentlyContinue
    $flutterExecutable = if ($flutterCommand) {
        $flutterCommand.Source
    } elseif (Test-Path 'E:\DevTools\flutter\bin\flutter.bat') {
        'E:\DevTools\flutter\bin\flutter.bat'
    } else {
        throw 'Flutter no está disponible en PATH ni en E:\DevTools\flutter.'
    }
    & $flutterExecutable @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Flutter falló: flutter $($Arguments -join ' ')"
    }
}

Push-Location $projectRoot
try {
    $environmentFlavor = if ($Channel -eq 'beta') { 'Beta' } else { 'Production' }
    $conductorFlavor = "conductor$environmentFlavor"
    $pasajeroFlavor = "pasajero$environmentFlavor"

    Invoke-Flutter pub get
    Invoke-Flutter analyze
    Invoke-Flutter test
    Invoke-Flutter build apk --debug --flavor $conductorFlavor --target lib/main.dart
    Invoke-Flutter build apk --debug --flavor $pasajeroFlavor --target lib/main_pasajero.dart

    Write-Host ''
    Write-Host "APKs $Channel generados en build/app/outputs/flutter-apk:"
    Get-ChildItem 'build/app/outputs/flutter-apk' -Filter "*$Channel-debug.apk" |
        ForEach-Object { Write-Host "  $($_.FullName)" }
} finally {
    Pop-Location
}
