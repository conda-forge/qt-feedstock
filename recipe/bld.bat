
:: TODO: OpenGL
set "INCLUDE=%LIBRARY_INC%;%INCLUDE%"
set "LIB=%LIBRARY_LIB%;%LIB%"

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
     
:: Note - webengine only built when you ask - so we can skip it easily.
     
::jom -U Release -j%CPU_COUNT%
nmake -U Release
if errorlevel 1 exit /b 1

::jom -U install -j%CPU_COUNT%
nmake -U install
if errorlevel 1 exit /b 1
     
:: To rewrite qt.conf contents per conda environment
copy "%RECIPE_DIR%\write_qtconf.bat" "%PREFIX%\Scripts\.qt-post-link.bat"
if errorlevel 1 exit /b 1

