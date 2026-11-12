$ErrorActionPreference='Stop'
$mobileRoot=Split-Path -Parent $PSScriptRoot
& (Join-Path $PSScriptRoot 'android-dev.ps1') -Action Start
$env:JAVA_HOME='D:/Android Studio/jbr'
$adb=Join-Path $env:LOCALAPPDATA 'Android/Sdk/platform-tools/adb.exe'
$name=& $adb -s emulator-5554 emu avd name
if ($name -notcontains 'Brain10_API_33') { throw 'Dedicated AVD required' }
& $adb -s emulator-5554 shell run-as vn.octopus.mobile rm -f code_cache/octopus-guard-phase code_cache/octopus-guard-ack 2>$null
Push-Location $mobileRoot
try {
  $driver=Start-Process -FilePath (Get-Command python.exe).Source -ArgumentList 'scripts/widget-automation.py' -WorkingDirectory $mobileRoot -WindowStyle Hidden -RedirectStandardOutput '.android-dev/widget-driver.log' -RedirectStandardError '.android-dev/widget-driver-error.log' -PassThru
  try {
    & flutter test integration_test/widget_flow_test.dart -d emulator-5554 --reporter expanded
    if ($LASTEXITCODE -ne 0) { throw 'Widget integration failed' }
  } finally { if (!$driver.HasExited) {$driver.Kill()} }
} finally {Pop-Location}
