#!/bin/bash

set -ex

cd test
ln -s ${GXX} g++
cp ../xcrun .
cp ../xcodebuild .
export PATH=${PWD}:${PATH}
qmake hello.pro
make
./hello
# Only test that this builds
make clean

if [[ $target_platform != "linux-ppc64le" ]]; then
    qmake qtwebengine.pro
    make
fi
