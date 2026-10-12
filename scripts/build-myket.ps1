param([int]$BuildNumber = 0, [switch]$SkipChecks, [switch]$UseWindowsCertificates, [switch]$Offline)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
Push-Location $projectRoot
$previousPub = $env:PUB_HOSTED_URL
$previousStorage = $env:FLUTTER_STORAGE_BASE_URL
$previousInit = $env:STUDY_GRADLE_INIT
$previousJavaOptions = $env:JAVA_TOOL_OPTIONS
$previousOffline = $env:STUDY_GRADLE_OFFLINE
$previousWrapper = $env:STUDY_GRADLE_WRAPPER
try {
    if (!(Test-Path 'android/key.properties')) {
        throw 'Create or restore release signing first; see docs/BUILD_FA.md.'
    }
    $env:PUB_HOSTED_URL = 'https://pub.myket.ir'
    $env:FLUTTER_STORAGE_BASE_URL = 'https://pub.myket.ir'
    $env:STUDY_GRADLE_INIT = Join-Path $PSScriptRoot 'myket.init.gradle'
    # Keep tracked wrapper settings official. A separate local wrapper uses Myket.
    $wrapperDir = Join-Path $projectRoot 'build/myket-wrapper/gradle/wrapper'
    New-Item -ItemType Directory -Path $wrapperDir -Force | Out-Null
    $wrapperJar = Join-Path $wrapperDir 'gradle-wrapper.jar'
    Copy-Item -LiteralPath 'android/gradle/wrapper/gradle-wrapper.jar' -Destination $wrapperJar -Force
    $wrapperProperties = [IO.File]::ReadAllText((Join-Path $projectRoot 'android/gradle/wrapper/gradle-wrapper.properties'))
    $wrapperProperties = $wrapperProperties.Replace('https\://services.gradle.org/distributions/', 'https\://maven.myket.ir/gradle/distributions/')
    [IO.File]::WriteAllText((Join-Path $wrapperDir 'gradle-wrapper.properties'), $wrapperProperties)
    $env:STUDY_GRADLE_WRAPPER = $wrapperJar
    if ($UseWindowsCertificates) {
        $env:JAVA_TOOL_OPTIONS = "$previousJavaOptions -Djavax.net.ssl.trustStoreType=Windows-ROOT -Djavax.net.ssl.trustStore=NONE".Trim()
    }
    if ($Offline) {
        $env:STUDY_GRADLE_OFFLINE = '1'
        & flutter pub get --offline
    } else {
        $env:STUDY_GRADLE_OFFLINE = $null
        & flutter pub get
    }
    if ($LASTEXITCODE -ne 0) { throw 'Dependency download failed.' }
    & flutter gen-l10n
    if ($LASTEXITCODE -ne 0) { throw 'Localization generation failed.' }
    if (!$SkipChecks) {
        & flutter analyze
        if ($LASTEXITCODE -ne 0) { throw 'Analysis failed.' }
        & flutter test
        if ($LASTEXITCODE -ne 0) { throw 'Tests failed.' }
    }
    $buildArgs = @('build', 'apk', '--release')
    if ($BuildNumber -le 0) {
        $BuildNumber = [int]([DateTimeOffset]::UtcNow.ToUnixTimeSeconds() - 1577836800)
    }
    $buildArgs += @('--build-number', "$BuildNumber")
    & flutter @buildArgs
    if ($LASTEXITCODE -ne 0) { throw 'APK build failed.' }
    Write-Host 'APK: build/app/outputs/flutter-apk/app-release.apk'
} finally {
    # Commit a lockfile with official package URLs for GitHub; preserve versions/hashes.
    $lockPath = Join-Path $projectRoot 'pubspec.lock'
    if (Test-Path $lockPath) {
        $lockContent = [IO.File]::ReadAllText($lockPath)
        [IO.File]::WriteAllText($lockPath, $lockContent.Replace('https://pub.myket.ir', 'https://pub.dev'))
    }
    $env:PUB_HOSTED_URL = $previousPub
    $env:FLUTTER_STORAGE_BASE_URL = $previousStorage
    $env:STUDY_GRADLE_INIT = $previousInit
    $env:JAVA_TOOL_OPTIONS = $previousJavaOptions
    $env:STUDY_GRADLE_OFFLINE = $previousOffline
    $env:STUDY_GRADLE_WRAPPER = $previousWrapper
    Pop-Location
}
