#! /bin/bash

clang -o browser_controller browser_controller.m -framework Cocoa -framework ApplicationServices -fobjc-arc
./browser_controller