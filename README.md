# Still Camera

A free native camera for iPhone and Android, built around the two supplied visual references. Black camera chrome, a rounded-square shutter, an illustrated two-row camera picker, and no premium banner or locked effects.

## Included

- Ten camera looks: Inst, Inst Sqc, Inst SQ, Original, Original V, SV10, SV10 V, FunS V, M24, and VHS.
- Live vintage color, film grain, vignettes, light leaks, starlight, blue bloom, optional instant frames, and date stamps.
- Full resolution by default, with a separate 1600-pixel retro export option.
- Front/rear switching, supported-device flash, tap focus, zoom, warmth, exposure, intensity, composition grid, and 3/10-second self timers.
- Import a photo and apply the same effects at its original resolution.
- A persistent local photo library with zoom, share, save to Photos, and delete.
- Optional untouched originals, mirrored selfies, shutter feedback, and saved preferences.

No ads, subscriptions, in-app purchases, server, analytics SDK, or account. Photos are processed and stored on the device. Sharing only happens when the user selects Share.

## Build and install

See [BUILDING.md](BUILDING.md) for Android APK and iPhone IPA instructions, signing requirements, verification, and device-dependent camera limits. The repository includes an APK/IPA GitHub Actions workflow and local build scripts. iOS binaries require a Mac build and Apple signing before installation.

## Implementation

Flutter 3.47.8 / Dart 3.13. Native camera capture uses the official Flutter camera plugin. The live viewfinder and export share a color matrix and film-overlay painter. Output is JPEG at quality 97 with full chroma resolution. High-resolution mode retains source dimensions instead of artificially upscaling. Instant-square looks crop to a square.

The application is a still-photo camera. Video-inspired preset names describe visual looks, not video-recording features.

## Credits

Camera illustrations are original vector artwork rendered by the app. The [bundled demonstration photo](https://images.unsplash.com/photo-1470770841072-f978cf4d019e) is from Unsplash’s public image CDN; it is explicitly labeled Sample Preview when used. It is not a user photo. Roboto is included under its bundled license in `assets/fonts/LICENSE.txt`. Third-party Flutter dependencies retain their respective licenses.
