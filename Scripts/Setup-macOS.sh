#!/bin/bash

pushd ..
# Vendor/Binaries/Premake/Linux/premake5 --cc=clang --file=Build.lua gmake2
Vendor/Binaries/Premake/macOS/premake5 --cc=g++ --file=Build.lua gmake2
popd
