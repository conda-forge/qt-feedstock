#!/bin/bash

cd test
ln -s ${GXX} g++
qmake hello.pro
make
./hello
