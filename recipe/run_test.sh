#!/bin/bash

cd test
ln -s ${GXX} g++
export PATH=${PWD}:${PATH}
qmake hello.pro
make
./hello
