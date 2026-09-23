#!/bin/sh

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
HOST_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
OUTPUT_DIR="$HOST_DIR/Core/generated"
HEADER_FILE="$OUTPUT_DIR/build_info.h"
TEMP_FILE="$HEADER_FILE.tmp"

GIT_HASH=$(git -C "$HOST_DIR" rev-parse --short=8 HEAD 2>/dev/null)

if [ -z "$GIT_HASH" ]; then
    BUILD_ID="unknown"
else
    DIRTY_SUFFIX=""

    if [ -n "$(git -C "$HOST_DIR" status --porcelain)" ]; then
        DIRTY_SUFFIX=".dirty"
    fi

    BUILD_ID="g${GIT_HASH}${DIRTY_SUFFIX}"
fi

mkdir -p "$OUTPUT_DIR"
printf '#pragma once\n\n#define INLRETRO_BUILD_ID "%s"\n' "$BUILD_ID" > "$TEMP_FILE"

if [ -f "$HEADER_FILE" ] && cmp -s "$TEMP_FILE" "$HEADER_FILE"; then
    rm "$TEMP_FILE"
else
    mv "$TEMP_FILE" "$HEADER_FILE"
fi
