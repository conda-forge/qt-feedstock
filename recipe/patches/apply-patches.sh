#!/usr/bin/env bash

PATCHES_DIR=$(dirname ${BASH_SOURCE[0]})
declare -a PATCHED_MODULES=()
PATCHED_MODULES+=(qtbase)
# PATCHED_MODULES+=(qtwebengine)

for MODULE in "${PATCHED_MODULES[@]}"; do
  declare -a PATCHES=()
  for PATCH in ${PATCHES_DIR}/00??-${MODULE}-*; do
    PATCHES+=(${PATCH})
  done
  pushd /opt/Shared.local/src/qt5/${MODULE}
    for PATCH in ${PATCHES[@]}; do
      echo "PATCHING ${MODULE} with: ${PATCH}"
    done
    git am -3 "${PATCHES[@]}"
  popd
done
