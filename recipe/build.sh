#!/bin/bash

# Compile
# -------
chmod +x configure

# Let Qt set its own flags and vars
for x in OSX_ARCH CFLAGS CXXFLAGS LDFLAGS
do
    unset $x
done

MAKE_JOBS=$CPU_COUNT

if [[ -d qtwebkit ]]; then
  # From: http://www.linuxfromscratch.org/blfs/view/svn/x/qtwebkit5.html
  # Should really be a patch:
  sed -i.bak -e '/CONFIG/a\
    QMAKE_CXXFLAGS += -Wno-expansion-to-defined' qtwebkit/Tools/qmake/mkspecs/features/unix/default_pre.prf
fi

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

if [[ ${HOST} =~ .*linux.* ]]; then

    if ! which ruby > /dev/null 2>&1; then
        echo "You need ruby to build qtwebkit"
        exit 1
    fi

    ln -s ${GXX} g++ || true
    ln -s ${GCC} gcc || true
    export PATH=${PWD}:${PATH}
    export LD=${GXX}
    export CC=${GCC}
    export CXX=${GXX}

    mkdir -p "${SRC_DIR}/openssl_hack"
    conda install -c https://repo.continuum.io/pkgs/main \
                  --no-deps --yes --copy --prefix "${SRC_DIR}/openssl_hack" \
                  openssl
    export OPENSSL_LIBS="-L${SRC_DIR}/openssl_hack/lib -lssl -lcrypto"
    rm -rf ${PREFIX}/include/openssl

    # Qt has some braindamaged behaviour around handling compiler system include and lib paths. Basically, if it finds any include dir
    # that is a system include dir then it prefixes it with -isystem. Problem is, passing -isystem <blah> causes GCC to forget all the
    # other system include paths. The reason that Qt needs to know about these paths is probably due to moc needing to know about them
    # so we cannot just elide them altogether. Instead, as soon as Qt sees one system path it needs to add them all as a group, in the
    # correct order. This is probably fairly tricky so we work around needing to do that by having them all be present all the time.
    #
    # Futher, any system dirs that appear from the output from pkg-config (QT_XCB_CFLAGS) can cause incorrect emission ordering so we
    # must filter those out too which we do with a pkg-config wrapper.
    #
    # References:
    #
    # https://github.com/voidlinux/void-packages/issues/5254
    # https://github.com/qt/qtbase/commit/0b144bc76a368ecc6c5c1121a1b51e888a0621ac
    # https://codereview.qt-project.org/#/c/157817/
    #
    declare -a INCDIRS
    INCDIRS=(-I ${PREFIX}/include)
    SYSINCDIRS=$(echo "" | ${CXX} -xc++ -E -v - 2>&1 | awk '/#include <...> search starts here:/{flag=1;next}/End of search list./{flag=0}flag')
    for SYSINCDIR in ${SYSINCDIRS}; do
      INCDIRS+=(-I ${SYSINCDIR})
    done
    echo "#!/usr/bin/env sh"                                                          > ./pkg-config
    echo "pc_res=\$(\${PREFIX}/bin/pkg-config \"\$@\")"                              >> ./pkg-config
    echo "res=\$?"                                                                   >> ./pkg-config
    echo "if [[ \${res} != 0 ]]; then"                                               >> ./pkg-config
    echo "  echo \${pc_res}"                                                         >> ./pkg-config
    echo "  exit \${res}"                                                            >> ./pkg-config
    echo "fi"                                                                        >> ./pkg-config
    echo "echo \${pc_res} | sed 's/[a-zA-Z0-9_-/\.]*sysroot[a-zA-Z0-9_-/\.]*//g'"    >> ./pkg-config
    echo "exit 0"                                                                    >> ./pkg-config
    chmod +x ./pkg-config
    export PATH=${PWD}:${PATH}

    ./configure -prefix $PREFIX \
                -libdir $PREFIX/lib \
                -bindir $PREFIX/bin \
                -headerdir $PREFIX/include/qt \
                -archdatadir $PREFIX \
                -datadir $PREFIX \
                -I ${SRC_DIR}/openssl_hack/include \
                -L $PREFIX/lib \
                "${INCDIRS[@]}" \
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
                -no-avx2 \
                -Wno-expansion-to-defined \
                -D _X_INLINE=inline \
                -D XK_dead_currency=0xfe6f \
                -D _FORTIFY_SOURCE=2 \
                -D XK_ISO_Level5_Lock=0xfe13 \
                -D FC_WEIGHT_EXTRABLACK=215 \
                -D FC_WEIGHT_ULTRABLACK=FC_WEIGHT_EXTRABLACK \
                -D GLX_GLXEXT_PROTOTYPES

#                --disable-new-dtags \

# To get a much quicker turnaround you can add this: (remember also to add the backslash after GLX_GLXEXT_PROTOTYPES)
# -skip qtwebsockets -skip qtwebchannel -skip qtwayland -skip qtsvg -skip qtsensors -skip qtcanvas3d -skip qtconnectivity -skip declarative -skip multimedia -skip qttools

    LD_LIBRARY_PATH=$PREFIX/lib make -j${MAKE_JOBS} module-qtwebengine || exit 1
    LD_LIBRARY_PATH=$PREFIX/lib make -j${MAKE_JOBS} || exit 1
    make install
fi

if [[ ${HOST} =~ .*darwin.* ]]; then

    # Avoid Xcode
    cp "${RECIPE_DIR}"/xcrun .
    cp "${RECIPE_DIR}"/xcodebuild .
    # Some test runs 'clang -v', but I do not want to add it as a requirement just for that.
    ln -s "${PREFIX}"/bin/${HOST}-clang++ ${HOST}-clang || true
    # Qt passes clang flags to LD (e.g. -stdlib=c++)
    export LD=${CXX}
    PATH=${PWD}:${PATH}

    # Because of the use of Objective-C Generics we need at least MacOSX10.11.sdk
    if [[ $CONDA_BUILD_SYSROOT != /opt/MacOSX10.11.sdk ]]; then
      echo "WARNING: You asked me to use $CONDA_BUILD_SYSROOT as the MacOS SDK"
      echo "         But because of the use of Objective-C Generics we need at"
      echo "         least MacOSX10.11.sdk"
      CONDA_BUILD_SYSROOT=/opt/MacOSX10.11.sdk
      if [[ ! -d $CONDA_BUILD_SYSROOT ]]; then
        echo "ERROR: $CONDA_BUILD_SYSROOT is not a directory"
        exit 1
      fi
    fi

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
                -qt-freetype \
                -qt-pcre \
                -no-framework \
                -no-dbus \
                -no-mtdev \
                -no-harfbuzz \
                -no-xinput2 \
                -no-xcb-xlib \
                -no-libudev \
                -no-egl \
                -no-openssl \
                -sdk macosx10.10
    ####
    make -j${MAKE_JOBS} module-qtwebengine || exit 1
    if find . -name "libQt5WebEngine*dylib" -exec false {} +; then
      echo "Did not build qtwebengine, exiting"
      exit 1
    fi
    make -j${MAKE_JOBS} || exit 1
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

if [[ ${HOST} =~ .*darwin.* ]];
then
    BIN=${PREFIX}/bin

    # This stuff needs to go away. It is working around some automatic .app handling by pkgbuild and installer.
    # It may be possible to set up a correct (i.e. non-default) COMPONENT PROPERTY LIST from:
    # https://developer.apple.com/legacy/library/documentation/Darwin/Reference/ManPages/man1/pkgbuild.1.html
    # where we specify:
    # BundleIsRelocatable = True
    # BundleIsVersionChecked = False
    # BundleHasStrictIdentifier = False
    # BundleOverwriteAction = ? not sure
    # .. to invesigate this, we should create installers with .apps and see
    #    what pkgbuild auto-creates with --analyze and iterate on that.
    # Failing that, we should use a different installer technology, one that we use only to install
    # Python and conda which is then used to install everything else.
    for _name in Assistant Designer Linguist pixeltool qml; do
        mv ${BIN}/${_name}.app ${BIN}/${_name}app
    done

    # We built Qt itself with SDK 10.10, but we shouldn't
    # force users to also build their Qt apps with SDK 10.10
    # https://bugreports.qt.io/browse/QTBUG-41238
    sed -i '' 's/macosx.*$/macosx/g' ${PREFIX}/mkspecs/qdevice.pri

    POST_LINK=${BIN}/.qt-post-link.sh
    PRE_UNLINK=${BIN}/.qt-pre-unlink.sh
    cp ${RECIPE_DIR}/osx-post.sh ${POST_LINK}
    cp ${RECIPE_DIR}/osx-pre.sh ${PRE_UNLINK}
    chmod +x ${POST_LINK} ${PRE_UNLINK}
fi
