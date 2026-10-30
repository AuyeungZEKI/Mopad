#!/bin/zsh
# 运行手势识别仿真测试（不需要权限，不会产生真实点击）
set -euo pipefail
ROOT="${0:A:h:h}"
OUT="$(mktemp -d)/mopad-tests"
SOURCES=("${(@f)$(ls "$ROOT"/Sources/*.swift | grep -v '/App.swift$')}")

swiftc -swift-version 5 -parse-as-library \
  -import-objc-header "$ROOT/Sources/Bridge.h" \
  -framework AppKit -framework SwiftUI -framework IOKit -framework ServiceManagement \
  "${SOURCES[@]}" "$ROOT/Tests/GestureSimulation.swift" -o "$OUT"

"$OUT"
