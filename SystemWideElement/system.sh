#! /bin/bash

clang -o system system.m -framework Cocoa -framework ApplicationServices -fobjc-arc
./system