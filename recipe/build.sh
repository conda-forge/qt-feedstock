# Clean config for dirty builds
# -----------------------------
rm -f .qmake.stash .qmake.cache || true

if [[ ${target_platform} =~ .*linux.* ]]; then
  ln -s ${GXX} g++ || true
  ln -s ${GCC} gcc || true
  ln -s ${AR} ar || true
  ln -s ${NM} nm || true
  # Needed for -ltcg, it we merge build and host again, change to ${PREFIX}
  ln -s ${GCC_AR} gcc-ar || true
  chmod +x g++ gcc ar nm gcc-ar
fi
# Compile
# -------
chmod +x configure

# Let Qt set its own flags and vars
for x in OSX_ARCH CFLAGS CXXFLAGS LDFLAGS
do
    unset $x
done

if which ccache; then
  CCACHE=-ccache
else
  CCACHE=
fi

# Use -optimize-debug as debug is otherwise too big.
declare -a LIBS_NATURE_ARGS=()
LIBS_NATURE_ARGS+=(-shared)
if [[ ${CONDA_BUILD_QT_LIBS_NATURE} == debug ]]; then
  LIBS_NATURE_ARGS+=(-force-debug-info)
  LIBS_NATURE_ARGS+=(-separate-debug-info)
  LIBS_NATURE_ARGS+=(-debug)
  if [[ ! ${CC} =~ .*clang.* ]]; then
    LIBS_NATURE_ARGS+=(-optimize-debug)
  fi
elif [[ ${CONDA_BUILD_QT_LIBS_NATURE} == debug-and-release ]]; then
  # If you want this build you are probably having a lot of trouble.
  LIBS_NATURE_ARGS+=(-force-debug-info)
  LIBS_NATURE_ARGS+=(-separate-debug-info)
  LIBS_NATURE_ARGS+=(-debug-and-release)
  if [[ ! ${CC} =~ .*clang.* ]]; then
    LIBS_NATURE_ARGS+=(-optimize-debug)
  fi
else
  # LIBS_NATURE_ARGS+=(-force-debug-info)
  # LIBS_NATURE_ARGS+=(-separate-debug-info)
  LIBS_NATURE_ARGS+=(-release)
  LIBS_NATURE_ARGS+=(-optimize-size)
  if [[ ! ${CC} =~ .*clang.* ]]; then
    LIBS_NATURE_ARGS+=(-reduce-relocations)
  fi
  LIBS_NATURE_ARGS+=(-optimized-tools)
fi

MAKE_JOBS=$CPU_COUNT

if [[ -d qtwebkit ]]; then
  # From: http://www.linuxfromscratch.org/blfs/view/svn/x/qtwebkit5.html
  # Should really be a patch:
  sed -i.bak -e '/CONFIG/a\
    QMAKE_CXXFLAGS += -Wno-expansion-to-defined' qtwebkit/Tools/qmake/mkspecs/features/unix/default_pre.prf
fi

# For QDoc
export LLVM_INSTALL_DIR=${PREFIX}


function parse_macos_sdk_ver
{
  local _SYSROOT=${1}; shift
  local _SDK_VER_VAR=${1} ; shift
  local _SDK_VER_MAJOR_VAR=${1} ; shift
  local _SDK_VER_MINOR_VAR=${1} ; shift
  re='[^0-9]*([0-9\.]+)\.\.*'
  if [[ "${_SYSROOT}" =~ $re ]]; then
    local _SDK_VER=${BASH_REMATCH[1]}
    re='([0-9]*)\.([0-9]*).*'
    if [[ "${_SDK_VER}" =~ $re ]]; then
      local _SDK_VER_MAJOR=${BASH_REMATCH[1]}
      local _SDK_VER_MINOR=${BASH_REMATCH[2]}
    fi
  fi
  eval "${_SDK_VER_VAR}=${_SDK_VER}"
  eval "${_SDK_VER_MAJOR_VAR}=${_SDK_VER_MAJOR}"
  eval "${_SDK_VER_MINOR_VAR}=${_SDK_VER_MINOR}"
}


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

if [[ ${target_platform} =~ .*linux.* ]]; then

  if ! which ruby > /dev/null 2>&1; then
    echo "You need ruby to build qtwebkit"
    exit 1
  fi

  if [[ -n ${CCACHE} ]]; then
    ln -s ${GXX} g++ || true
    ln -s ${GCC} gcc || true
    # Needed for -ltcg
    ln -s ${BUILD_PREFIX}/bin/${HOST}-gcc-ar gcc-ar || true
    chmod +x g++ gcc gcc-ar
    export PATH=${PWD}:${PATH}
  fi
  export LD=${GXX}
  export CC=${GCC}
  export CXX=${GXX}
  # Urgh. Why?
  # conda init || true
  # conda create -y --prefix "${SRC_DIR}/openssl_hack" -c https://repo.continuum.io/pkgs/main  \
  #               --no-deps --yes --copy --prefix "${SRC_DIR}/openssl_hack"  \
  #               openssl=${openssl} || true
  # export OPENSSL_LIBS="-L${SRC_DIR}/openssl_hack/lib -lssl -lcrypto"
  # rm -rf ${PREFIX}/include/openssl
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
  
  export PATH=${PWD}:${PATH}
  declare -A COS6_MISSING_DEFINES=()
  declare -a QT_CONFIGURE_EXTRA_DEFINES=()

  if [[ ${HOST} =~ .*cos6.* ]]; then
    
  
    # Quite a big hack here. These are passed to Qt's configure command-line.
    QT_CONFIGURE_EXTRA_DEFINES+=("-D" "_X_INLINE=inline")
    QT_CONFIGURE_EXTRA_DEFINES+=("-D" "XK_dead_currency=0xfe6f")
    QT_CONFIGURE_EXTRA_DEFINES+=("-D" "_FORTIFY_SOURCE=2")
    QT_CONFIGURE_EXTRA_DEFINES+=("-D" "FC_WEIGHT_EXTRABLACK=215")
    QT_CONFIGURE_EXTRA_DEFINES+=("-D" "FC_WEIGHT_ULTRABLACK=FC_WEIGHT_EXTRABLACK")
    QT_CONFIGURE_EXTRA_DEFINES+=("-D" "GLX_GLXEXT_PROTOTYPES")

    # Major hack here.
    # The following macros are missing in cos6 and there are a few files that I have to patch to make it work
    # Tried giving this as macros to ./configure, but the configure script doesn't pass them to ninja when building chromium.
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

# OpenGL CDT problems as ever:
#
# old (working, of sorts):
#
# PATH=$SRC_DIR:$PATH \
#   g++ -Wl,-O1 \
#     -fuse-ld=gold \
#     -o opengl main.o \
#     -L$PREFIX/lib \
#     -L$BUILD_PREFIX/x86_64-conda_cos6-linux-gnu/sysroot/usr/lib64 \
#     $BUILD_PREFIX/bin/../x86_64-conda_cos6-linux-gnu/sysroot/usr/lib64/libGL.so
#
# .. this only worked because gold doesn't care!
#
# vs 5.15.0, non-working:
#
# PATH=$SRC_DIR:$PATH \
#   g++ -m64 -Wl,-O1 \
#     -o opengl main.o \
#     -L$PREFIX/lib \
#     -L$BUILD_PREFIX/x86_64-conda_cos6-linux-gnu/sysroot/usr/lib64 \
#     -L/usr/lib64 \
#     -L$BUILD_PREFIX/bin/../x86_64-conda_cos6-linux-gnu/sysroot/usr/lib64 -lGL
#
# Frm conda-build, we have a CDT test that involves OpenGL:
#
# build deps are: pkg-config libxcb libselinux-devel libxi-devel libx11-devel libxau-devel libxext-devel libxfixes-devel mesa-libgl-devel xorg-x11-proto-devel mesa-dri-drivers libxdamage-devel libxxf86vm
#
# echo -e "#include <GL/gl.h>\nint main() { glBegin(GL_TRIANGLES); glEnd(); return 0; }" | ${CC} -o ${PREFIX}/bin/links-to-opengl-cdt -x c $(pkg-config --libs gl) -Wl,-rpath-link,${PREFIX}/lib -
#
# echo -e "#include <GL/gl.h>\nint main() { glBegin(GL_TRIANGLES); glEnd(); return 0; }" > gl.c
# x86_64-conda_cos6-linux-gnu-cc -o links-to-opengl-cdt -x c -L${PREFIX}/bin/../x86_64-conda_cos6-linux-gnu/sysroot/usr/lib64 -lGL -Wl,-rpath-link,${PREFIX}/lib gl.c
#
# pushd /opt/conda/conda-bld/qt-5.15.0_minimal_26/work ; . build_env_setup.sh ; PATH=$PWD:$PATH && cd config.tests/opengl
# g++ -m64 -Wl,-O1 -o opengl main.o   -L$PREFIX/lib -L$BUILD_PREFIX/x86_64-conda_cos6-linux-gnu/sysroot/usr/lib64 -L$BUILD_PREFIX/x86_64-conda_cos6-linux-gnu/sysroot/usr/lib64 -L$BUILD_PREFIX/bin/../x86_64-conda_cos6-linux-gnu/sysroot/usr/lib64 -lGL

    for key in "${!COS6_MISSING_DEFINES[@]}"; do
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
  # -platform linux-g++-64 :: Because of:
  # https://forum.qt.io/topic/78224/opengl-test-failed-when-configure-qt-as-source/5
  #    ..
  #    Note: QtSerialBus: Cannot find linux/can.h and linux/can/raw.h Linux headers for socketCAN support.
  #    
  #    Note: The following modules are not being compiled in this configuration:
  #        3dcore
  #        3drender
  #    
  #    WARNING: No QPA platform plugin enabled! This will
  #    produce a Qt that cannot run GUI applications.
  #    See "Platform backends" in the output of --help.
  #    
  #    ERROR: The OpenGL functionality tests failed!
  #    You might need to modify the include and library search paths by editing QMAKE_INCDIR_OPENGL[_ES2],
  #    QMAKE_LIBDIR_OPENGL[_ES2] and QMAKE_LIBS_OPENGL[_ES2] in the mkspec for your platform.
  if [[ ! -f .status.configure ]]; then
    ./configure -prefix ${PREFIX} \
                -platform linux-g++-64 \
                -libdir ${PREFIX}/lib \
                -bindir ${PREFIX}/bin \
                -headerdir ${PREFIX}/include/qt \
                -archdatadir ${PREFIX} \
                -datadir ${PREFIX} \
                -I ${PREFIX}/include \
                -L ${PREFIX}/lib \
                "${LIBS_NATURE_ARGS[@]}" \
                -opensource \
                -confirm-license \
                -nomake examples \
                -nomake tests \
                -verbose \
                -skip wayland \
                -system-libjpeg \
                -system-libpng \
                -system-zlib \
                -system-sqlite \
                -sql-sqlite \
                -sql-mysql \
                -sql-psql \
                -plugin-sql-sqlite \
                -plugin-sql-mysql \
                -plugin-sql-psql \
                -qt-pcre \
                -xkbcommon \
                -dbus \
                -no-linuxfb \
                -no-libudev \
                -no-avx \
                -no-avx2 \
                -cups \
                -openssl-linked \
                -openssl \
                -Wno-expansion-to-defined \
                "${QT_CONFIGURE_EXTRA_DEFINES[@]}" \
                "${SKIPS[@]}" 2>&1 | tee configure.log
    if fgrep "QDoc will not be compiled" configure.log; then
      echo "ERROR :: Failed to find libclang, I guess."
      exit 1
    fi
    echo "done" > .status.configure
  fi
            
# ltcg bloats a test tar.bz2 from 24524263 to 43257121 (built with the following skips)
#                -ltcg \
#                --disable-new-dtags \

  if [[ ! -f .status.make ]]; then
    # if [[ ${MINIMAL_BUILD} != yes ]]; then
    #   CPATH=$PREFIX/include LD_LIBRARY_PATH=$PREFIX/lib make -j${MAKE_JOBS} module-qtwebengine || exit 1
    #   if find . -name "libQt5WebEngine*so" -exec false {} +; then
    #     echo "Did not build qtwebengine, exiting"
    #     exit 1
    #   fi
    # fi
    CPATH=$PREFIX/include LD_LIBRARY_PATH=$PREFIX/lib make -j${MAKE_JOBS} || exit 1
    echo "done" > .status.make

    # We may as well check all DSOs here. We may as well do that in CB's post.py too.
    DSO_FILES=()
    # find . -type f -name "libQt5WebEngine*so.*" >tmpfile
    find . -type f \( -name "*.o" -or -name "*.so.*" \) >tmpfile
    while IFS=  read -r; do
      DSO_FILES+=("$REPLY")
    done <tmpfile
    rm -f tmpfile
    ANY_BAD=no
    for DSO_FILE in "${DSO_FILES[@]}"; do
      BAD_GLIBCS=()
      # echo "INFO :: libQt5WebEngine.so found at ${libQt5WebEngine_FILE}"
      if [[ ${DSO_FILE} =~ .*.o ]]; then
        NM_DYN=
      else
        NM_DYN=-D
      fi
      ${NM} ${NM_DYN} --with-symbol-versions "${DSO_FILE}" | \
        sed -E 's|(.*)(GLIBC_2.2.*)|\2|gp;d' | \
        sort | uniq | grep -E -v 'GLIBC_2.2.5'>tmpfile || true
      if [[ -f tmpfile ]]; then
        while IFS=  read -r; do
          BAD_GLIBCS+=("$REPLY")
          ANY_BAD=yes
          echo "ERROR ::${DSO_FILE} links to ${REPLY}"
        done <tmpfile
        rm -f tmpfile
      fi
    done
    if [[ ${ANY_BAD} == yes ]]; then
      echo "ERROR :: DSOs are linking to a too-modern glibc. Something was compiled with the wrong compiler."
      exit 1
    fi
  fi
  # if [[ ! -f .status.make-install ]]; then
  make install
  #   echo "done" > .status.make-install
  # fi
elif [[ ${target_platform} == osx-64 ]]; then
  parse_macos_sdk_ver ${CONDA_BUILD_SYSROOT} OSX_SDK_VER OSX_SDK_VER_MAJOR OSX_SDK_VER_MINOR
  printf "INFO :: Parsed ${CONDA_BUILD_SYSROOT} as:\n  OSX_SDK_VER=$OSX_SDK_VER OSX_SDK_VER_MAJOR=$OSX_SDK_VER_MAJOR OSX_SDK_VER_MINOR=$OSX_SDK_VER_MINOR"
  # Because of the use of Objective-C Generics we need at least MacOSX10.11.sdk
  if [[ ${OSX_SDK_VER_MAJOR} -lt 11 ]] && [[ ${OSX_SDK_VER_MINOR} -lt 11 ]]; then
    echo "ERROR: You asked me to use $CONDA_BUILD_SYSROOT as MacOS SDK (maj: ${OSX_SDK_VER_MAJOR} min: ${OSX_SDK_VER_MINOR})"
    echo "         But because of the use of Objective-C Generics we need at \least MacOSX10.11.sdk"
    exit 1
  fi

  # Avoid Xcode
  [[ -f xcrun ]] || cp "${RECIPE_DIR}"/xcrun .
  [[ -f xcodebuild ]] || cp "${RECIPE_DIR}"/xcodebuild .
  [[ -f xcode-select ]] || cp "${RECIPE_DIR}"/xcode-select .
  chmod +x xcrun xcodebuild xcode-select
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
  # [[ -f .status.configure ]] && rm .status.configure
  if [[ ! -f .status.configure ]]; then
    ./configure -prefix $PREFIX \
                -libdir $PREFIX/lib \
                -bindir $PREFIX/bin \
                -headerdir $PREFIX/include/qt \
                -archdatadir $PREFIX \
                -datadir $PREFIX \
                -L $PREFIX/lib \
                -I $PREFIX/include \
                -R $PREFIX/lib \
                "${LIBS_NATURE_ARGS[@]}" \
                -opensource \
                -confirm-license \
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
                -sdk macosx${OSX_SDK_VER} \
                "${SKIPS[@]}" 2>&1 | tee configure.log
    if [[ ${MINIMAL_BUILD} != yes ]]; then
      if fgrep "QDoc will not be compiled" configure.log; then
        echo "ERROR :: Failed to find libclang, I guess."
        exit 1
      fi
    fi
    echo "done" > .status.configure
  fi

  # For quicker turnaround when e.g. checking compilers optimizations
  #                -skip qtwebsockets -skip qtwebchannel -skip qtwebengine -skip qtsvg -skip qtsensors -skip qtcanvas3d -skip qtconnectivity -skip declarative -skip multimedia -skip qttools -skip qtlocation -skip qt3d
  # lto causes an increase in final tar.bz2 size of about 4% (tested with the above -skip options though, not the whole thing)
  #                -ltcg \
  # Just because qtwebengine fails most often, so eek any problems out.
  # [[ -f .status.make ]] && rm .status.make
  if [[ ! -f .status.make ]]; then
    if [[ ${MINIMAL_BUILD} != yes ]]; then
      make -j${MAKE_JOBS} module-qtwebengine || exit 1
      if find . -name "libQt5WebEngine*dylib" -exec false {} +; then
        echo "Did not build qtwebengine, exiting"
        exit 1
      fi
    fi
    make -j${MAKE_JOBS} || exit 1
    echo "done" > .status.make
  fi
  # [[ -f .status.make-install ]] && rm .status.make-install
  if [[ ! -f .status.make-install ]]; then
    # This is race-y on macOS.
    make -j${MAKE_JOBS} install || make install || make install || exit 1
    echo "done" > .status.make-install
  fi

  # Avoid Xcode (2)
  mkdir -p "${PREFIX}"/bin/xc-avoidance || true
  cp "${RECIPE_DIR}"/xcrun "${PREFIX}"/bin/xc-avoidance/
  cp "${RECIPE_DIR}"/xcodebuild "${PREFIX}"/bin/xc-avoidance/
fi


# Qt Charts
# ---------
pushd qtcharts
  ${PREFIX}/bin/qmake qtcharts.pro PREFIX=${PREFIX}
  make
  make install
popd


# Post build setup
# ----------------
pushd "${PREFIX}"/lib > /dev/null
    echo "WARNING :: Removing the following static libraries as they are not part of the Qt SDK."
    find . -name "*.a" -and -not -name "libQt*" -exec echo {} \;
    find . -name "*.a" -and -not -name "libQt*" -exec rm -f {} \; || true
popd > /dev/null

# Add qt.conf file to the package to make it fully relocatable
cp "${RECIPE_DIR}"/qt.conf "${PREFIX}"/bin/

if [[ ${target_platform} == osx-64 ]]; then
  pushd ${PREFIX}
    # We built Qt itself with SDK 10.10, but we shouldn't
    # force users to also build their Qt apps with SDK 10.10
    # https://bugreports.qt.io/browse/QTBUG-41238
    [[ -f mkspecs/qdevice.pri ]] && sed -i '' 's/macosx.*$/macosx/g' mkspecs/qdevice.pri
    # We allow macOS SDK 10.12 while upstream requires 10.13 (as of Qt 5.12.1).
    sed -i '' "s/QT_MAC_SDK_VERSION_MIN = 10\..*/QT_MAC_SDK_VERSION_MIN = ${OSX_SDK_VER_MAJOR}\.${OSX_SDK_VER_MINOR}/g" mkspecs/common/macx.conf
    # We may want to replace these with \$\${QMAKE_MAC_SDK_PATH}/ instead?
    sed -i '' "s|${CONDA_BUILD_SYSROOT}/|/|g" mkspecs/modules/*.pri
    CMAKE_FILES=$(find lib/cmake -name "Qt*.cmake")
    for CMAKE_FILE in ${CMAKE_FILES}; do
      sed -i '' "s|${CONDA_BUILD_SYSROOT}/|\${CMAKE_OSX_SYSROOT}/|g" ${CMAKE_FILE}
    done
  popd
fi

# We will set CONDA_BUILD_SYSROOT even on Linux so that all of this works OK. This is probably a feature that conda-build could perform
# for us (both setting CONDA_BUILD_SYSROOT on Linux and doing these specific replacements, ping @msarahan,

if [[ ${target_platform} =~ .*inux.* ]]; then
  CB_SYSROOT_SUF=$(basename $(dirname $("${CC}" -print-sysroot)))/$(basename $("${CC}" -print-sysroot))
else
  CB_SYSROOT_SUF=${CONDA_BUILD_SYSROOT:-${CC} -print-sysroot}
fi
echo "CB_SYSROOT_SUF=${CB_SYSROOT_SUF}"

if [[ 0 == 1 ]]; then
pushd ${PREFIX}
  SYSROOT_FILES=()
  find . -name "*.cmake" -or -name "*.prl" -or -name "*.pc" -or -name "*.pri" >tmpfile
  while IFS=  read -r; do
    SYSROOT_FILES+=("$REPLY")
  done <tmpfile
  rm -f tmpfile
  echo "SYSROOT_FILES is " "${SYSROOT_FILES[@]}"
  for _SYSROOT_FILE in "${SYSROOT_FILES[@]}"; do
    echo "INFO :: hmm, sysroot found in ${_SYSROOT_FILE}"
    case ${_SYSROOT_FILE} in
      *.pri|*.prl)
        SED_REPLACER="s|[^ ]+/[^ \"]*${CB_SYSROOT_SUF}\"?|\$\$\(CONDA_BUILD_SYSROOT\)|g"
        ;;
      *.cmake)
        SED_REPLACER="s|[^ ]+/[^ \"].*${CB_SYSROOT_SUF}[ \"]|\$ENV{CONDA_BUILD_SYSROOT}|g"
        ;;
      # Because we pass this to pkg-config as `--define-variable=CONDA_BUILD_SYSROOT=<something>` and this cannot handle an empty something
      # we also pass in the leading slash, that when CONDA_BUILD_SYSROOT is empty a single '/' is passed and pkg-config is not sad.
      *.pc)
        SED_REPLACER="s|[^ ]+/[^ \"]*${CB_SYSROOT_SUF}\/\"?|\${CONDA_BUILD_SYSROOT_S}\/|g"
        ;;
    esac
    # Dry-run.
    # cat "${_SYSROOT_FILE}" | sed -E "${SED_REPLACER}" | grep CONDA_BUILD_SYSROOT
    # Do-it (good luck!)
    echo "sed -i.bak -E ${SED_REPLACER} ${_SYSROOT_FILE}"
    sed -i.bak -E "${SED_REPLACER}" "${_SYSROOT_FILE}" || true
    rm -f ${_SYSROOT_FILE}.bak
  done
popd
fi


LICENSE_DIR="$PREFIX/share/qt/3rd_party_licenses"
    find . -name "*.a" -and -not -name "libQt*" -exec echo {} \;

for f in $(find * \
  \( -iname "*LICENSE*" -or -iname "*COPYING*" -or -iname "*COPYRIGHT*" -or -iname "NOTICE" \) \
    -and -not \
  \( -ipath "*examples*" -or -name "*.h" -or -name "*.js" -or -name "*.o" \) ); do
  mkdir -p "$LICENSE_DIR/$(dirname $f)"
  cp -rf $f "$LICENSE_DIR/$f"
  rm -rf "$LICENSE_DIR/qtbase/examples/widgets/dialogs/licensewizard"
  rm -rf "$LICENSE_DIR/qtwebengine/src/3rdparty/chromium/tools/checklicenses"
  rm -rf "$LICENSE_DIR/qtwebengine/src/3rdparty/chromium/third_party/skia/tools/copyright"
done
