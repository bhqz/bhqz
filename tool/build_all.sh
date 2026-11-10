#!/usr/bin/env bash
set -euo pipefail
flutter pub get
flutter build apk --release
flutter build windows --release
# Must be run on macOS with Xcode installed and signing configured.
if [[ "$(uname -s)" == "Darwin" ]]; then
  dart run flutter_vless:setup_macos_vpn
  flutter build macos --release
else
  echo 'macOS 构建需要在 macOS + Xcode 环境中运行。' >&2
fi
