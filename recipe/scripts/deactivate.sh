#!/bin/bash

unset QMAKESPEC
if [[ -n "$_CONDA_SET_QMAKESPEC" ]]; then
    export QMAKESPEC=$_CONDA_SET_QMAKESPEC
    unset _CONDA_SET_QMAKESPEC
fi
