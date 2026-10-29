#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
flutter pub get
flutter build ios --release --no-codesign
mkdir -p build/ipa/Payload
cp -R build/ios/iphoneos/Runner.app build/ipa/Payload/Still.app
(cd build/ipa && zip -q -r -y Still-Camera-unsigned.ipa Payload)
printf 'Built: build/ipa/Still-Camera-unsigned.ipa\nThis IPA requires signing with your Apple account before installation.\n'
