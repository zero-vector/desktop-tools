#!/bin/bash

APP=d-toggle-win
CXX=dmd
#CXX=ldc2

FILES=(`find ./src -name "*.d"`)

rm ./$APP

if [[ "$CXX" == "ldc2" ]]; then
    $CXX ${FILES[*]} -m64 -of$APP -O -release
    #-nogc -betterC
else
    $CXX ${FILES[*]} -m64 -of$APP -g
fi
