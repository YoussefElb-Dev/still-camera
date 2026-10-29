# Still Camera builds

This is a native Flutter application with Android and iOS projects. It does not wrap a website. All camera effects run locally; there is no backend, account, subscription, advertising SDK, or paid filter service.

## Android

Use Flutter 3.47.8 (Dart 3.13), JDK 21, and the Android SDK. The Flutter build installs missing SDK components when their licenses have been accepted. Run `scripts/build-android.ps1` on Windows, or `flutter pub get && flutter build apk --release` on another development system.

The resulting APK is `build/app/outputs/flutter-apk/app-release.apk`. It is installable directly on an Android phone. The current Gradle configuration uses the development signing key for a directly installable personal build. Preserve that key for future updates; Play Store publishing should use your own release keystore. Cloud builds use the runner’s development key, so they cannot update a locally signed installation without uninstalling first.

## iPhone

An IPA contains a compiled iOS application, so compilation requires macOS and Xcode. A Windows machine cannot compile it with the Android toolchain.

The included **Build APK and IPA** GitHub Actions workflow builds on a macOS runner and produces `Still-Camera-unsigned.ipa`. You can also run `bash scripts/build-ios.sh` on a Mac. The IPA is compiled for real ARM64 iPhones, not the simulator.

The public source repository is [YoussefElb-Dev/still-camera](https://github.com/YoussefElb-Dev/still-camera). Standard GitHub-hosted runners are [free for public repositories](https://docs.github.com/en/billing/concepts/product-billing/github-actions).

After downloading the IPA, `python scripts/verify-ipa.py Still-Camera-unsigned.ipa` checks the archive integrity, expected app identifier, camera permission descriptions, physical-device platform, and ARM64 app/framework binaries. This requires Python 3.11 or newer and uses only its standard library.

An **unsigned IPA is not directly installable**. Sign it with your Apple account using a sideloading tool such as Sideloadly or AltStore, or open `ios/Runner.xcworkspace` in Xcode and use your own development team. This app does not require a paid developer account for personal testing; Apple’s personal-signing restrictions still apply. App Store or TestFlight distribution requires the appropriate Apple developer enrollment and provisioning. No Apple credentials are stored in this project.

To produce an Apple-distribution IPA on a configured Mac, set the Runner signing team and bundle identifier in Xcode, then run `flutter build ipa`. See [Flutter’s iOS release guide](https://docs.flutter.dev/deployment/ios).

## Validate

```text
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

The tests cover resolution preservation, 1600-pixel export without upscaling, square cropping, borders in exported JPEGs, original-copy cleanup, persistent library reloads, settings, and camera-screen interactions at 390 × 844 and 360 × 640. They also export review images to `artifacts/previews` and render the original camera illustration into launcher icons. The SDK path used by Windows must not contain spaces; this workspace has a local junction at `C:\Users\youss\.cache\still-camera-flutter` for that purpose.

Preview-only launch: `flutter run --dart-define=DEMO_MODE=true`. Production builds default to a real native camera, not demo mode.

## Device verification still matters

Maximum resolution, flash, focus, and zoom depend on the selected physical camera and OS. `ResolutionPreset.max` requests the highest resolution exposed by the camera plugin; it does not promise a specific megapixel count or access to a phone’s proprietary RAW/48 MP mode. The Original look adds no vintage color transform. The other looks keep their vintage processing at both resolutions. High-resolution exports do not upscale a source photo. A square camera crops to a square; an enabled border overlays the photo edges.

The live viewfinder uses the camera texture plus the same color matrix and overlay painter as export. Grain density scales for the final image. The Night control is a +0.7 EV exposure boost, not a multi-exposure night-photography mode. The V/VHS/M24 camera names describe photo looks inspired by video cameras; this version captures still photographs.
