#! /bin/bash

clang -o observers observers.m -framework Cocoa -framework ApplicationServices -fobjc-arc
./observers