pushd test
if exist .qmake.stash del /a .qmake.stash
if exist hello-minimal.pro (
    qmake hello-minimal.pro
) else (
    qmake hello.pro
)
if %ErrorLevel% neq 0 exit /b 1
nmake
if %ErrorLevel% neq 0 exit /b 1
:: Only test that this builds
nmake clean
if %ErrorLevel% neq 0 exit /b 1
if exist qtwebengine.pro (
  qmake qtwebengine.pro
  if %ErrorLevel% neq 0 exit /b 1
  nmake
  if %ErrorLevel% neq 0 exit /b 1
  popd
)
