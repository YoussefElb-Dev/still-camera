import 'dart:convert';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:still_camera/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Native camera captures a processed photo and persists the library',
    (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'settings',
        jsonEncode({
          'saveToGallery': false,
          'lookId': 'sv10',
          'highResolution': true,
          'sound': false,
        }),
      );
      await tester.pumpWidget(const StillApp());
      final deadline = DateTime.now().add(const Duration(seconds: 45));
      while (find.byType(CameraPreview).evaluate().isEmpty &&
          DateTime.now().isBefore(deadline)) {
        await tester.pump(const Duration(milliseconds: 500));
      }
      expect(
        find.byType(CameraPreview),
        findsOneWidget,
        reason:
            'Native camera must initialize; grant CAMERA to the QA emulator before running.',
      );
      await tester.tap(find.bySemanticsLabel('Take photo'));
      await tester.pump();
      final dir = Directory(
        '${(await getApplicationDocumentsDirectory()).path}/Still',
      );
      final index = File('${dir.path}/library.json');
      final saveDeadline = DateTime.now().add(const Duration(seconds: 45));
      while (!await index.exists() && DateTime.now().isBefore(saveDeadline)) {
        await tester.pump(const Duration(milliseconds: 500));
      }
      expect(await index.exists(), true);
      final photos = jsonDecode(await index.readAsString()) as List;
      expect(photos, isNotEmpty);
      expect(photos.first['look'], 'SV10');
      expect(photos.first['width'], greaterThan(0));
      expect(photos.first['height'], greaterThan(0));
      expect(
        await File('${dir.path}/${photos.first['path']}').length(),
        greaterThan(1000),
      );
      await tester.tap(find.bySemanticsLabel('Open photo library'));
      await tester.pumpAndSettle();
      expect(find.text('Your little time capsule.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
