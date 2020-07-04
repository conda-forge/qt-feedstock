#!/bin/bash

set -e

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
if [[ -f qtwebengine.pro ]]; then
  qmake qtwebengine.pro
  make
fi
