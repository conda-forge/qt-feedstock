#!/bin/bash

set -e

cd test
ln -s ${GXX} g++
cp ../xcrun .
cp ../xcodebuild .
export PATH=${PWD}:${PATH}
if [[ -f hello-minimal.pro ]]; then
  qmake hello-minimal.pro
else
  qmake hello.pro
fi
make
./hello
# Only test that this builds
make clean
if [[ -f qtwebengine.pro ]]; then
  qmake qtwebengine.pro
  make
fi
