#!/usr/bin/env bash

set -euo pipefail

flutter pub get

if ! dart format --set-exit-if-changed .; then
  echo "::warning title=Formatting::代码未通过 dart format；请运行 dart format ."
else
  echo "::notice title=Formatting::代码已通过 dart format。"
fi

if ! flutter analyze; then
  echo "::warning title=Static analysis::flutter analyze 发现问题，请查看日志。"
else
  echo "::notice title=Static analysis::flutter analyze 未发现异常。"
fi

shopt -s nullglob globstar
dart_tests=(test/**/*.dart)
if (( ${#dart_tests[@]} > 0 )); then
  flutter test
fi

python3 -m unittest discover -s pybuilds/tests -v
