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
    git am -3 -p2 "${PATCHES[@]}"
  popd
done

# Regen via e.g.:
# git am -3 -p5 ../../../../../../r/a.wip/qt-feedstock/recipe/patches/0005-qtwebengine-jpeg-codec-cannot-convert-bool-to-boolean.patch
# git format-patch --src-prefix=a/qtwebengine/ --dst-prefix=b/qtwebengine/ -1
# git format-patch --start-number=9 --src-prefix=a/qtwebengine/3rdparty/chromium/ --dst-prefix=b/qtwebengine/3rdparty/chromium/ -1
