# SPDX-FileCopyrightText: 2026 MSHost contributors
# SPDX-License-Identifier: GPL-3.0-or-later
param(
    [string]$SigningRoot = 'D:\MSHost\Builds\TalkAndroid\signing',
    [string]$LegacyKey = 'C:\Users\sgord\.android\debug.keystore',
    [string]$JavaHome = 'C:\Program Files\Java\jdk-21.0.12',
    [string]$AndroidSdk = 'C:\Users\sgord\AppData\Local\Android\Sdk'
)
$ErrorActionPreference = 'Stop'
if (Test-Path -LiteralPath $SigningRoot) { throw 'Signing directory already exists; refusing to overwrite keys' }
New-Item -ItemType Directory -Path $SigningRoot | Out-Null
$acl = New-Object System.Security.AccessControl.DirectorySecurity
$acl.SetAccessRuleProtection($true, $false)
$sid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
    $sid, 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow')
$acl.AddAccessRule($rule)
Set-Acl -LiteralPath $SigningRoot -AclObject $acl
Add-Type -AssemblyName System.Security
$random = New-Object byte[] 48
$rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
$rng.GetBytes($random)
$rng.Dispose()
$plain = [System.Text.Encoding]::UTF8.GetBytes([Convert]::ToBase64String($random))
$previousPassword = $env:MSHOST_TALK_SIGNING_PASSWORD
try {
    $env:JAVA_HOME = $JavaHome
    $env:MSHOST_TALK_SIGNING_PASSWORD = [System.Text.Encoding]::UTF8.GetString($plain)
    $protected = [System.Security.Cryptography.ProtectedData]::Protect(
        $plain, $null, [System.Security.Cryptography.DataProtectionScope]::CurrentUser)
    [System.IO.File]::WriteAllBytes((Join-Path $SigningRoot 'password.dpapi'), $protected)
    & "$JavaHome\bin\keytool.exe" -importkeystore -noprompt -srckeystore $LegacyKey `
        -srcstorepass android -srcalias androiddebugkey -srckeypass android `
        -destkeystore (Join-Path $SigningRoot 'legacy.p12') -deststoretype PKCS12 `
        -deststorepass:env MSHOST_TALK_SIGNING_PASSWORD -destkeypass:env MSHOST_TALK_SIGNING_PASSWORD
    if ($LASTEXITCODE) { throw 'Legacy certificate preservation failed' }
    & "$JavaHome\bin\keytool.exe" -genkeypair -noprompt -alias mshost-talk `
        -keyalg RSA -keysize 3072 -validity 10000 -dname 'CN=MSHost Talk, O=MSHost' `
        -keystore (Join-Path $SigningRoot 'release.p12') -storetype PKCS12 `
        -storepass:env MSHOST_TALK_SIGNING_PASSWORD -keypass:env MSHOST_TALK_SIGNING_PASSWORD
    if ($LASTEXITCODE) { throw 'Release signing key generation failed' }
    & "$AndroidSdk\build-tools\36.0.0\apksigner.bat" rotate --out (Join-Path $SigningRoot 'lineage.bin') `
        --old-signer --ks (Join-Path $SigningRoot 'legacy.p12') --ks-key-alias androiddebugkey `
        --ks-pass env:MSHOST_TALK_SIGNING_PASSWORD --key-pass env:MSHOST_TALK_SIGNING_PASSWORD `
        --new-signer --ks (Join-Path $SigningRoot 'release.p12') --ks-key-alias mshost-talk `
        --ks-pass env:MSHOST_TALK_SIGNING_PASSWORD --key-pass env:MSHOST_TALK_SIGNING_PASSWORD
    if ($LASTEXITCODE) { throw 'Certificate lineage generation failed' }
    Write-Output 'Release key and update lineage prepared; private files stay outside source and release archives.'
} finally {
    [Array]::Clear($plain, 0, $plain.Length)
    [Array]::Clear($random, 0, $random.Length)
    $env:MSHOST_TALK_SIGNING_PASSWORD = $previousPassword
}
