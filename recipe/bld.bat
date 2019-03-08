set INCLUDE=%LIBRARY_INC%;%INCLUDE%
set LIB=%LIBRARY_LIB%;%LIB%

:: For some reason configure.exe is deleted on AppVeyor. Virus check?
:: Anyway, it has been added to the recipe so copy it if it doesn't exist
if not exist configure.exe (
    copy %RECIPE_DIR%\configure.exe .
)

echo y | configure.exe -prefix %LIBRARY_PREFIX% ^
                       -libdir %LIBRARY_LIB% ^
                       -bindir %LIBRARY_BIN% ^
                       -headerdir %LIBRARY_INC%\qt ^
                       -datadir %LIBRARY_PREFIX% ^
                       -release ^
                       -shared ^
                       -opensource ^
                       -fast ^
                       -no-qt3support ^
                       -nomake examples ^
                       -nomake demos ^
                       -nomake docs ^
                       -openssl ^
                       -webkit ^
                       -nomake examples ^
                       -nomake tests ^
                       -system-zlib ^
                       -system-libpng ^
                       -L %LIBRARY_LIB% ^
                       -I %LIBRARY_INC% ^
                       -system-libjpeg ^
                       -qt-libtiff ^
                       -platform win32-msvc%VS_YEAR%


bin\qmake -r QT_BUILD_PARTS="libs tools"

jom -j%CPU_COUNT%
if errorlevel 1 exit 1
nmake install
if errorlevel 1 exit 1

:: To rewrite qt.conf contents per conda environment
copy "%RECIPE_DIR%\write_qtconf.bat" "%PREFIX%\Scripts\.qt-post-link.bat"
if errorlevel 1 exit /b 1
FOR /F "tokens=1,2 delims==" %%i IN ('msvc_versions.bat') DO echo %CL_TEXT% | findstr /C:"Version %%i" > nul && set VSTRING=%%j && goto FOUND
EXIT 1
:FOUND

mkdir %LIBRARY_PREFIX%\mkspecs\win32-msvc-default
copy %LIBRARY_PREFIX%\mkspecs\win32-msvc%VS_YEAR%\* %LIBRARY_PREFIX%\mkspecs\win32-msvc-default\

copy "%RECIPE_DIR%\write_qtconf.bat" "%PREFIX%\Scripts\.qt-post-link.bat"
