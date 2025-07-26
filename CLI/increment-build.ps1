$buildFile = "build.txt"
$headerFile = "Source\build.h"

# Crée le fichier s’il n’existe pas
if (-not (Test-Path $buildFile)) {
    Set-Content -Path $buildFile -Value "0"
}

# Lire et valider le contenu
$raw = Get-Content $buildFile
if ($raw -match '^\d+$') {
    $num = [int]$raw
} else {
    $num = 0
}

# Incrémenter
$num++

# Écrire dans le fichier texte
Set-Content -Path $buildFile -Value $num

# Générer le header
$headerContent = @"
#pragma once
#define INLRETRO_CLI_BUILD $num
"@
Set-Content -Path $headerFile -Value $headerContent

Write-Host "Build number updated to $num in $buildFile and $headerFile)"
