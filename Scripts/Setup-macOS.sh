#!/bin/bash

pushd ..
# Vendor/Binaries/Premake/macOS/premake5 --cc=clang --file=Build.lua gmake2
Vendor/Binaries/Premake/macOS/premake5 --cc=gcc --file=Build.lua gmake2
popd
