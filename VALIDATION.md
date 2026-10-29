# Validation — 28 October 2026

- Flutter 3.47.8 / Dart 3.13.7 on Windows.
- Static analysis: no issues.
- Eight unit/widget checks passed, covering image resolution, JPEG output, square crops, instant frames, original copies, library persistence, settings, and phone layouts.
- Native Android camera integration test passed on an Android 15 / API 35 emulator: initialize camera, capture, process, persist, and display in the library.
- Final release APK built, APK v2 signature verified, installed, and launched with the live native camera. A shutter capture exported a 1392 × 1856 JPEG to the emulator’s system Pictures library. This is the emulator camera’s output, not a promise about a physical phone’s sensor resolution.
- Android uses Skia for stable camera-texture compositing on software GL devices. The emulator’s Impeller renderer exited during earlier camera checks; the final package uses the renderer that passed the camera test.
- Android APK supports API 24+ and includes arm64-v8a, armeabi-v7a, and x86_64 architectures. It is a personal build signed with the development key, as described in BUILDING.md.
- The iOS project and macOS GitHub Actions IPA workflow are included. No iOS binary has been compiled or signed in this Windows workspace. Physical iPhone verification remains outstanding.
