param([ValidateSet('guard_test.dart', 'vpn_probe_test.dart')][string]$TestFile = 'guard_test.dart')
$ErrorActionPreference = 'Stop'
$mobileRoot = Split-Path -Parent $PSScriptRoot
& (Join-Path $PSScriptRoot 'android-dev.ps1') -Action Start
$env:JAVA_HOME = 'D:/Android Studio/jbr'
$adb = Join-Path $env:LOCALAPPDATA 'Android/Sdk/platform-tools/adb.exe'
$name = & $adb -s emulator-5554 emu avd name
if ($name -notcontains 'Octopus_API_33') { throw 'Dedicated Octopus AVD required.' }
# Only test markers, never application data. A fresh test install may not exist yet.
& $adb -s emulator-5554 shell run-as vn.octopus.mobile rm -f code_cache/octopus-guard-phase code_cache/octopus-guard-ack code_cache/octopus-guard-result.json 2>$null
Push-Location $mobileRoot
try {
  $driver = Start-Process -FilePath (Get-Command python.exe).Source -ArgumentList 'scripts/guard-automation.py' -WorkingDirectory $mobileRoot -WindowStyle Hidden -RedirectStandardOutput '.android-dev/guard-driver.log' -RedirectStandardError '.android-dev/guard-driver-error.log' -PassThru
  try {
    & flutter test "integration_test/$TestFile" -d emulator-5554 --reporter expanded
    if ($LASTEXITCODE -ne 0) { throw 'Native guard suite failed. Inspect guard-driver logs and test-results/guard.' }
  } finally { if (!$driver.HasExited) { $driver.Kill() } }
} finally { Pop-Location }
