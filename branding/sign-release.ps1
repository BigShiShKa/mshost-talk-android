# SPDX-FileCopyrightText: 2026 MSHost contributors
# SPDX-License-Identifier: GPL-3.0-or-later
param(
    [Parameter(Mandatory=$true)][string]$UnsignedApk,
    [Parameter(Mandatory=$true)][string]$SignedApk,
    [string]$SigningRoot = 'D:\MSHost\Builds\TalkAndroid\signing',
    [string]$AndroidSdk = 'C:\Users\sgord\AppData\Local\Android\Sdk'
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Security
$encrypted = [System.IO.File]::ReadAllBytes((Join-Path $SigningRoot 'password.dpapi'))
$plain = [System.Security.Cryptography.ProtectedData]::Unprotect(
    $encrypted, $null, [System.Security.Cryptography.DataProtectionScope]::CurrentUser)
$previousPassword = $env:MSHOST_TALK_SIGNING_PASSWORD
try {
    $env:MSHOST_TALK_SIGNING_PASSWORD = [System.Text.Encoding]::UTF8.GetString($plain)
    & "$AndroidSdk\build-tools\36.0.0\apksigner.bat" sign `
        --ks (Join-Path $SigningRoot 'legacy.p12') --ks-key-alias androiddebugkey `
        --ks-pass env:MSHOST_TALK_SIGNING_PASSWORD --key-pass env:MSHOST_TALK_SIGNING_PASSWORD `
        --next-signer --ks (Join-Path $SigningRoot 'release.p12') --ks-key-alias mshost-talk `
        --ks-pass env:MSHOST_TALK_SIGNING_PASSWORD --key-pass env:MSHOST_TALK_SIGNING_PASSWORD `
        --lineage (Join-Path $SigningRoot 'lineage.bin') --rotation-min-sdk-version 28 `
        --out $SignedApk $UnsignedApk
    if ($LASTEXITCODE) { throw 'APK signing with certificate lineage failed' }
} finally {
    [Array]::Clear($plain, 0, $plain.Length)
    $env:MSHOST_TALK_SIGNING_PASSWORD = $previousPassword
}
