
:: Check we have Ruby (should be installed on AppVeyor)
where ruby

:: Add the gnuwin32 tools to PATH
set PATH=%cd%\gnuwin32\bin;%PATH%

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
     
:: Note - webengine only built when you ask (nmake module-webengine) - so we can skip it easily.
     
nmake Release
if errorlevel 1 exit /b 1

nmake install
if errorlevel 1 exit /b 1
     
:: To rewrite qt.conf contents per conda environment
copy "%RECIPE_DIR%\write_qtconf.bat" "%PREFIX%\Scripts\.qt-post-link.bat"
if errorlevel 1 exit /b 1

