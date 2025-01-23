#! /bin/bash

clang -o regex regex.m -framework Cocoa -framework ApplicationServices -fobjc-arc
./regex