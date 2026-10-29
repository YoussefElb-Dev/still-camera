import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:still_camera/models/camera_look.dart';
import 'package:still_camera/services/photo_library.dart';
import 'package:still_camera/services/photo_processor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Uint8List source;
  setUpAll(() {
    final image = img.Image(width: 2048, height: 1536);
    img.fill(image, color: img.ColorRgb8(150, 125, 100));
    source = Uint8List.fromList(img.encodeJpg(image));
  });
  test('Original color transform is identity and each preset is valid', () {
    expect(lookMatrix(cameraLooks[7]), identityMatrix);
    for (final look in cameraLooks) {
      expect(lookMatrix(look).length, 20);
      expect(lookMatrix(look).every((v) => v.isFinite), true);
      expect(lookMatrix(look, strength: 0), identityMatrix);
    }
  });
  testWidgets(
    'High resolution retains input pixels; retro mode scales without upscaling',
    (tester) async {
      await tester.runAsync(() async {
        final settings = PhotoSettings(
          lookId: 'original',
          border: false,
          grain: false,
        );
        final high = await processPhoto(source, settings);
        expect((high.width, high.height), (2048, 1536));
        final decoded = img.decodeJpg(high.bytes)!;
        expect(decoded.getPixel(1024, 768).r, closeTo(150, 4));
        settings.highResolution = false;
        final retro = await processPhoto(source, settings);
        expect((retro.width, retro.height), (1600, 1200));
        final small = Uint8List.fromList(
          img.encodePng(img.Image(width: 320, height: 240)),
        );
        final kept = await processPhoto(small, settings);
        expect((kept.width, kept.height), (320, 240));
      });
    },
  );
  testWidgets('Square crop and instant border are baked into JPEG', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final output = await processPhoto(
        source,
        PhotoSettings(lookId: 'inst-sqc', border: true, grain: false),
      );
      expect((output.width, output.height), (1536, 1536));
      final decoded = img.decodeJpg(output.bytes)!;
      expect(decoded.getPixel(4, 4).r, greaterThan(230));
      expect(decoded.getPixel(4, 4).b, greaterThan(215));
      expect(decoded.getPixel(768, 768).r, lessThan(200));
    });
  });
  test('Library survives reload and deletes matching original only', () async {
    final dir = await Directory.systemTemp.createTemp('still-library-test-');
    try {
      final library = PhotoLibrary(directory: dir);
      final settings = PhotoSettings(saveOriginal: true, saveToGallery: false);
      final photo = await library.save(
        source,
        settings,
        2048,
        1536,
        original: source,
      );
      final original = File(
        photo.path.replaceFirst(RegExp(r'_[^_]+\.jpg$'), '_original.jpg'),
      );
      expect(await original.exists(), true);
      final reloaded = PhotoLibrary(directory: dir);
      await reloaded.load();
      expect(reloaded.photos.length, 1);
      expect(await File(reloaded.photos.single.path).exists(), true);
      await reloaded.delete(reloaded.photos.single);
      expect(await File(photo.path).exists(), false);
      expect(await original.exists(), false);
      final empty = PhotoLibrary(directory: dir);
      await empty.load();
      expect(empty.photos, isEmpty);
    } finally {
      await dir.delete(recursive: true);
    }
  });
  test(
    'Settings preserve high resolution and creative controls across reload',
    () {
      final before = PhotoSettings(
        lookId: 'sv10',
        highResolution: false,
        warmth: .4,
        exposure: .6,
        effect: 2,
        dateStamp: true,
      );
      final after = PhotoSettings.fromJson(before.toJson());
      expect(after.toJson(), before.toJson());
      expect(after.look.id, 'sv10');
    },
  );
}
