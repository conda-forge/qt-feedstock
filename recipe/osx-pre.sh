#!/bin/bash

for _name in Assistant Designer Linguist pixeltool qml; do
    rm -r ${PREFIX}/bin/${_name}.app
done
