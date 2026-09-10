$buildFile = "build.txt"
$headerFile = "Source\build.h"

# create file if it doesn't exist
if (-not (Test-Path $buildFile)) {
    "0`n" | Set-Content -Path $buildFile -NoNewline
}

# read and control file content
$raw = (Get-Content $buildFile -Raw).Trim()
if ($raw -match '^\d+$') {
    $num = [int]$raw
} else {
    $num = 0
}

# increment build number
$num++

# write it back to text file
($num.ToString() + "`n") | Set-Content $buildFile -NoNewline

# create header file
("#pragma once`n#define INLRETRO_GUI_BUILD $NUM`n") |
    Set-Content $headerFile -NoNewline

Write-Host "Build number updated to $num in $buildFile and $headerFile)"
