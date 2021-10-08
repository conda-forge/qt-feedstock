#!/bin/bash

set -e

ls
cd test
ln -s ${GXX} g++
export PATH=${PWD}:${PATH}
qmake hello.pro
make
./hello
# Only test that this builds
make clean
