#! /bin/bash

clang -o border_test bindings/border_test.m -framework Cocoa -framework ApplicationServices -fobjc-arc
./border_test