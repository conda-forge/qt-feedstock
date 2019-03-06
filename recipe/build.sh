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
    export CXXFLAGS="$CXXFLAGS -std=c++11"

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
    compiler_mkspec=qtbase/mkspecs/common/clang.conf
    flag_mkspec=qtbase/mkspecs/macx-clang/qmake.conf

    export LDFLAGS="$LDFLAGS -Wl,-rpath,$PREFIX/lib -licuuc -licui18n -licudata"
    export CXXFLAGS="$CXXFLAGS -std=c++11"
fi

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
