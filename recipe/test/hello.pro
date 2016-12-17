QT       += core
QT       -= gui
TARGET = hello
CONFIG   += console
CONFIG   -= app_bundle
TEMPLATE = app
SOURCES += main.cpp

# this is set in the qmake.conf for macx-clang-c++, but gets forgotten
# somehow
macx {
    QMAKE_LFLAGS_RPATH = "-Xlinker -rpath "
}

# so it can find the Qt libraries
QMAKE_RPATHDIR += $$(PREFIX)/lib
