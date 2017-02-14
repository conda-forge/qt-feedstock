
:: Add the gnuwin32 tools to PATH - needed for webkit
:: Ruby is also needed but this is supplied by AppVeyor
set PATH=%cd%\gnuwin32\bin;%PATH%

:: Webkit is not part of the distributed Qt5 tarballs anymore in 5.6 or after. 
:: You need to download it separately and move it to the build directory by yourself. 
set SHORT_VERSION=%PKG_VERSION:~0,-2%
if "%DIRTY%" == "" (
    :: TODO: checksum
    curl -LO "http://download.qt.io/community_releases/%SHORT_VERSION%/%PKG_VERSION%/qtwebkit-opensource-src-%PKG_VERSION%.tar.xz"
    if errorlevel 1 exit 1
    7za x -so qtwebkit-opensource-src-%PKG_VERSION%.tar.xz | 7za x -si -aoa -ttar > NUL 2>&1
    if errorlevel 1 exit 1
    move qtwebkit-opensource-src-%PKG_VERSION% qtwebkit
    if errorlevel 1 exit 1
)

set "INCLUDE=%LIBRARY_INC%;%INCLUDE%"
set "LIB=%LIBRARY_LIB%;%LIB%"

:: We use '-opengl desktop'. Other options need DirectX SDK or Angle (C++11 only)

:: this needs to be CALLed due to an exit statement at the end of configure:
call configure ^
     -prefix %LIBRARY_PREFIX% ^
     -libdir %LIBRARY_LIB% ^
     -bindir %LIBRARY_BIN% ^
     -headerdir %LIBRARY_INC%\qt ^
     -archdatadir %LIBRARY_PREFIX% ^
     -datadir %LIBRARY_PREFIX% ^
     -L %LIBRARY_LIB% ^
     -I %LIBRARY_INC% ^
     -confirm-license ^
     -no-fontconfig ^
     -icu ^
     -no-separate-debug-info ^
     -no-warnings-are-errors ^
     -nomake examples ^
     -nomake tests ^
     -no-warnings-are-errors ^
     -opengl desktop ^
     -opensource ^
     -openssl ^
     -platform win32-msvc%VS_YEAR% ^
     -release ^
     -shared ^
     -qt-freetype ^
     -system-libjpeg ^
     -system-libpng ^
     -system-zlib ^
     -mp
if errorlevel 1 exit /b 1

:: re-enable echoing which is disabled by configure
echo on
     
:: Note - webengine only built when you ask (nmake module-webengine) - so we can skip it easily.
     
nmake Release
if errorlevel 1 exit /b 1

nmake install
if errorlevel 1 exit /b 1
     
:: To rewrite qt.conf contents per conda environment
copy "%RECIPE_DIR%\write_qtconf.bat" "%PREFIX%\Scripts\.qt-post-link.bat"
if errorlevel 1 exit /b 1

