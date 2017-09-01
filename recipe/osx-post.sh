#!/bin/bash

for _name in Assistant Designer Linguist pixeltool qml; do
    # remove old .app if it exists
    rm -rf ${PREFIX}/bin/${_name}.app
    # rename (breaking link)
    cp -r ${PREFIX}/bin/${_name}app $PREFIX/bin/${_name}.app
    rm -r ${PREFIX}/bin/${_name}app
done
