# SPDX-FileCopyrightText: 2026 MSHost contributors
# SPDX-License-Identifier: GPL-3.0-or-later
param(
    [Parameter(Mandatory=$true)][string]$Apk,
    [string]$AndroidSdk = "$env:LOCALAPPDATA\Android\Sdk",
    [string]$JavaHome = 'C:\Program Files\Java\jdk-21.0.12'
)
$ErrorActionPreference = 'Stop'
$env:JAVA_HOME = $JavaHome
$tools = Join-Path $AndroidSdk 'build-tools\36.0.0'
$badging = & "$tools\aapt.exe" dump badging $Apk
if ($LASTEXITCODE) { throw 'aapt badging failed' }
$text = $badging -join "`n"
if ($text -notmatch "package: name='org.mshostcloud.talk' versionCode='250010090' versionName='25.1.0'") {
    throw 'Unexpected package/version metadata'
}
if ($text -notmatch "application-label:'MSHost Talk'") { throw 'Unexpected launcher name' }
if ($text -notmatch "sdkVersion:'26'") { throw 'Unexpected minimum Android version' }
if ($text -match 'application-debuggable') { throw 'Release APK must not allow debugging' }
$manifest = (& "$tools\aapt.exe" dump xmltree $Apk AndroidManifest.xml) -join "`n"
if ($LASTEXITCODE) { throw 'Manifest inspection failed' }
if ($manifest -match 'android:(?:debuggable|testOnly|shell)\([^)]*\)=\(type 0x12\)0xffffffff') {
    throw 'Release APK must not allow debugging, test-only installation or shell profiling'
}
if ($manifest -notmatch 'org.mshostcloud.talk.PRIVATE_BROADCAST') { throw 'Broadcast permission must be isolated' }
if ($manifest -notmatch 'vnd.org.mshostcloud.talk.chat') { throw 'Contact MIME type must be isolated' }
if ($manifest -match 'vnd.com.nextcloud.talk2.chat') { throw 'Original contact MIME type leaked into manifest' }
$resourceTable = (& "$tools\aapt.exe" dump --values resources $Apk) -join "`n"
if ($LASTEXITCODE) { throw 'Resource table inspection failed' }
if ($resourceTable -notmatch ':bool/nc_is_debug:[^\r\n]*\r?\n\s+\(boolean\) false') {
    throw 'Compiled debug feature switch must be false'
}
foreach ($xml in @('auth', 'syncadapter')) {
    $resourcePattern = '(?m)^\s+resource [^\r\n]+:xml/' + $xml + ':[^\r\n]*\r?\n\s+\(string8?\)\s+"([^"]+)"'
    $resourceMatch = [regex]::Match($resourceTable, $resourcePattern)
    if (-not $resourceMatch.Success) { throw "Compiled $xml XML path missing" }
    $xmlDump = (& "$tools\aapt.exe" dump xmltree $Apk $resourceMatch.Groups[1].Value) -join "`n"
    if ($LASTEXITCODE) { throw "Compiled $xml XML inspection failed" }
    if ($xmlDump -notmatch 'org.mshostcloud.talk' -or $xmlDump -match 'com.nextcloud.talk2') {
        throw "Compiled $xml account type must be isolated"
    }
}
$serverEntries = (& "$tools\aapt.exe" dump --values resources $Apk |
    Select-String ':string/weblogin_url:' -Context 0,1) -join "`n"
if ($LASTEXITCODE -or $serverEntries -notmatch 'https://cloud\.mshostcloud\.org') {
    throw 'Default server URL missing from compiled resources'
}
$signature = & "$tools\apksigner.bat" verify --verbose --print-certs $Apk
if ($LASTEXITCODE) { throw 'APK signature verification failed' }
$badging | Select-String 'package:|sdkVersion:|targetSdkVersion:|application-label:|native-code:'
$signature
Write-Output 'APK metadata, isolation and signature checks passed'
