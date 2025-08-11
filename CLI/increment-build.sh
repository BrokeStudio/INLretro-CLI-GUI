#!/bin/sh

BUILD_FILE="build.txt"
HEADER_FILE="Source/build.h"

# Crée le fichier s'il n'existe pas
if [ ! -f "$BUILD_FILE" ]; then
    echo "0" > "$BUILD_FILE"
fi

# Lire et valider le contenu
RAW=$(cat "$BUILD_FILE")
if echo "$RAW" | grep -qE '^[0-9]+$'; then
    NUM=$RAW
else
    NUM=0
fi

# Incrémenter
NUM=$((NUM + 1))

# Écrire dans le fichier texte
echo "$NUM" > "$BUILD_FILE"

# Générer le header C++
echo "#pragma once" > "$HEADER_FILE"
echo "#define INLRETRO_CLI_BUILD $NUM" >> "$HEADER_FILE"

echo "Build number updated to $NUM in $BUILD_FILE and $HEADER_FILE)"
