#! /bin/bash

clang -o monitor monitor.m -framework Cocoa -framework ApplicationServices -fobjc-arc
./monitor