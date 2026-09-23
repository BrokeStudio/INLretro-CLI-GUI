$hostDir = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$outputDir = Join-Path $hostDir "Core\generated"
$headerFile = Join-Path $outputDir "build_info.h"

$gitCommand = Get-Command git -ErrorAction SilentlyContinue
$buildId = "unknown"

if ($gitCommand) {
    $gitHash = (& git -C $hostDir rev-parse --short=8 HEAD 2>$null)

    if ($LASTEXITCODE -eq 0 -and $gitHash) {
        $gitStatus = @(& git -C $hostDir status --porcelain)
        $dirtySuffix = if ($gitStatus.Count -gt 0) { ".dirty" } else { "" }
        $buildId = "g$($gitHash.Trim())$dirtySuffix"
    }
}

$content = "#pragma once`n`n#define INLRETRO_BUILD_ID `"$buildId`"`n"

New-Item -ItemType Directory -Path $outputDir -Force | Out-Null

$currentContent = if (Test-Path $headerFile) {
    [System.IO.File]::ReadAllText($headerFile)
} else {
    ""
}

if ($currentContent -ne $content) {
    [System.IO.File]::WriteAllText(
        $headerFile,
        $content,
        [System.Text.UTF8Encoding]::new($false)
    )
}
