$ErrorActionPreference = 'Stop'

$sdkRoot = Join-Path $env:LOCALAPPDATA 'Android\Sdk'
$adbPath = Join-Path $sdkRoot 'platform-tools\adb.exe'
$emulatorPath = Join-Path $sdkRoot 'emulator\emulator.exe'
$avdName = 'Leiva_API_36'
$packageName = 'com.leivahermanos.leiva_app_interna'
$projectRoot = Split-Path -Parent $PSScriptRoot
$apkPath = Join-Path $projectRoot 'build\app\outputs\flutter-apk\app-debug.apk'

if (-not (Test-Path -LiteralPath $adbPath)) {
    throw "No se encontró ADB en $adbPath"
}

if (-not (Test-Path -LiteralPath $emulatorPath)) {
    throw "No se encontró el emulador de Android en $emulatorPath"
}

function Get-RunningEmulatorId {
    foreach ($line in (& $adbPath devices)) {
        $normalizedLine = $line.Trim()
        if ($normalizedLine -match '^(emulator-\d+)\s+device$') {
            return $Matches[1]
        }
    }
    return $null
}

& $adbPath start-server | Out-Null
$deviceId = Get-RunningEmulatorId

if (-not $deviceId) {
    Write-Host "Iniciando el emulador $avdName..."
    Start-Process -FilePath $emulatorPath -ArgumentList '-avd', $avdName

    for ($attempt = 0; $attempt -lt 90 -and -not $deviceId; $attempt++) {
        Start-Sleep -Seconds 2
        $deviceId = Get-RunningEmulatorId
    }
}

if (-not $deviceId) {
    throw 'El emulador no apareció dentro del tiempo esperado.'
}

Write-Host 'Esperando que Android termine de iniciar...'
$bootCompleted = $false
for ($attempt = 0; $attempt -lt 90; $attempt++) {
    $bootState = (& $adbPath -s $deviceId shell getprop sys.boot_completed 2>$null).Trim()
    if ($bootState -eq '1') {
        $bootCompleted = $true
        break
    }
    Start-Sleep -Seconds 2
}

if (-not $bootCompleted) {
    throw 'Android no terminó de iniciar dentro del tiempo esperado.'
}

& $adbPath -s $deviceId shell ime enable `
    com.google.android.inputmethod.latin/com.android.inputmethod.latin.LatinIME | Out-Null
& $adbPath -s $deviceId shell ime set `
    com.google.android.inputmethod.latin/com.android.inputmethod.latin.LatinIME | Out-Null
& $adbPath -s $deviceId shell settings put secure show_ime_with_hard_keyboard 1

$installedPackage = & $adbPath -s $deviceId shell pm path $packageName 2>$null
if (-not $installedPackage) {
    if (-not (Test-Path -LiteralPath $apkPath)) {
        throw 'La app no está instalada y no existe un APK compilado. Ejecutá primero flutter build apk --debug.'
    }
    Write-Host 'Instalando Leiva Interna...'
    & $adbPath -s $deviceId install -r $apkPath | Out-Null
}

Write-Host 'Abriendo Leiva Interna...'
& $adbPath -s $deviceId shell am force-stop $packageName
& $adbPath -s $deviceId shell monkey -p $packageName `
    -c android.intent.category.LAUNCHER 1 | Out-Null
Start-Sleep -Seconds 3

$appPid = (& $adbPath -s $deviceId shell pidof $packageName).Trim()
if (-not $appPid) {
    throw 'Android inició, pero Leiva Interna no pudo abrirse.'
}

# Android 16 puede abrir Gboard en su barra manuscrita compacta. Si la app está
# en el login, enfocamos Usuario y usamos el atajo oficial "Mostrar teclado en
# pantalla" para dejar el QWERTY visible. No se ejecuta dentro del dashboard.
$uiDumpPath = '/sdcard/leiva-app-window.xml'
& $adbPath -s $deviceId shell uiautomator dump $uiDumpPath | Out-Null
$uiDump = (& $adbPath -s $deviceId shell cat $uiDumpPath) -join "`n"
& $adbPath -s $deviceId shell rm $uiDumpPath
if ($uiDump -match 'hint="nombre\.apellido"') {
    & $adbPath -s $deviceId shell input tap 360 880
    Start-Sleep -Seconds 1
    & $adbPath -s $deviceId shell input keycombination 57 39
    Start-Sleep -Seconds 1
}

Write-Host 'Leiva Interna está lista.' -ForegroundColor Green
