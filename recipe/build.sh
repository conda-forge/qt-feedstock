#!/bin/bash

set -ex

# Compile
# -------
chmod +x configure

# Frustratingly, Qt's configure checks do not honor the standard build
# environment variables ($CC, $*FLAGS, etc) in a very consistent way. In
# particular, they are largely ignored during configuration. AFAICT, the best
# way to get them to apply during both configuration and the primary build is
# to modify the "mkspec" files used in the build. (You can pass #defines to
# the configuration script, but you can't pass linker flags like
# `-Wl,-rpath`.)
#
# Aside: our toolchain environments unfortunately mix preprocessor and
# non-preprocessor flags in both $CFLAGS and $CPPFLAGS.

if [ $(uname) == Linux ]; then
    compiler_mkspec=qtbase/mkspecs/common/g++-base.conf
    flag_mkspec=qtbase/mkspecs/linux-g++/qmake.conf

    # The Anaconda gcc7 compiler flags specify -std=c++17 by default, which
    # activates features that break compilation. Begone!
    CXXFLAGS=$(echo $CXXFLAGS | sed -E 's@\-std=[^ ]+@@')
    export CXXFLAGS="$CXXFLAGS -std=c++11"

    # This warning causes a huge amount of spew in the build logs.
    if [ "$cxx_compiler" = gxx ] ; then
        CXXFLAGS="$CXXFLAGS -Wno-expansion-to-defined"
    fi

    export LDFLAGS="$LDFLAGS -Wl,-rpath-link,$PREFIX/lib"
    export CPPFLAGS="$CPPFLAGS -DXK_dead_currency=0xfe6f -DXK_ISO_Level5_Lock=0xfe13"
    export CPPFLAGS="$CPPFLAGS -DFC_WEIGHT_EXTRABLACK=215 -DFC_WEIGHT_ULTRABLACK=FC_WEIGHT_EXTRABLACK"
    export CPPFLAGS="$CPPFLAGS -DGLX_GLXEXT_PROTOTYPES"
else
    compiler_mkspec=qtbase/mkspecs/common/clang.conf
    flag_mkspec=qtbase/mkspecs/macx-clang/qmake.conf

    export LDFLAGS="$LDFLAGS -Wl,-rpath,$PREFIX/lib"
    export CXXFLAGS="$CXXFLAGS -std=c++11"
fi

# If we don't $(basename) here, when $CC contains an absolute path it will
# point into the *build* environment directory, which won't get replaced when
# making the package -- breaking the mkspec for downstream consumers.
sed -i -e "s|^QMAKE_CC.*=.*|QMAKE_CC = $(basename $CC)|" $compiler_mkspec
sed -i -e "s|^QMAKE_CXX.*=.*|QMAKE_CXX = $(basename $CXX)|" $compiler_mkspec

# The mkspecs only append to QMAKE_*FLAGS, so if we set them at the very top
# of the main mkspec file, the settings will be honored.

cp $flag_mkspec $flag_mkspec.orig
cat <<EOF >$flag_mkspec
QMAKE_CFLAGS = $CFLAGS $CPPFLAGS
QMAKE_CXXFLAGS = $CXXFLAGS $CPPFLAGS
QMAKE_LFLAGS = $LDFLAGS
EOF
cat $flag_mkspec.orig >>$flag_mkspec

# The main Qt build does eventually honor $LD, but it calls it like a
# compiler, not like the straight `ld` program as in the conda toolchain
# variables.
export LD="$CXX"

# If we leave these variables set, they will override our work during the main
# build.
unset CFLAGS CPPFLAGS CXXFLAGS LDFLAGS

if [ $(uname) == Linux ]; then
    # Download QtWebkit
    curl -L "http://download.qt.io/community_releases/5.6/${PKG_VERSION}/qtwebkit-opensource-src-${PKG_VERSION}.tar.xz" > qtwebkit.tar.xz
    unxz qtwebkit.tar.xz
    tar xf qtwebkit.tar
    mv qtwebkit-opensource-src* qtwebkit
    patch -p0 < "${RECIPE_DIR}"/0001-qtwebkit-old-ld-compat.patch
    patch -p0 < "${RECIPE_DIR}"/0002-qtwebkit-ruby-1.8.patch
    patch -p0 < "${RECIPE_DIR}"/0003-qtwebkit-O_CLOEXEC-workaround.patch
    patch -p0 < "${RECIPE_DIR}"/0004-qtwebkit-CentOS5-Fix-fucomip-compat-with-gas-2.17.50.patch
    # From https://bugs.webkit.org/show_bug.cgi?id=70610, http://trac.webkit.org/changeset/172759, https://github.com/WebKit/webkit/commit/4d7f0f
    patch -p0 < "${RECIPE_DIR}"/0005-qtwebkit-fix-TEXTREL-on-x86-changeset_172759.patch
    rm qtwebkit.tar

    ./configure -prefix $PREFIX \
                -libdir $PREFIX/lib \
                -bindir $PREFIX/bin \
                -headerdir $PREFIX/include/qt \
                -archdatadir $PREFIX \
                -datadir $PREFIX \
                -release \
                -opensource \
                -confirm-license \
                -shared \
                -nomake examples \
                -nomake tests \
                -verbose \
                -skip enginio \
                -skip location \
                -skip sensors \
                -skip serialport \
                -skip serialbus \
                -skip quickcontrols2 \
                -skip wayland \
                -skip canvas3d \
                -skip 3d \
                -skip webengine \
                -system-libjpeg \
                -system-libpng \
                -system-zlib \
                -system-sqlite \
                -plugin-sql-sqlite \
                -qt-pcre \
                -qt-xcb \
                -qt-xkbcommon \
                -xkb-config-root $PREFIX/lib \
                -dbus \
                -no-linuxfb \
                -no-libudev \
                -no-avx \
                -no-avx2
# To get a much quicker turnaround you can add this: (remember also to add the backslash after `no-avx2`)
# -skip qtwebsockets -skip qtwebchannel -skip qtwayland -skip qtsvg -skip qtsensors -skip qtcanvas3d -skip qtconnectivity -skip declarative -skip multimedia -skip qttools

# If we must not remove strict_c++ from qtbase/mkspecs/features/qt_common.prf
# (0007-qtbase-CentOS5-Do-not-use-strict_c++.patch) then we need to add these
# defines instead:
# -D __u64="unsigned long long" \
# -D __s64="__signed__ long long" \
# -D __le64="unsigned long long" \
# -D __be64="__signed__ long long"

    LD_LIBRARY_PATH=$PREFIX/lib make -j $CPU_COUNT || exit 1
    make install
fi

if [ $(uname) == Darwin ]; then
    unset OSX_ARCH
    sed -i.bak "s/QMAKE_MAC_SDK *= macosx/QMAKE_MAC_SDK           = macosx${MACOSX_DEPLOYMENT_TARGET}/g" qtbase/mkspecs/common/macx.conf
    export MACOSX_DEPLOYMENT_TARGET=10.9

    ./configure -prefix $PREFIX \
                -libdir $PREFIX/lib \
                -bindir $PREFIX/bin \
                -headerdir $PREFIX/include/qt \
                -archdatadir $PREFIX \
                -datadir $PREFIX \
                -R $PREFIX/lib \
                -release \
                -opensource \
                -confirm-license \
                -shared \
                -nomake examples \
                -nomake tests \
                -verbose \
                -skip enginio \
                -skip location \
                -skip sensors \
                -skip serialport \
                -skip serialbus \
                -skip quickcontrols2 \
                -skip wayland \
                -skip canvas3d \
                -skip 3d \
                -system-libjpeg \
                -system-libpng \
                -system-zlib \
                -qt-pcre \
                -qt-freetype \
                -c++11 \
                -no-framework \
                -no-dbus \
                -no-mtdev \
                -no-harfbuzz \
                -no-xinput2 \
                -no-xcb-xlib \
                -no-libudev \
                -no-egl \
                -no-openssl \
                -sdk macosx${MACOSX_DEPLOYMENT_TARGET} \
    ####

    make -j $CPU_COUNT || exit 1
    make install
fi


# Post build setup
# ----------------
# Remove static libraries that are not part of the Qt SDK.
pushd "${PREFIX}"/lib > /dev/null
    find . -name "*.a" -and -not -name "libQt*" -exec rm -f {} \;
popd > /dev/null

# Add qt.conf file to the package to make it fully relocatable
cp "${RECIPE_DIR}"/qt.conf "${PREFIX}"/bin/

if [ $(uname) == Darwin ]
then
    BIN=$PREFIX/bin

    for name in Assistant Designer Linguist pixeltool qml
    do
        mv ${BIN}/${name}.app ${BIN}/${name}app
    done

    # We built Qt itself with SDK 10.9, but we shouldn't
    # force users to also build their Qt apps with SDK 10.9
    # https://bugreports.qt.io/browse/QTBUG-41238
    sed -i '' s/macosx10\../macosx/g ${PREFIX}/mkspecs/qdevice.pri

    POST_LINK=$BIN/.qt-post-link.sh
    PRE_UNLINK=$BIN/.qt-pre-unlink.sh
    cp $RECIPE_DIR/osx-post.sh $POST_LINK
    cp $RECIPE_DIR/osx-pre.sh $PRE_UNLINK
    chmod +x $POST_LINK $PRE_UNLINK
fi
