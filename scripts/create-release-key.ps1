param([string]$JavaHome = $env:JAVA_HOME)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$signingDir = Join-Path $projectRoot 'android/signing'
$propertiesFile = Join-Path $projectRoot 'android/key.properties'
$keystoreFile = Join-Path $signingDir 'study-release.jks'
if ((Test-Path $propertiesFile) -or (Test-Path $keystoreFile)) {
    throw 'Signing files already exist. Never replace the release key.'
}
$keytool = if ($JavaHome) { Join-Path $JavaHome 'bin/keytool.exe' } else { 'keytool' }
$randomBytes = New-Object byte[] 32
$rng = [Security.Cryptography.RandomNumberGenerator]::Create()
$rng.GetBytes($randomBytes)
$rng.Dispose()
$password = [Convert]::ToBase64String($randomBytes)
$previousPassword = $env:STUDY_KEY_PASSWORD
try {
    New-Item -ItemType Directory -Path $signingDir -Force | Out-Null
    $env:STUDY_KEY_PASSWORD = $password
    & $keytool -genkeypair -v -storetype JKS -keystore $keystoreFile -alias study `
        -keyalg RSA -keysize 3072 -validity 10000 -dname 'CN=Study' `
        -storepass:env STUDY_KEY_PASSWORD -keypass:env STUDY_KEY_PASSWORD
    if ($LASTEXITCODE -ne 0) { throw 'Key generation failed.' }
    $properties = "storeFile=signing/study-release.jks`nstorePassword=$password`nkeyAlias=study`nkeyPassword=$password`n"
    [IO.File]::WriteAllText($propertiesFile, $properties)
    Write-Host 'Created android/signing/study-release.jks and android/key.properties.'
    Write-Host 'Back up both files securely. Keep the same key for every future release.'
} finally {
    $env:STUDY_KEY_PASSWORD = $previousPassword
}
