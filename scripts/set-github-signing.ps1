param([Parameter(Mandatory=$true)][string]$Repository)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$config = @{}
foreach ($line in Get-Content (Join-Path $projectRoot 'android/key.properties')) {
    if ($line -match '^([^#=]+)=(.*)$') { $config[$matches[1]] = $matches[2] }
}
$keystore = Join-Path (Join-Path $projectRoot 'android') $config.storeFile
$secrets = @{
    ANDROID_KEYSTORE_BASE64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($keystore))
    ANDROID_STORE_PASSWORD = $config.storePassword
    ANDROID_KEY_PASSWORD = $config.keyPassword
    ANDROID_KEY_ALIAS = $config.keyAlias
}
$temporarySecrets = New-TemporaryFile
try {
    $lines = $secrets.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }
    [IO.File]::WriteAllText($temporarySecrets.FullName, ($lines -join "`n"))
    & gh secret set --env-file $temporarySecrets.FullName --repo $Repository
    if ($LASTEXITCODE -ne 0) { throw 'Failed to configure signing secrets.' }
} finally {
    Remove-Item -LiteralPath $temporarySecrets.FullName -Force
}
Write-Host 'GitHub signing secrets configured.'
