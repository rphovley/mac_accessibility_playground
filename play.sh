#! /bin/bash

clang -o play Play.m -framework Cocoa -framework ApplicationServices -fobjc-arc
./play