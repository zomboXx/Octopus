param([switch]$WithAI,[string]$ApiUrl=$env:OCTOPUS_API_URL)
$ErrorActionPreference='Stop'
if ($WithAI -and !$ApiUrl) { throw 'Specify -ApiUrl or set OCTOPUS_API_URL.' }
$mobileRoot=Split-Path -Parent $PSScriptRoot
foreach ($jbr in @('D:/Android Studio/jbr', 'C:/Program Files/Android/Android Studio/jbr', $env:JAVA_HOME)) {
  if ($jbr -and (Test-Path -LiteralPath (Join-Path $jbr 'bin/java.exe'))) { $env:JAVA_HOME = $jbr; break }
}
Push-Location $mobileRoot
try {
  $aiArgs = @(if ($WithAI) { "--dart-define=OCTOPUS_API_URL=$ApiUrl" })
  & flutter build apk --debug --target-platform android-arm,android-arm64,android-x64 @aiArgs
  if ($LASTEXITCODE -ne 0) { throw 'APK build failed.' }
  $source=Join-Path $mobileRoot 'build/app/outputs/flutter-apk/app-debug.apk'
  $artifacts=Join-Path $mobileRoot 'artifacts'
  New-Item -ItemType Directory -Force -Path $artifacts | Out-Null
  $destination=Join-Path $artifacts 'octopus-android-debug.apk'
  Copy-Item -LiteralPath $source -Destination $destination -Force
  $versionLine=Get-Content -LiteralPath 'pubspec.yaml' | Where-Object { $_ -match '^version:' } | Select-Object -First 1
  $version=($versionLine -replace '^version:\s*','').Split('+')[0]
  $versionedFile="octopus-$version-android-debug.apk"
  Copy-Item -LiteralPath $destination -Destination (Join-Path $artifacts $versionedFile) -Force
  $metadata=@{aiMode=$(if ($WithAI -and $ApiUrl.StartsWith('http:')) {'emulator-local-backend'} elseif ($WithAI) {'public-beta-backend'} else {'disabled'});version=$version;bytes=(Get-Item -LiteralPath $destination).Length;sha256=(Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash;abis=@('armeabi-v7a','arm64-v8a','x86_64')}
  $metadata | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $artifacts 'build.json') -Encoding utf8
  Write-Host "Stable APK: $destination"
  Write-Host "Versioned APK: $(Join-Path $artifacts $versionedFile)"
  $metadata | ConvertTo-Json
} finally { Pop-Location }
