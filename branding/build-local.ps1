# SPDX-FileCopyrightText: 2026 MSHost contributors
# SPDX-License-Identifier: GPL-3.0-or-later
param(
    [string]$JavaHome = 'C:\Program Files\Java\jdk-21.0.12',
    [string]$AndroidSdk = "$env:LOCALAPPDATA\Android\Sdk",
    [switch]$Checks
)
$ErrorActionPreference = 'Stop'
$sourceRoot = Split-Path $PSScriptRoot -Parent
$env:JAVA_HOME = $JavaHome
$env:ANDROID_HOME = $AndroidSdk
Push-Location $sourceRoot
try {
    & "$PSScriptRoot\prepare-assets.ps1"
    python branding/test_branding.py
    if ($LASTEXITCODE) { throw 'Branding contract checks failed' }
    $tasks = @(':app:assembleGenericRelease')
    if ($Checks) { $tasks += @('detekt', 'ktlintCheck') }
    $ErrorActionPreference = 'Continue'
    & "$JavaHome\bin\java.exe" '-Djava.net.preferIPv4Stack=true' `
        '-Dorg.gradle.internal.http.socketTimeout=30000' '-Dorg.gradle.internal.http.connectionTimeout=30000' `
        -jar gradle/wrapper/gradle-wrapper.jar @tasks -PmshostMavenMirror=true `
        --console=plain --no-configuration-cache --max-workers=2
    $buildExit = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    if ($buildExit) { throw "Gradle build failed: $buildExit" }
    $apkDir = Join-Path $sourceRoot 'app\build\outputs\apk\generic\release'
    $metadata = Get-Content (Join-Path $apkDir 'output-metadata.json') -Raw | ConvertFrom-Json
    $unsignedApk = Join-Path $apkDir $metadata.elements[0].outputFile
    $signedApk = $unsignedApk.Replace('-unsigned.apk', '.apk')
    & "$PSScriptRoot\sign-release.ps1" -UnsignedApk $unsignedApk -SignedApk $signedApk -AndroidSdk $AndroidSdk
    & "$PSScriptRoot\verify-apk.ps1" -Apk $signedApk `
        -AndroidSdk $AndroidSdk -JavaHome $JavaHome
    python branding/check-startup-toast.py $signedApk
    if ($LASTEXITCODE) { throw 'Startup toast regression check failed' }
    python branding/verify-release.py $signedApk
    if ($LASTEXITCODE) { throw 'Release feature verification failed' }
    python branding/export-release.py
    if ($LASTEXITCODE) { throw 'Release export failed' }
} finally { Pop-Location }
exit 0
