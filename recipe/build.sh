# Clean config for dirty builds
# -----------------------------
rm -f .qmake.stash .qmake.cache || true

# Compile
# -------
chmod +x configure

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

echo PREFIX=${PREFIX}
echo BUILD_PREFIX=${BUILD_PREFIX}
USED_BUILD_PREFIX=${BUILD_PREFIX:-${PREFIX}}
echo USED_BUILD_PREFIX=${BUILD_PREFIX}

MAKE_JOBS=$CPU_COUNT
# You can use this to cut down on the number of modules built. Of course the Qt package will not be of
# much use, but it is useful if you are iterating on e.g. figuring out compiler flags to reduce the
# size of the libraries.
MINIMAL_BUILD=no

if [[ -d qtwebkit ]]; then
  # From: http://www.linuxfromscratch.org/blfs/view/svn/x/qtwebkit5.html
  # Should really be a patch:
  sed -i.bak -e '/CONFIG/a\
    QMAKE_CXXFLAGS += -Wno-expansion-to-defined' qtwebkit/Tools/qmake/mkspecs/features/unix/default_pre.prf
fi

# For QDoc
export LLVM_INSTALL_DIR=${USED_BUILD_PREFIX}

# Remove protobuf which is pulled in indirectly
rm -rf $PREFIX/include/google/protobuf
rm -rf $PREFIX/bin/protoc

# Problems: https://bugreports.qt.io/browse/QTBUG-61158
#           (same thing happens for libyuv, it does not pickup the -I$PREFIX/include)
# Something to do with BUILD.gn files and/or ninja
# To find the files that do not include $PREFIX/include:
# pushd /opt/conda/conda-bld/qt_1520013782031/work/qtwebengine/src
# grep -R include_dirs . | grep ninja | grep -v _h_env_ | cut -d':' -f 1 | sort | uniq
# To find the files that do:
# pushd /opt/conda/conda-bld/qt_1520013782031/work/qtwebengine/src
# grep -R include_dirs . | grep ninja | grep _h_env_ | cut -d':' -f 1 | sort | uniq
# Need to figure out what in the BUILD.gn files is different, so compare the smallest file from each?
# grep -R include_dirs . | grep ninja | grep -v _h_env_ | cut -d':' -f 1 | sort | uniq | xargs stat -c "%s %n" 2>/dev/null | sort -h | head -n 10
# grep -R include_dirs . | grep ninja | grep    _h_env_ | cut -d':' -f 1 | sort | uniq | xargs stat -c "%s %n" 2>/dev/null | sort -h | head -n 10
# Then find the .gn or .gni files that these ninja files were created from and figure out wtf is going on.

# qtwebengine needs python 2
conda create -y --prefix "${SRC_DIR}/python2_hack" -c https://repo.continuum.io/pkgs/main --no-deps python=2
export PATH=${SRC_DIR}/python2_hack/bin:${PATH}

if [[ ${HOST} =~ .*linux.* ]]; then

    if ! which ruby > /dev/null 2>&1; then
        echo "You need ruby to build qtwebkit"
        exit 1
    fi

    ln -s ${GXX} g++ || true
    ln -s ${GCC} gcc || true
    # Needed for -ltcg, it we merge build and host again, change to ${PREFIX}
    ln -s ${USED_BUILD_PREFIX}/bin/${HOST}-gcc-ar gcc-ar || true
    chmod +x g++ gcc gcc-ar
    export PATH=${PWD}:${PATH}
    export LD=${GXX}
    export CC=${GCC}
    export CXX=${GXX}

    conda create -y --prefix "${SRC_DIR}/openssl_hack" -c https://repo.continuum.io/pkgs/main  \
                  --no-deps --yes --copy --prefix "${SRC_DIR}/openssl_hack"  \
                  openssl=${openssl}
    export OPENSSL_LIBS="-L${SRC_DIR}/openssl_hack/lib -lssl -lcrypto"
    rm -rf ${PREFIX}/include/openssl

    # Qt has some braindamaged behaviour around handling compiler system include and lib paths. Basically, if it finds any include dir
    # that is a system include dir then it prefixes it with -isystem. Problem is, passing -isystem <blah> causes GCC to forget all the
    # other system include paths. The reason that Qt needs to know about these paths is probably due to moc needing to know about them
    # so we cannot just elide them altogether. Instead, as soon as Qt sees one system path it needs to add them all as a group, in the
    # correct order. This is probably fairly tricky so we work around needing to do that by having them all be present all the time.
    #
    # Further, any system dirs that appear from the output from pkg-config (QT_XCB_CFLAGS) can cause incorrect emission ordering so we
    # must filter those out too which we do with a pkg-config wrapper.
    #
    # References:
    #
    # https://github.com/voidlinux/void-packages/issues/5254
    # https://github.com/qt/qtbase/commit/0b144bc76a368ecc6c5c1121a1b51e888a0621ac
    # https://codereview.qt-project.org/#/c/157817/
    #
    sed -i "s/-isystem//g" "qtbase/mkspecs/common/gcc-base.conf"
    export PKG_CONFIG_LIBDIR=$(${USED_BUILD_PREFIX}/bin/pkg-config --pclibdir)

    export PATH=${PWD}:${PATH}
    declare -a SKIPS
    if [[ ${MINIMAL_BUILD} == yes ]]; then
      SKIPS+=(-skip); SKIPS+=(qtwebsockets)
      SKIPS+=(-skip); SKIPS+=(qtwebchannel)
      SKIPS+=(-skip); SKIPS+=(qtwebengine)
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
    declare -A COS6_MISSING_DEFINES
    if [[ ${_CONDA_PYTHON_SYSCONFIGDATA_NAME} == *cos6* ]]; then
      COS6_MISSING_DEFINES["SYN_DROPPED"]="3"
      COS6_MISSING_DEFINES["BTN_TRIGGER_HAPPY1"]="0x2c0"
      COS6_MISSING_DEFINES["BTN_TRIGGER_HAPPY2"]="0x2c1"
      COS6_MISSING_DEFINES["BTN_TRIGGER_HAPPY3"]="0x2c2"
      COS6_MISSING_DEFINES["BTN_TRIGGER_HAPPY4"]="0x2c3"
      COS6_MISSING_DEFINES["BTN_TRIGGER_HAPPY17"]="0x2d0"
      COS6_MISSING_DEFINES["INPUT_PROP_POINTER"]="0x00"
      COS6_MISSING_DEFINES["INPUT_PROP_DIRECT"]="0x01"
      COS6_MISSING_DEFINES["INPUT_PROP_BUTTONPAD"]="0x02"
      COS6_MISSING_DEFINES["INPUT_PROP_SEMI_MT"]="0x03"
      COS6_MISSING_DEFINES["INPUT_PROP_MAX"]="0x1f"
      COS6_MISSING_DEFINES["INPUT_PROP_CNT"]="0x20"
      COS6_MISSING_DEFINES["ABS_MT_SLOT"]="0x2f"
      COS6_MISSING_DEFINES["ABS_MT_PRESSURE"]="0x3a"
      COS6_MISSING_DEFINES["ABS_MT_DISTANCE"]="0x3b"

      # MAJOR HACK ahead!!!!!!
      # The above macros are missing in cos6 and there are a few files that I have to patch to make it work
      # Tried giving this as macros to ./configure, but the configure script doesn't pass them to ninja when building chromium.
      for key in ${!COS6_MISSING_DEFINES[@]}; do
        mv ${BUILD_PREFIX}/${HOST}/sysroot/usr/include/linux/input.h ${BUILD_PREFIX}/${HOST}/sysroot/usr/include/linux/input.h.bak
        cp ${BUILD_PREFIX}/${HOST}/sysroot/usr/include/linux/input.h.bak ${BUILD_PREFIX}/${HOST}/sysroot/usr/include/linux/input.h
        echo "#ifndef ${key}"                                 >> ${BUILD_PREFIX}/${HOST}/sysroot/usr/include/linux/input.h
        echo "#define ${key} ${COS6_MISSING_DEFINES[${key}]}" >> ${BUILD_PREFIX}/${HOST}/sysroot/usr/include/linux/input.h
        echo "#endif" >> ${BUILD_PREFIX}/${HOST}/sysroot/usr/include/linux/input.h
      done
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
    ./configure -prefix ${PREFIX} \
                -libdir ${PREFIX}/lib \
                -bindir ${PREFIX}/bin \
                -headerdir ${PREFIX}/include/qt \
                -archdatadir ${PREFIX} \
                -datadir ${PREFIX} \
                -I ${SRC_DIR}/openssl_hack/include \
                -I ${PREFIX}/include \
                -L ${PREFIX}/lib \
                -L ${BUILD_PREFIX}/${HOST}/sysroot/usr/lib64 \
                -release \
                -opensource \
                -confirm-license \
                -shared \
                -nomake examples \
                -nomake tests \
                -verbose \
                -skip wayland \
                -system-libjpeg \
                -system-libpng \
                -system-zlib \
                -system-sqlite \
                -plugin-sql-sqlite \
                -plugin-sql-mysql \
                -plugin-sql-psql \
                -qt-pcre \
                -qt-xcb \
                -xkbcommon \
                -dbus \
                -no-linuxfb \
                -no-libudev \
                -no-avx \
                -no-avx2 \
                -optimize-size \
                -reduce-relocations \
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
                "${SKIPS[@]}" \
                QMAKE_LFLAGS+="-Wl,-rpath,$PREFIX/lib -Wl,-rpath-link,$PREFIX/lib -L$PREFIX/lib"



# ltcg bloats a test tar.bz2 from 24524263 to 43257121 (built with the following skips)
#                -ltcg \
#                --disable-new-dtags \

    if [[ ${MINIMAL_BUILD} != yes ]]; then
      CPATH=$PREFIX/include LD_LIBRARY_PATH=$PREFIX/lib make -j${MAKE_JOBS} module-qtwebengine || exit 1
      if find . -name "libQt5WebEngine*so" -exec false {} +; then
        echo "Did not build qtwebengine, exiting"
        exit 1
      fi
    fi
    CPATH=$PREFIX/include LD_LIBRARY_PATH=$PREFIX/lib make -j${MAKE_JOBS} || exit 1
    make install
fi

if [[ ${HOST} =~ .*darwin.* ]]; then

    # Avoid Xcode
    cp "${RECIPE_DIR}"/xcrun .
    cp "${RECIPE_DIR}"/xcodebuild .
    # Some test runs 'clang -v', but I do not want to add it as a requirement just for that.
    ln -s "${CXX}" ${HOST}-clang || true
    # For ltcg we cannot use libtool (or at least not the macOS 10.9 system one) due to lack of LLVM bitcode support.
    ln -s "${LIBTOOL}" libtool || true
    # Just in-case our strip is better than the system one.
    ln -s "${STRIP}" strip || true
    chmod +x ${HOST}-clang libtool strip
    # Qt passes clang flags to LD (e.g. -stdlib=c++)
    export LD=${CXX}
    PATH=${PWD}:${PATH}

    # Because of the use of Objective-C Generics we need at least MacOSX10.11.sdk
    if [[ $(basename $CONDA_BUILD_SYSROOT) != "MacOSX10.12.sdk" ]]; then
      echo "WARNING: You asked me to use $CONDA_BUILD_SYSROOT as the MacOS SDK"
      echo "         But because of the use of Objective-C Generics we need at"
      echo "         least MacOSX10.12.sdk"
      CONDA_BUILD_SYSROOT=/opt/MacOSX10.12.sdk
      if [[ ! -d $CONDA_BUILD_SYSROOT ]]; then
        echo "ERROR: $CONDA_BUILD_SYSROOT is not a directory"
        exit 1
      fi
    fi
    
    sed -i.bak "s/-Wno-c++11-narrowing'/-Wno-c++11-narrowing', '-Wno-elaborated-enum-base'/g" qtwebengine/src/3rdparty/gn/build/gen.py
    sed -i.bak 's/-Wno-address-of-packed-member"/-Wno-address-of-packed-member", "-Wno-elaborated-enum-base"/g' qtwebengine/src/3rdparty/chromium/build/config/compiler/BUILD.gn

    # Move VERSION file which conflicts with version in libc++ headers in case-insensitive files
    mv qtwebengine/src/3rdparty/chromium/third_party/libsrtp/VERSION qtwebengine/src/3rdparty/chromium/third_party/libsrtp/LIBSRTP_VERSION || true;

    #             -qtlibinfix .conda \

    ./configure -prefix $PREFIX \
                -libdir $PREFIX/lib \
                -bindir $PREFIX/bin \
                -headerdir $PREFIX/include/qt \
                -archdatadir $PREFIX \
                -datadir $PREFIX \
                -L $PREFIX/lib \
                -I $PREFIX/include \
                -R $PREFIX/lib \
                -release \
                -opensource \
                -confirm-license \
                -shared \
                -nomake examples \
                -nomake tests \
                -verbose \
                -skip wayland \
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
                -optimize-size \
                -sdk macosx10.12

# For quicker turnaround when e.g. checking compilers optimizations
#                -skip qtwebsockets -skip qtwebchannel -skip qtwebengine -skip qtsvg -skip qtsensors -skip qtcanvas3d -skip qtconnectivity -skip declarative -skip multimedia -skip qttools -skip qtlocation -skip qt3d
# lto causes an increase in final tar.bz2 size of about 4% (tested with the above -skip options though, not the whole thing)
#                -ltcg \

    ####
    make -j${MAKE_JOBS} module-qtwebengine || exit 1
    if find . -name "libQt5WebEngine*dylib" -exec false {} +; then
      echo "Did not build qtwebengine, exiting"
      exit 1
    fi
    make -j${MAKE_JOBS} || exit 1
    make install

    # Avoid Xcode (2)
    mkdir -p "${PREFIX}"/bin/xc-avoidance || true
    cp "${RECIPE_DIR}"/xcrun "${PREFIX}"/bin/xc-avoidance/
    cp "${RECIPE_DIR}"/xcodebuild "${PREFIX}"/bin/xc-avoidance/
fi

# Qt Charts
# ---------
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
    sed -i '' 's/QT_MAC_SDK_VERSION_MIN = 10\..*/QT_MAC_SDK_VERSION_MIN = 10\.12/g' mkspecs/common/macx.conf
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
