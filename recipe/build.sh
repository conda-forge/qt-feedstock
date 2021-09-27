set -exou

# Compile
# -------
chmod +x configure

# Clean config for dirty builds
# -----------------------------
if [[ -d qt-build ]]; then
  rm -rf qt-build
fi

mkdir qt-build
pushd qt-build

echo PREFIX=${PREFIX}
echo BUILD_PREFIX=${BUILD_PREFIX}
USED_BUILD_PREFIX=${BUILD_PREFIX:-${PREFIX}}
echo USED_BUILD_PREFIX=${BUILD_PREFIX}

MAKE_JOBS=$CPU_COUNT
export NINJAFLAGS="-j${MAKE_JOBS}"

# For QDoc
export LLVM_INSTALL_DIR=${USED_BUILD_PREFIX}

# Remove the full path from CXX etc. If we don't do this
# then the full path at build time gets put into
# mkspecs/qmodule.pri and qmake attempts to use this.
export AR=$(basename ${AR})
export RANLIB=$(basename ${RANLIB})
export STRIP=$(basename ${STRIP})
export OBJDUMP=$(basename ${OBJDUMP})
export CC=$(basename ${CC})
export CXX=$(basename ${CXX})

# Let Qt set its own flags and vars
for x in OSX_ARCH CFLAGS CXXFLAGS LDFLAGS
do
    unset $x
done

# You can use this to cut down on the number of modules built. Of course the Qt package will not be of
# much use, but it is useful if you are iterating on e.g. figuring out compiler flags to reduce the
# size of the libraries.
MINIMAL_BUILD=no

# Remove protobuf which is pulled in indirectly
# rm -rf $PREFIX/include/google/protobuf
# rm -rf $PREFIX/bin/protoc

if [[ $(uname) == "Linux" ]]; then
    ln -s ${GXX} g++ || true
    ln -s ${GCC} gcc || true
    # Needed for -ltcg, it we merge build and host again, change to ${PREFIX}
    ln -s ${USED_BUILD_PREFIX}/bin/${HOST}-gcc-ar gcc-ar || true

    export LD=${GXX}
    export CC=${GCC}
    export CXX=${GXX}
    export PKG_CONFIG_PATH="$PKG_CONFIG_PATH:/usr/lib64/pkgconfig/"
    chmod +x g++ gcc gcc-ar
    export PATH=${PWD}:${PATH}

    declare -a SKIPS
    if [[ ${MINIMAL_BUILD} == yes ]]; then
      SKIPS+=(-skip); SKIPS+=(qtwebsockets)
      SKIPS+=(-skip); SKIPS+=(qtwebchannel)
      SKIPS+=(-skip); SKIPS+=(qtsvg)
      SKIPS+=(-skip); SKIPS+=(qtsensors)
      SKIPS+=(-skip); SKIPS+=(qtcanvas3d)
      SKIPS+=(-skip); SKIPS+=(qtconnectivity)
      SKIPS+=(-skip); SKIPS+=(declarative)
      SKIPS+=(-skip); SKIPS+=(multimedia)
      SKIPS+=(-skip); SKIPS+=(qttools)
      SKIPS+=(-skip); SKIPS+=(qtlocation)
      SKIPS+=(-skip); SKIPS+=(qt3d)
    fi

    if [ ${target_platform} == "linux-aarch64" ] || [ ${target_platform} == "linux-ppc64le" ]; then
        # The -reduce-relations option doesn't seem to pass for aarch64 and ppc64le
        REDUCE_RELOCATIONS=
    else
        REDUCE_RELOCATIONS=-reduce-relocations
    fi

    # ${BUILD_PREFIX}/${HOST}/sysroot/usr/lib64 is because our compilers don't look in sysroot/usr/lib64
    # CentOS7 has:
    # LIBRARY_PATH=/usr/lib/gcc/x86_64-redhat-linux/4.8.5/:/usr/lib/gcc/x86_64-redhat-linux/4.8.5/../../../../lib64/:/lib/../lib64/:/usr/lib/../lib64/:/usr/lib/gcc/x86_64-redhat-linux/4.8.5/../../../:/lib/:/usr/lib/
    # We have:
    # LIBRARY_PATH=/opt/conda/conda-bld/qt_1549795295295/_build_env/bin/../lib/gcc/x86_64-conda_cos6-linux-gnu/7.3.0/:/opt/conda/conda-bld/qt_1549795295295/_build_env/bin/../lib/gcc/:/opt/conda/conda-bld/qt_1549795295295/_build_env/bin/../lib/gcc/x86_64-conda_cos6-linux-gnu/7.3.0/../../../../x86_64-conda_cos6-linux-gnu/lib/../lib/:/opt/conda/conda-bld/qt_1549795295295/_build_env/x86_64-conda_cos6-linux-gnu/sysroot/lib/../lib/:/opt/conda/conda-bld/qt_1549795295295/_build_env/x86_64-conda_cos6-linux-gnu/sysroot/usr/lib/../lib/:/opt/conda/conda-bld/qt_1549795295295/_build_env/bin/../lib/gcc/x86_64-conda_cos6-linux-gnu/7.3.0/../../../../x86_64-conda_cos6-linux-gnu/lib/:/opt/conda/conda-bld/qt_1549795295295/_build_env/x86_64-conda_cos6-linux-gnu/sysroot/lib/:/opt/conda/conda-bld/qt_1549795295295/_build_env/x86_64-conda_cos6-linux-gnu/sysroot/usr/lib/
    # .. this is probably my fault.
    # Had been trying with:
    #   -sysroot ${BUILD_PREFIX}/${HOST}/sysroot
    # .. but it probably requires changing -L ${BUILD_PREFIX}/${HOST}/sysroot/usr/lib64 to -L /usr/lib64
    ../configure -prefix ${PREFIX} \
                 -libdir ${PREFIX}/lib \
                 -bindir ${PREFIX}/bin \
                 -headerdir ${PREFIX}/include/qt \
                 -archdatadir ${PREFIX} \
                 -datadir ${PREFIX} \
                 -I ${PREFIX}/include \
                 -L ${PREFIX}/lib \
                 -L ${BUILD_PREFIX}/${HOST}/sysroot/usr/lib64 \
                 -L ${BUILD_PREFIX}/${HOST}/sysroot/usr/lib \
                 QMAKE_LFLAGS+="-Wl,-rpath,$PREFIX/lib -Wl,-rpath-link,$PREFIX/lib -L$PREFIX/lib" \
                 -release \
                 -opensource \
                 -confirm-license \
                 -shared \
                 -nomake examples \
                 -nomake tests \
                 -verbose \
                 -skip wayland \
                 -skip qtwebengine \
                 -gstreamer 1.0 \
                 -system-libjpeg \
                 -system-libpng \
                 -system-zlib \
                 -system-sqlite \
                 -plugin-sql-sqlite \
                 -plugin-sql-mysql \
                 -plugin-sql-psql \
                 -xcb \
                 -xcb-xlib \
                 -bundled-xcb-xinput \
                 -qt-pcre \
                 -xkbcommon \
                 -dbus \
                 -no-linuxfb \
                 -no-libudev \
                 -optimize-size \
                 ${REDUCE_RELOCATIONS} \
                 -cups \
                 -openssl-linked \
                 -openssl \
                 -Wno-expansion-to-defined \
                 -D _X_INLINE=inline \
                 -D XK_dead_currency=0xfe6f \
                 -D _FORTIFY_SOURCE=2 \
                 -D XK_ISO_Level5_Lock=0xfe13 \
                 -D FC_WEIGHT_EXTRABLACK=215 \
                 -D FC_WEIGHT_ULTRABLACK=FC_WEIGHT_EXTRABLACK \
                 -D GLX_GLXEXT_PROTOTYPES \
                 "${SKIPS[@]+"${SKIPS[@]}"}"

# ltcg bloats a test tar.bz2 from 24524263 to 43257121 (built with the following skips)
#                -ltcg \
#                --disable-new-dtags \

  make -j$(nproc)
  make install
fi

if [[ ${HOST} =~ .*darwin.* ]]; then
    PLATFORM=""
    if [[ $(arch) == "arm64" ]]; then
      PLATFORM="-device-option QMAKE_APPLE_DEVICE_ARCHS=arm64"
    fi

    ../configure -prefix ${PREFIX} \
                 -libdir ${PREFIX}/lib \
                 -bindir ${PREFIX}/bin \
                 -headerdir ${PREFIX}/include/qt \
                 -archdatadir ${PREFIX} \
                 -datadir ${PREFIX} \
                 $PLATFORM \
                 -I ${PREFIX}/include \
                 -I ${PREFIX}/include/mysql \
                 -L ${PREFIX}/lib \
                 -R $PREFIX/lib \
                 -release \
                 -opensource \
                 -confirm-license \
                 -shared \
                 -nomake examples \
                 -nomake tests \
                 -verbose \
                 -skip wayland \
                 -skip qtwebengine \
                 -system-libjpeg \
                 -system-libpng \
                 -system-zlib \
                 -system-sqlite \
                 -plugin-sql-sqlite \
                 -plugin-sql-mysql \
                 -plugin-sql-psql \
                 -qt-freetype \
                 -qt-pcre \
                 -no-framework \
                 -dbus \
                 -no-mtdev \
                 -no-harfbuzz \
                 -no-libudev \
                 -no-egl \
                 -no-openssl \
                 -optimize-size

# For quicker turnaround when e.g. checking compilers optimizations
#                -skip qtwebsockets -skip qtwebchannel -skip qtwebengine -skip qtsvg -skip qtsensors -skip qtcanvas3d -skip qtconnectivity -skip declarative -skip multimedia -skip qttools -skip qtlocation -skip qt3d
# lto causes an increase in final tar.bz2 size of about 4% (tested with the above -skip options though, not the whole thing)
#                -ltcg \

    ####
    make -j${MAKE_JOBS} || exit 1
    make install
fi

# Qt Charts
# ---------
popd
pushd qtcharts
${PREFIX}/bin/qmake qtcharts.pro PREFIX=${PREFIX}
make || exit 1
make install || exit 1
popd

# Post build setup
# ----------------
# Remove static libraries that are not part of the Qt SDK.
pushd "${PREFIX}"/lib > /dev/null
    find . -name "*.a" -and -not -name "libQt*" -exec rm -f {} \;
popd > /dev/null

# Add qt.conf file to the package to make it fully relocatable
cp "${RECIPE_DIR}"/qt.conf "${PREFIX}"/bin/

if [[ ${HOST} =~ .*darwin.* ]]; then
  pushd ${PREFIX}
    # We built Qt itself with SDK 10.10, but we shouldn't
    # force users to also build their Qt apps with SDK 10.10
    # https://bugreports.qt.io/browse/QTBUG-41238
    sed -i '' 's/macosx.*$/macosx/g' mkspecs/qdevice.pri
    # We allow macOS SDK 10.12 while upstream requires 10.13 (as of Qt 5.12.1).
    sed -i '' 's/QT_MAC_SDK_VERSION_MIN = 10\..*/QT_MAC_SDK_VERSION_MIN = 10\.13/g' mkspecs/common/macx.conf
    # We may want to replace these with \$\${QMAKE_MAC_SDK_PATH}/ instead?
    sed -i '' "s|${CONDA_BUILD_SYSROOT}/|/|g" mkspecs/modules/*.pri
    CMAKE_FILES=$(find lib/cmake -name "Qt*.cmake")
    for CMAKE_FILE in ${CMAKE_FILES}; do
      sed -i '' "s|${CONDA_BUILD_SYSROOT}/|\${CMAKE_OSX_SYSROOT}/|g" ${CMAKE_FILE}
    done
  popd
fi

LICENSE_DIR="$PREFIX/share/qt/3rd_party_licenses"
for f in $(find * -iname "*LICENSE*" -or -iname "*COPYING*" -or -iname "*COPYRIGHT*" -or -iname "NOTICE"); do
  mkdir -p "$LICENSE_DIR/$(dirname $f)"
  cp -rf $f "$LICENSE_DIR/$f"
  rm -rf "$LICENSE_DIR/qtbase/examples/widgets/dialogs/licensewizard"
  rm -rf "$LICENSE_DIR/qtwebengine/src/3rdparty/chromium/tools/checklicenses"
  rm -rf "$LICENSE_DIR/qtwebengine/src/3rdparty/chromium/third_party/skia/tools/copyright"
done
