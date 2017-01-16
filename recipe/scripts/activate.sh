
if [[ -n "$QMAKESPEC" ]]; then
    export _CONDA_SET_QMAKESPEC=$QMAKESPEC
fi
export QMAKESPEC=unsupported/macx-clang-libc++
