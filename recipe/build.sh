#!/bin/bash

# Compile
# -------
chmod +x configure

if [ $(uname) == Linux ]; then
    compiler_mkspec=mkspecs/common/g++-base.conf
    flag_mkspec=mkspecs/linux-g++/qmake.conf

    # The Anaconda gcc7 compiler flags specify -std=c++17 by default, which
    # activates features that break compilation. Begone!
    CXXFLAGS=$(echo $CXXFLAGS | sed -E 's@\-std=[^ ]+@@')
    export CXXFLAGS="$CXXFLAGS -std=c++98"

    # This warning causes a huge amount of spew in the build logs.
    if [ "$cxx_compiler" = gxx ] ; then
        CXXFLAGS="$CXXFLAGS -Wno-expansion-to-defined"
    fi

    export LDFLAGS="$LDFLAGS -Wl,-rpath-link,$PREFIX/lib"
    export LDFLAGS="$LDFLAGS -Wl,-rpath-link,${BUILD_PREFIX}/${HOST}/sysroot"
    export CPPFLAGS="$CPPFLAGS -DXK_dead_currency=0xfe6f -DXK_ISO_Level5_Lock=0xfe13"
    export CPPFLAGS="$CPPFLAGS -DFC_WEIGHT_EXTRABLACK=215 -DFC_WEIGHT_ULTRABLACK=FC_WEIGHT_EXTRABLACK"
    export CPPFLAGS="$CPPFLAGS -DGLX_GLXEXT_PROTOTYPES"
else
    compiler_mkspec=mkspecs/common/clang.conf
    flag_mkspec=mkspecs/macx-clang/qmake.conf

    export LDFLAGS="$LDFLAGS -Wl,-rpath,$PREFIX/lib -licuuc -licui18n -licudata"
    export CXXFLAGS="$CXXFLAGS -std=c++98"
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
    ./configure -prefix $PREFIX \
                -libdir $PREFIX/lib \
                -bindir $PREFIX/bin \
                -headerdir $PREFIX/include/qt \
                -datadir $PREFIX \
                -L $PREFIX/lib \
                -I $PREFIX/include \
                -release \
                -fast \
                -no-qt3support \
                -nomake examples \
                -nomake demos \
                -nomake docs \
                -opensource \
                -openssl \
                -webkit \
                -system-zlib \
                -system-libpng \
                -system-libtiff \
                -system-libjpeg \
                -gtkstyle \
                -no-dbus \
                -sm

    # Build on RPM based distros fails without setting LD_LIBRARY_PATH
    # to the build lib dir
    # See https://bugreports.qt.io/browse/QTBUG-5385
    LD_LIBRARY_PATH=$SRC_DIR/lib make
    make install
fi

if [ $(uname) == Darwin ]; then
    # Leave Qt set its own flags and vars, else compilation errors
    # will occur
    for x in OSX_ARCH CFLAGS CXXFLAGS LDFLAGS
    do
        unset $x
    done

    export MACOSX_DEPLOYMENT_TARGET="10.9"

    # for some reason this dir isn't created and breaks
    # the build if it isn't there
    mkdir src/3rdparty/webkit/Source/lib

    chmod +x configure
    ./configure -prefix $PREFIX \
                -libdir $PREFIX/lib \
                -bindir $PREFIX/bin \
                -headerdir $PREFIX/include/qt \
                -datadir $PREFIX \
                -L $PREFIX/lib \
                -I $PREFIX/include \
                -release \
                -fast \
                -no-qt3support \
                -nomake examples \
                -nomake demos \
                -nomake docs \
                -opensource \
                -openssl \
                -system-zlib \
                -system-libpng \
                -system-libtiff \
                -system-libjpeg \
                -no-framework \
                -arch $(uname -m) \
                -platform unsupported/macx-clang-libc++ \
                -silent \
                -no-dbus \
                -sdk $(xcode-select --print-path)/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.9.sdk \
    ####

    make -j $CPU_COUNT
    make install

    # copy activation scripts for OSX - set $QMAKESPEC
    # to unsupported/macx-clang-libc++ otherwise there are problems with qmake
    ACTIVATE_DIR=$PREFIX/etc/conda/activate.d
    DEACTIVATE_DIR=$PREFIX/etc/conda/deactivate.d
    mkdir -p $ACTIVATE_DIR
    mkdir -p $DEACTIVATE_DIR

    cp $RECIPE_DIR/scripts/activate.sh $ACTIVATE_DIR/qt-activate.sh
    cp $RECIPE_DIR/scripts/deactivate.sh $DEACTIVATE_DIR/qt-deactivate.sh
fi


# Post build setup
# ----------------

# Remove unneeded files
pushd $PREFIX
rm -rf phrasebooks translations q3porting.xml tests
popd

# Add qt.conf file to the package to make it fully relocatable
cp $RECIPE_DIR/qt.conf $PREFIX/bin/
