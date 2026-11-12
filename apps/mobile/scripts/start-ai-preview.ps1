$ErrorActionPreference='Stop'
$mobileRoot=Split-Path -Parent $PSScriptRoot
$apiRoot=[IO.Path]::GetFullPath((Join-Path $mobileRoot '../api'))
$webRoot=[IO.Path]::GetFullPath((Join-Path $mobileRoot '../website'))
$runtimeRoot=Join-Path $mobileRoot '.android-dev'
$userPoolSecret=[Environment]::GetEnvironmentVariable('POOL_API_KEY','User')
if($userPoolSecret){$env:POOL_API_KEY=$userPoolSecret}
if(!$env:POOL_API_KEY){throw 'Set POOL_API_KEY in your user environment first. Do not put it in app code.'}
New-Item -ItemType Directory -Force -Path $runtimeRoot | Out-Null
Push-Location $webRoot
try{& node scripts/prepare-ai-beta.mjs;if($LASTEXITCODE -ne 0){throw 'Could not prepare beta access file.'}}finally{Pop-Location}
foreach($service in @(@{Port=4180;Root=$apiRoot;Name='api';Health='/health'},@{Port=4178;Root=$webRoot;Name='web';Health='/api/plans'})){
  $ready=$false
  try{$response=Invoke-RestMethod -Uri "http://127.0.0.1:$($service.Port)$($service.Health)" -TimeoutSec 2;$ready=($response.ok -eq $true -or $response.configured -eq $true)}catch{}
  if(!$ready){
    $env:PORT=[string]$service.Port
    Start-Process -FilePath (Get-Command node.exe).Source -ArgumentList 'server.mjs' -WorkingDirectory $service.Root -WindowStyle Hidden -RedirectStandardOutput (Join-Path $runtimeRoot "$($service.Name)-ai.log") -RedirectStandardError (Join-Path $runtimeRoot "$($service.Name)-ai-error.log") | Out-Null
  }
}
Write-Host 'Web AI preview: http://127.0.0.1:4178/try/'
Write-Host 'Android Emulator API: http://10.0.2.2:4180'
Write-Host "Beta access file: $(Join-Path $runtimeRoot 'ai-beta-access.txt')"
Write-Host 'AI calls consume credits only when you choose to create a plan.'
