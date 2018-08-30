pushd test
qmake hello.pro
nmake
hello
:: Only test that this builds
nmake clean
qmake qtwebengine.pro
nmake
popd
