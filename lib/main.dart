import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'screens/camera_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'Roboto',
    ], await rootBundle.loadString('assets/fonts/LICENSE.txt'));
  });
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const StillApp());
}

class StillApp extends StatelessWidget {
  final bool demo;
  const StillApp({
    super.key,
    this.demo = const bool.fromEnvironment('DEMO_MODE'),
  });
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Still Camera',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: Colors.black,
      colorScheme: const ColorScheme.dark(
        primary: Color(0xffe8cf39),
        surface: Color(0xff171717),
      ),
      fontFamily: 'StillSans',
      useMaterial3: true,
      sliderTheme: const SliderThemeData(
        trackHeight: 2,
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 7),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Color(0xff151515),
        showDragHandle: true,
        dragHandleColor: Color(0xff484848),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Color(0xff333333),
        contentTextStyle: TextStyle(color: Colors.white),
      ),
    ),
    home: CameraScreen(demo: demo),
  );
}
