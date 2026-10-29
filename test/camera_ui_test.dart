import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:still_camera/models/camera_look.dart';
import 'package:still_camera/main.dart';
import 'package:still_camera/widgets/camera_body.dart';

void main() {
  final previewKey = GlobalKey();
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await (FontLoader(
      'StillSans',
    )..addFont(rootBundle.load('assets/fonts/StillSans-Regular.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    await (FontLoader(
      'monospace',
    )..addFont(rootBundle.load('assets/fonts/StillSans-Regular.ttf'))).load();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));
  Future<void> launch(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      RepaintBoundary(key: previewKey, child: const StillApp(demo: true)),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> screenshot(WidgetTester tester, String name) async {
    await tester.runAsync(() async {
      final boundary =
          previewKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory('artifacts/previews').create(recursive: true);
      await File(
        'artifacts/previews/$name.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets('Camera, picker, selection, and settings match phone sizes', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await launch(tester, const Size(390, 844));
    expect(find.bySemanticsLabel('Take photo'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await screenshot(tester, 'camera');
    await tester.tap(find.bySemanticsLabel('Choose camera'));
    await tester.pumpAndSettle();
    expect(find.text('Inst Sqc'), findsOneWidget);
    expect(find.text('SV10'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await screenshot(tester, 'camera-picker');
    await tester.tap(find.text('SV10'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Close camera picker'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Camera settings'));
    await tester.pumpAndSettle();
    expect(find.text('High resolution'), findsOneWidget);
    expect(find.text('Save to Photos'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await screenshot(tester, 'settings');
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
  testWidgets('Small phone controls do not overflow', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await launch(tester, const Size(360, 640));
    expect(tester.takeException(), isNull);
    await tester.tap(find.bySemanticsLabel('Choose camera'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
  testWidgets('Render original native app icons', (tester) async {
    final key = GlobalKey();
    tester.view.physicalSize = const Size(1024, 1024);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: RepaintBoundary(
          key: key,
          child: Container(
            color: const Color(0xff161714),
            alignment: Alignment.center,
            child: CameraIllustration(cameraLooks[5], size: 820),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      Future<void> write(String path, int size) async {
        final image = await boundary.toImage(pixelRatio: size / 1024);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final rgb = img
            .decodePng(bytes!.buffer.asUint8List())!
            .convert(numChannels: 3);
        await File(path).writeAsBytes(img.encodePng(rgb));
        image.dispose();
      }

      for (final entry in {
        'mdpi': 48,
        'hdpi': 72,
        'xhdpi': 96,
        'xxhdpi': 144,
        'xxxhdpi': 192,
      }.entries) {
        await write(
          'android/app/src/main/res/mipmap-${entry.key}/ic_launcher.png',
          entry.value,
        );
      }
      final dir = Directory('ios/Runner/Assets.xcassets/AppIcon.appiconset');
      for (final file in dir.listSync().whereType<File>().where(
        (f) => f.path.endsWith('.png'),
      )) {
        final name = file.uri.pathSegments.last;
        final match = RegExp(
          r'Icon-App-([0-9.]+)x[0-9.]+@([123])x',
        ).firstMatch(name)!;
        await write(
          file.path,
          (double.parse(match.group(1)!) * int.parse(match.group(2)!)).round(),
        );
      }
    });
  });
}
