param(
  [ValidateSet('Setup', 'Start', 'Run', 'Test', 'Logs', 'Stop')]
  [string]$Action = 'Run',
  [string]$Serial = 'emulator-5554',
  [switch]$WithAI
)
$ErrorActionPreference = 'Stop'
$mobileRoot = Split-Path -Parent $PSScriptRoot
$avdName = 'Brain10_API_33'
$sdkRoot = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } else { Join-Path $env:LOCALAPPDATA 'Android/Sdk' }
$adb = Join-Path $sdkRoot 'platform-tools/adb.exe'
$emulator = Join-Path $sdkRoot 'emulator/emulator.exe'
$manager = Join-Path $sdkRoot 'cmdline-tools/latest/bin/avdmanager.bat'
$runtimeRoot = Join-Path $mobileRoot '.android-dev'
foreach ($required in @($adb, $emulator, $manager)) {
  if (!(Test-Path -LiteralPath $required)) { throw "Android tool not found: $required" }
}
# Prefer the valid JBR shipped with Android Studio; do not change user-level JAVA_HOME.
foreach ($jbr in @('D:/Android Studio/jbr', 'C:/Program Files/Android/Android Studio/jbr', $env:JAVA_HOME)) {
  if ($jbr -and (Test-Path -LiteralPath (Join-Path $jbr 'bin/java.exe'))) { $env:JAVA_HOME = $jbr; break }
}
New-Item -ItemType Directory -Force -Path $runtimeRoot | Out-Null

function Assert-BrainDevice {
  $name = & $adb -s $Serial emu avd name 2>$null
  if ($LASTEXITCODE -ne 0 -or $name -notcontains $avdName) {
    throw "Device $Serial is not the dedicated Octopus AVD. Refusing to modify another device."
  }
}
function Start-BrainDevice {
  $available = & $emulator -list-avds
  if ($available -notcontains $avdName) {
    $image = Join-Path $sdkRoot 'system-images/android-33/google_apis/x86_64/system.img'
    if (!(Test-Path -LiteralPath $image)) { throw 'Install the Android 13 / Google APIs / x86_64 image in Android Studio first.' }
    'no' | & $manager create avd --name $avdName --package 'system-images;android-33;google_apis;x86_64' --device pixel_6 --path (Join-Path $runtimeRoot "$avdName.avd")
    if ($LASTEXITCODE -ne 0) { throw 'Could not create Octopus AVD.' }
  }
  $devices = & $adb devices
  if (!($devices -match "^$Serial\s+(device|offline)")) {
    Start-Process -FilePath $emulator -ArgumentList '-avd',$avdName,'-port','5554','-gpu','host','-memory','2048','-no-audio','-no-boot-anim' -WindowStyle Normal -RedirectStandardOutput (Join-Path $runtimeRoot 'emulator.log') -RedirectStandardError (Join-Path $runtimeRoot 'emulator-error.log') | Out-Null
  }
  Write-Host 'Waiting for Android to finish booting...'
  $deadline = (Get-Date).AddMinutes(4)
  do {
    $boot = & $adb -s $Serial shell getprop sys.boot_completed 2>$null
    if ($LASTEXITCODE -eq 0 -and $boot -contains '1') { break }
    if ((Get-Date) -gt $deadline) { throw 'Emulator boot timed out. See .android-dev/emulator-error.log.' }
    Start-Sleep -Seconds 2
  } while ($true)
  Assert-BrainDevice
  & $adb -s $Serial shell cmd alarm set-timezone Asia/Ho_Chi_Minh | Out-Null
}

function Enable-LocalAI {
  if (!$WithAI) { return @() }
  $apiRoot = [IO.Path]::GetFullPath((Join-Path $mobileRoot '../api'))
  $ready = $false
  try { $health = Invoke-RestMethod -Uri 'http://127.0.0.1:4180/health' -TimeoutSec 2; $ready = $health.ok -eq $true } catch { }
  if (!$ready) {
    if (!$env:POOL_API_KEY) { throw 'POOL_API_KEY must be set in the server process environment.' }
    if (!(Test-Path -LiteralPath (Join-Path $apiRoot 'node_modules/ajv'))) { throw 'Run npm install inside apps/api first.' }
    Start-Process -FilePath (Get-Command node.exe).Source -ArgumentList 'server.mjs' -WorkingDirectory $apiRoot -WindowStyle Hidden -RedirectStandardOutput (Join-Path $runtimeRoot 'api.log') -RedirectStandardError (Join-Path $runtimeRoot 'api-error.log') | Out-Null
    for ($attempt = 0; $attempt -lt 20; $attempt++) {
      try { $health = Invoke-RestMethod -Uri 'http://127.0.0.1:4180/health' -TimeoutSec 2; if ($health.ok) { $ready = $true; break } } catch { }
      Start-Sleep -Milliseconds 250
    }
  }
  if (!$ready) { throw 'Local planning API did not become ready.' }
  & $adb -s $Serial reverse tcp:4180 tcp:4180 | Out-Null
  if ($LASTEXITCODE -ne 0) { throw 'Could not forward the local planning API to Android.' }
  return @('--dart-define=OCTOPUS_API_URL=http://127.0.0.1:4180')
}

Push-Location $mobileRoot
try {
  switch ($Action) {
    'Stop' { Assert-BrainDevice; & $adb -s $Serial emu kill }
    'Logs' { Assert-BrainDevice; & $adb -s $Serial logcat 'flutter:V' 'AndroidRuntime:E' '*:S' }
    'Setup' { Start-BrainDevice; Write-Host "Ready: $avdName ($Serial). Also available in Android Studio Device Manager." }
    'Start' { Start-BrainDevice }
    'Run' { Start-BrainDevice; $aiArgs = @(Enable-LocalAI); & flutter run -d $Serial -t lib/main.dart @aiArgs }
    'Test' {
      Start-BrainDevice
      $aiArgs = @(Enable-LocalAI)
      $python = (Get-Command python.exe -ErrorAction Stop).Source
      $driver = Start-Process -FilePath $python -ArgumentList 'scripts/picker-automation.py','--serial',$Serial,'--grant-usage','--grant-guard' -WorkingDirectory $mobileRoot -WindowStyle Hidden -RedirectStandardOutput (Join-Path $runtimeRoot 'picker.log') -RedirectStandardError (Join-Path $runtimeRoot 'picker-error.log') -PassThru
      try {
        & flutter test integration_test/app_smoke_test.dart -d $Serial --reporter expanded @aiArgs
        if ($LASTEXITCODE -ne 0) { throw 'Android integration test failed. Check .android-dev/picker-error.log for picker failures.' }
      } finally { if (!$driver.HasExited) { $driver.Kill() } }
      Write-Host 'Integration tests passed. Use Action Run to install the normal app again.'
    }
  }
} finally { Pop-Location }
