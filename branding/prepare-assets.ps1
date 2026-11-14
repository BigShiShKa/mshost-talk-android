# SPDX-FileCopyrightText: 2026 MSHost contributors
# SPDX-License-Identifier: GPL-3.0-or-later
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$res = Join-Path (Split-Path $PSScriptRoot -Parent) 'app\src\generic\res'
$source = [Drawing.Image]::FromFile((Join-Path $PSScriptRoot 'talk-logo-mt.png'))
function Write-Logo([string]$Target, [int]$Size, [double]$Scale) {
    New-Item -ItemType Directory -Path (Split-Path $Target -Parent) -Force | Out-Null
    $bitmap = New-Object Drawing.Bitmap($Size, $Size, ([Drawing.Imaging.PixelFormat]::Format32bppArgb))
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    try {
        $graphics.Clear([Drawing.Color]::Transparent)
        $graphics.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $width = [int]($Size * $Scale)
        $height = [int]($width * $source.Height / $source.Width)
        $graphics.DrawImage($source, [int](($Size-$width)/2), [int](($Size-$height)/2), $width, $height)
        $bitmap.Save($Target, [Drawing.Imaging.ImageFormat]::Png)
    } finally { $graphics.Dispose(); $bitmap.Dispose() }
}
try {
    foreach ($entry in @{mdpi=48;hdpi=72;xhdpi=96;xxhdpi=144;xxxhdpi=192}.GetEnumerator()) {
        Write-Logo (Join-Path $res "mipmap-$($entry.Key)\ic_launcher.png") $entry.Value 0.82
    }
    Write-Logo (Join-Path $res 'drawable-nodpi\mshost_logo.png') 512 0.92
    Write-Logo (Join-Path $res 'drawable-nodpi\mshost_launcher_foreground.png') 432 0.58
} finally { $source.Dispose() }
