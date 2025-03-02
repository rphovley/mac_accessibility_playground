#! /bin/bash

clang -o app_switch_detector bindings/app_switch_detector.m -framework Cocoa -framework ApplicationServices -fobjc-arc
./app_switch_detector