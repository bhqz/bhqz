#!/usr/bin/env bash
set -euo pipefail
# Generate standard platform runners while preserving the app source.
cp pubspec.yaml /tmp/fnyun_pubspec.yaml
cp lib/main.dart /tmp/fnyun_main.dart
flutter create --project-name fnyun_client --org com.fnyun --platforms android,windows,macos .
cp /tmp/fnyun_pubspec.yaml pubspec.yaml
cp /tmp/fnyun_main.dart lib/main.dart
flutter pub get
