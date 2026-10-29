import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/camera_look.dart';
import '../services/photo_library.dart';
import '../services/photo_processor.dart';
import '../widgets/camera_body.dart';
import 'library_screen.dart';
import 'settings_sheet.dart';

const _yellow = Color(0xffe7cc2d);

class CameraScreen extends StatefulWidget {
  final bool demo;
  const CameraScreen({super.key, this.demo = false});
  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  PhotoSettings settings = PhotoSettings();
  final library = PhotoLibrary();
  CameraController? camera;
  Future<void>? cameraDisposal;
  bool startingCamera = false;
  List<CameraDescription> cameras = [];
  CameraLensDirection facing = CameraLensDirection.back;
  bool loading = true,
      busy = false,
      picker = false,
      flash = false,
      night = false,
      favoritesOnly = false,
      listMode = false,
      sample = false,
      shutterFlash = false;
  final Set<String> favorites = {};
  int generation = 0, countdown = 0, captureToken = 0;
  String? cameraError, panel;
  double zoom = 1, minZoom = 1, maxZoom = 1;
  Offset? focus;
  Timer? focusTimer, saveTimer;
  SharedPreferences? prefs;
  bool get previewSample => widget.demo || sample;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  Future<void> _load() async {
    prefs = await SharedPreferences.getInstance();
    try {
      final data = prefs!.getString('settings');
      if (data != null) {
        settings = PhotoSettings.fromJson(
          jsonDecode(data) as Map<String, dynamic>,
        );
      }
    } catch (_) {
      /* Use safe defaults if settings are damaged. */
    }
    favorites.addAll(prefs!.getStringList('favorites') ?? []);
    if (!widget.demo) {
      await library.load();
    }
    if (!mounted) {
      return;
    }
    setState(() => loading = !widget.demo);
    if (!widget.demo) {
      await _startCamera();
    }
  }

  void changed() {
    if (mounted) {
      setState(() {});
    }
    saveTimer?.cancel();
    saveTimer = Timer(const Duration(milliseconds: 200), () {
      prefs?.setString('settings', jsonEncode(settings.toJson()));
      prefs?.setStringList('favorites', favorites.toList());
    });
  }

  void message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(text), duration: const Duration(seconds: 3)),
      );
    }
  }

  Future<void> _startCamera() async {
    if (startingCamera || !mounted) {
      return;
    }
    startingCamera = true;
    final id = ++generation;
    final old = camera;
    camera = null;
    if (mounted) {
      setState(() {
        loading = true;
        cameraError = null;
        flash = false;
      });
    }
    CameraController? next;
    try {
      await cameraDisposal;
      cameraDisposal = null;
      await old?.dispose();
      if (cameras.isEmpty) {
        cameras = await availableCameras();
      }
      if (cameras.isEmpty) {
        throw CameraException(
          'NoCamera',
          'No camera was found on this device.',
        );
      }
      final description = cameras.firstWhere(
        (c) => c.lensDirection == facing,
        orElse: () => cameras.first,
      );
      facing = description.lensDirection;
      next = CameraController(
        description,
        ResolutionPreset.max,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await next.initialize();
      await next.lockCaptureOrientation(DeviceOrientation.portraitUp);
      try {
        await next.setFlashMode(FlashMode.off);
      } catch (_) {}
      final minimum = await next.getMinZoomLevel(),
          maximum = await next.getMaxZoomLevel();
      if (!mounted || id != generation) {
        await next.dispose();
        return;
      }
      setState(() {
        camera = next;
        loading = false;
        minZoom = minimum;
        maxZoom = maximum;
        zoom = minimum;
      });
    } on CameraException catch (e) {
      await next?.dispose();
      if (mounted && id == generation) {
        setState(() {
          loading = false;
          cameraError = e.code.contains('AccessDenied')
              ? 'Allow camera access in your phone’s settings, then tap Try again.'
              : e.description ??
                    'The camera is unavailable. Try importing a photo.';
        });
      }
    } catch (_) {
      await next?.dispose();
      if (mounted && id == generation) {
        setState(() {
          loading = false;
          cameraError =
              'The camera could not start. Try again or import a photo.';
        });
      }
    } finally {
      startingCamera = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (widget.demo) {
      return;
    }
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      // A system permission sheet can briefly suspend the app during initialize.
      // Let that initialization finish; dispose only an established session.
      if (camera == null) {
        return;
      }
      ++generation;
      ++captureToken;
      final old = camera;
      camera = null;
      cameraDisposal = old?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      if (camera == null) {
        _startCamera();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ++generation;
    ++captureToken;
    focusTimer?.cancel();
    saveTimer?.cancel();
    camera?.dispose();
    library.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    if (busy) {
      return;
    }
    if (camera == null && !previewSample) {
      message('Enable the camera or import a photo first.');
      return;
    }
    final token = ++captureToken, options = settings.copy();
    setState(() => busy = true);
    try {
      for (var i = options.timer; i > 0; i--) {
        if (!mounted || token != captureToken) {
          return;
        }
        setState(() => countdown = i);
        await Future<void>.delayed(const Duration(seconds: 1));
      }
      if (!mounted || token != captureToken) {
        return;
      }
      setState(() {
        countdown = 0;
        shutterFlash = true;
      });
      if (options.sound) {
        SystemSound.play(SystemSoundType.click);
      }
      HapticFeedback.lightImpact();
      Future<void>.delayed(const Duration(milliseconds: 110), () {
        if (mounted) {
          setState(() => shutterFlash = false);
        }
      });
      final Uint8List original;
      if (previewSample) {
        original = (await rootBundle.load(
          'assets/sample.jpg',
        )).buffer.asUint8List();
      } else {
        final file = await camera!.takePicture();
        original = await file.readAsBytes();
      }
      await _saveImage(
        original,
        options,
        mirror:
            !previewSample &&
            facing == CameraLensDirection.front &&
            options.mirrorSelfies,
      );
    } catch (_) {
      message('That photo could not be saved. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
          countdown = 0;
          shutterFlash = false;
        });
      }
    }
  }

  Future<void> _saveImage(
    Uint8List original,
    PhotoSettings options, {
    bool mirror = false,
  }) async {
    final output = await processPhoto(original, options, mirror: mirror);
    final saved = await library.save(
      output.bytes,
      options,
      output.width,
      output.height,
      original: original,
    );
    if (mounted) {
      setState(() {});
    }
    if (options.saveToGallery) {
      try {
        await library.export(saved);
        message('Saved to Photos · ${output.width} × ${output.height}');
      } catch (_) {
        message(
          'Saved in Still. Allow Photos access to also save to your phone.',
        );
      }
    } else {
      message('Saved in Still · ${output.width} × ${output.height}');
    }
  }

  Future<void> _import() async {
    if (busy) {
      return;
    }
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        requestFullMetadata: false,
      );
      if (file == null || !mounted) {
        return;
      }
      setState(() => busy = true);
      await _saveImage(await file.readAsBytes(), settings.copy());
    } catch (_) {
      message('Could not import that photo. Try a JPEG, PNG or HEIC image.');
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> _flip() async {
    if (busy || loading) {
      return;
    }
    if (widget.demo) {
      message('Front and rear cameras are available on a phone.');
      return;
    }
    if (cameras.map((c) => c.lensDirection).toSet().length < 2) {
      message('This device has one camera.');
      return;
    }
    facing = facing == CameraLensDirection.back
        ? CameraLensDirection.front
        : CameraLensDirection.back;
    await _startCamera();
  }

  Future<void> _flash() async {
    if (camera == null || busy) {
      message('Flash is available when the camera is running.');
      return;
    }
    try {
      await camera!.setFlashMode(flash ? FlashMode.off : FlashMode.always);
      setState(() => flash = !flash);
    } catch (_) {
      message('This camera does not support flash.');
    }
  }

  Future<void> _zoom() async {
    if (camera == null) {
      message('24 mm · 1×. Zoom is available with your camera.');
      return;
    }
    final target = zoom < 1.4
        ? 1.5
        : zoom < 1.9
        ? 2.0
        : minZoom;
    try {
      final z = target.clamp(minZoom, maxZoom);
      await camera!.setZoomLevel(z);
      setState(() => zoom = z);
    } catch (_) {
      message('Zoom is unavailable on this camera.');
    }
  }

  void _focus(TapDownDetails details, Size size) {
    if (camera == null) {
      return;
    }
    final p = Offset(
      (details.localPosition.dx / size.width).clamp(0.0, 1.0),
      (details.localPosition.dy / size.height).clamp(0.0, 1.0),
    );
    camera!.setFocusPoint(p).catchError((Object _) {});
    setState(() => focus = details.localPosition);
    focusTimer?.cancel();
    focusTimer = Timer(const Duration(milliseconds: 950), () {
      if (mounted) {
        setState(() => focus = null);
      }
    });
  }

  void _openSettings() => showCameraSettings(context, settings, changed);

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !picker,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop && picker) {
        setState(() => picker = false);
      }
    },
    child: Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          final topSafe = MediaQuery.paddingOf(context).top;
          final bottomSafe = MediaQuery.paddingOf(context).bottom;
          final normalPreview = math.min(
            size.width * 4 / 3,
            size.height * .625,
          );
          final pickerHeight = math.min(390.0, size.height * .46);
          final previewHeight = picker
              ? size.height - pickerHeight
              : normalPreview;
          final top = picker
              ? 0.0
              : math.max(
                  topSafe + 36,
                  math.min(
                    (size.height - normalPreview) * .31,
                    size.height - normalPreview - bottomSafe - 184,
                  ),
                );
          return Stack(
            children: [
              Column(
                children: [
                  if (!picker)
                    SizedBox(
                      height: top,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(25, topSafe + 6, 25, 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GestureDetector(
                              onTap: () {
                                settings.highResolution =
                                    !settings.highResolution;
                                changed();
                              },
                              child: Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: Text(
                                  settings.highResolution ? 'HI-RES' : 'RETRO',
                                  style: TextStyle(
                                    fontSize: 9,
                                    letterSpacing: 1.9,
                                    color: settings.highResolution
                                        ? Colors.white38
                                        : _yellow,
                                  ),
                                ),
                              ),
                            ),
                            const Spacer(),
                            Padding(
                              padding: const EdgeInsets.only(top: 13),
                              child: Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: camera != null
                                      ? const Color(0xff32c659)
                                      : Colors.white24,
                                ),
                              ),
                            ),
                            const Spacer(),
                            _PillButton(
                              label: 'Settings',
                              onTap: _openSettings,
                              child: const Icon(Icons.more_horiz, size: 22),
                            ),
                          ],
                        ),
                      ),
                    ),
                  SizedBox(
                    height: previewHeight,
                    child: _preview(Size(size.width, previewHeight)),
                  ),
                  if (picker)
                    Expanded(child: _cameraPicker(bottomSafe))
                  else
                    Expanded(child: _controls(bottomSafe)),
                ],
              ),
              if (picker)
                Positioned(
                  right: 24,
                  top: topSafe + 14,
                  child: _PillButton(
                    label: 'Settings',
                    onTap: _openSettings,
                    child: const Icon(Icons.settings_outlined, size: 19),
                  ),
                ),
              if (shutterFlash)
                const Positioned.fill(
                  child: IgnorePointer(child: ColoredBox(color: Colors.white)),
                ),
            ],
          );
        },
      ),
    ),
  );

  Widget _preview(Size size) {
    final look = settings.look;
    final showPhoto = previewSample;
    Widget image;
    if (showPhoto) {
      image = Image.asset(
        'assets/sample.jpg',
        fit: BoxFit.cover,
        width: size.width,
        height: size.height,
      );
    } else if (camera != null && camera!.value.isInitialized) {
      final v = camera!.value;
      image = ClipRect(
        child: SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: v.previewSize!.height,
              height: v.previewSize!.width,
              child: CameraPreview(camera!),
            ),
          ),
        ),
      );
    } else {
      image = Image.asset(
        'assets/sample.jpg',
        fit: BoxFit.cover,
        width: size.width,
        height: size.height,
      );
    }
    if (!showPhoto &&
        facing == CameraLensDirection.front &&
        !settings.mirrorSelfies) {
      image = Transform.flip(flipX: true, child: image);
    }
    final content = Stack(
      fit: StackFit.expand,
      children: [
        ColorFiltered(
          colorFilter: ColorFilter.matrix(
            lookMatrix(
              look,
              strength: settings.strength,
              exposure: settings.exposure,
              warmth: settings.warmth,
            ),
          ),
          child: image,
        ),
        IgnorePointer(
          child: CustomPaint(
            painter: FilmOverlayPainter(
              settings.copy()..border = picker && settings.border,
            ),
          ),
        ),
        if (settings.grid && !picker)
          const IgnorePointer(child: CustomPaint(painter: _GridPainter())),
        if (focus != null)
          Positioned(
            left: focus!.dx - 26,
            top: focus!.dy - 26,
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                border: Border.all(color: _yellow, width: 1),
              ),
            ),
          ),
        if (countdown > 0)
          Center(
            child: Text(
              '$countdown',
              style: const TextStyle(
                fontSize: 82,
                fontWeight: FontWeight.w200,
                color: Colors.white,
              ),
            ),
          ),
        if (loading && !showPhoto)
          const ColoredBox(
            color: Color(0x99000000),
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white54,
              ),
            ),
          ),
        if (cameraError != null && !showPhoto)
          ColoredBox(
            color: Colors.black54,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(35),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.camera_alt_outlined,
                      size: 35,
                      color: Colors.white70,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Let’s make a memory.',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      cameraError!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _startCamera,
                      child: const Text('Try again'),
                    ),
                    TextButton(
                      onPressed: _import,
                      child: const Text('Import a photo'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (!picker)
          Positioned(
            left: 0,
            right: 0,
            bottom: 14,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _PreviewPill(
                  label: 'Warmth',
                  active: panel == 'warmth',
                  onTap: () => setState(
                    () => panel = panel == 'warmth' ? null : 'warmth',
                  ),
                  child: const Icon(
                    Icons.thermostat_outlined,
                    size: 22,
                    color: _yellow,
                  ),
                ),
                const SizedBox(width: 5),
                _PreviewPill(
                  label: 'Zoom',
                  onTap: _zoom,
                  child: Text(
                    '${(24 * zoom).round()}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                _PreviewPill(
                  label: 'Exposure',
                  active: panel == 'exposure',
                  onTap: () => setState(
                    () => panel = panel == 'exposure' ? null : 'exposure',
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.wb_sunny_outlined,
                        size: 21,
                        color: _yellow,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${settings.exposure >= 0 ? '+' : ''}${settings.exposure.toStringAsFixed(1)}',
                        style: const TextStyle(
                          color: _yellow,
                          fontSize: 12,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        if (!picker)
          Positioned(
            right: 15,
            bottom: 15,
            child: _effectOrb(settings.effect, () {
              setState(() => settings.effect = (settings.effect + 1) % 4);
              changed();
            }, size: 32),
          ),
        if (!picker && panel != null)
          Positioned(
            left: 35,
            right: 35,
            bottom: 70,
            child: Container(
              padding: const EdgeInsets.fromLTRB(15, 10, 15, 4),
              decoration: BoxDecoration(
                color: const Color(0xdd202020),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    panel == 'warmth'
                        ? 'TEMPERATURE'
                        : panel == 'exposure'
                        ? 'EXPOSURE'
                        : 'LOOK INTENSITY',
                    style: const TextStyle(
                      fontSize: 9,
                      letterSpacing: 2,
                      color: Colors.white70,
                    ),
                  ),
                  Slider(
                    value: panel == 'warmth'
                        ? settings.warmth
                        : panel == 'exposure'
                        ? settings.exposure
                        : settings.strength,
                    min: panel == 'warmth'
                        ? -1
                        : panel == 'exposure'
                        ? -2
                        : 0,
                    max: panel == 'exposure' ? 2 : 1,
                    divisions: panel == 'exposure' ? 40 : 100,
                    onChanged: (value) {
                      if (panel == 'warmth') {
                        settings.warmth = value;
                      } else if (panel == 'exposure') {
                        settings.exposure = value;
                      } else {
                        settings.strength = value;
                      }
                      changed();
                    },
                  ),
                ],
              ),
            ),
          ),
        if (showPhoto)
          const Positioned(
            left: 14,
            top: 14,
            child: Text(
              'SAMPLE PREVIEW',
              style: TextStyle(
                fontSize: 8,
                letterSpacing: 2,
                color: Colors.white60,
              ),
            ),
          ),
      ],
    );
    final frame = look.square
        ? Center(child: AspectRatio(aspectRatio: 1, child: content))
        : content;
    return GestureDetector(
      onTapDown: (details) => _focus(details, size),
      child: ClipRect(child: frame),
    );
  }

  Widget _controls(double bottom) => Padding(
    padding: EdgeInsets.fromLTRB(25, 12, 25, math.max(10, bottom)),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _IconButton(
              label: 'Self timer',
              icon: Icons.timer_outlined,
              active: settings.timer > 0,
              badge: settings.timer > 0 ? '${settings.timer}' : null,
              onTap: () {
                settings.timer = settings.timer == 0
                    ? 3
                    : settings.timer == 3
                    ? 10
                    : 0;
                changed();
                message(
                  settings.timer == 0
                      ? 'Timer off'
                      : '${settings.timer}-second timer',
                );
              },
            ),
            _IconButton(
              label: 'Effect intensity',
              icon: Icons.filter_tilt_shift,
              onTap: () => setState(
                () => panel = panel == 'strength' ? null : 'strength',
              ),
            ),
            _IconButton(
              label: 'Flash',
              icon: flash ? Icons.flash_on : Icons.flash_off,
              active: flash,
              onTap: _flash,
            ),
            _IconButton(
              label: 'Night exposure',
              icon: Icons.nightlight_outlined,
              active: night,
              onTap: () {
                night = !night;
                settings.exposure = night ? .7 : 0;
                changed();
                message(
                  night ? 'Exposure boost +0.7 EV' : 'Exposure boost off',
                );
              },
            ),
            _IconButton(
              label: 'Switch camera',
              icon: Icons.flip_camera_ios_outlined,
              onTap: _flip,
            ),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Semantics(
              button: true,
              label: 'Open photo library',
              child: GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => LibraryScreen(library: library),
                  ),
                ),
                child: Container(
                  width: 60,
                  height: 60,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: const Color(0xff17171c),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: library.photos.isNotEmpty
                      ? Image.file(
                          File(library.photos.first.path),
                          fit: BoxFit.cover,
                          cacheWidth: 180,
                        )
                      : Image.asset('assets/sample.jpg', fit: BoxFit.cover),
                ),
              ),
            ),
            Semantics(
              button: true,
              label: busy ? 'Processing photo' : 'Take photo',
              child: GestureDetector(
                onTap: _capture,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 100),
                  width: 76,
                  height: 76,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: busy
                        ? const Color(0xff53503c)
                        : const Color(0xff333333),
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(
                      color: const Color(0xff484848),
                      width: 1.5,
                    ),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(19),
                    ),
                    child: busy
                        ? const Center(
                            child: SizedBox(
                              width: 23,
                              height: 23,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black54,
                              ),
                            ),
                          )
                        : null,
                  ),
                ),
              ),
            ),
            Semantics(
              button: true,
              label: 'Choose camera',
              child: GestureDetector(
                onTap: () => setState(() {
                  picker = true;
                  panel = null;
                }),
                child: CameraIllustration(settings.look, size: 65),
              ),
            ),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _PillButton(
              label: 'Import photo',
              onTap: _import,
              compact: true,
              child: const Icon(
                Icons.photo_library_outlined,
                size: 17,
                color: Colors.white54,
              ),
            ),
            _PillButton(
              label: 'Camera settings',
              onTap: _openSettings,
              compact: true,
              child: const Icon(Icons.tune, size: 17, color: _yellow),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _cameraPicker(double bottom) {
    final visible = cameraLooks
        .where((l) => !favoritesOnly || favorites.contains(l.id))
        .toList();
    return Container(
      color: Colors.black,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 9, 20, 7),
            child: Row(
              children: [
                _CircleButton(
                  label: 'Favorite cameras',
                  onTap: () => setState(() => favoritesOnly = !favoritesOnly),
                  child: Icon(
                    favoritesOnly ? Icons.favorite : Icons.favorite_border,
                    size: 19,
                    color: favoritesOnly ? _yellow : Colors.white,
                  ),
                ),
                const SizedBox(width: 7),
                _CircleButton(
                  label: 'Toggle camera list',
                  onTap: () => setState(() => listMode = !listMode),
                  child: Icon(
                    listMode ? Icons.grid_view : Icons.menu,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 8),
                _PillButton(
                  label: 'Toggle sample preview',
                  onTap: () => setState(() => sample = !sample),
                  compact: true,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CameraIllustration(settings.look, size: 19),
                      const SizedBox(width: 5),
                      Text(
                        sample
                            ? 'Live camera'
                            : '${settings.look.name} Samples',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    final id = settings.lookId;
                    if (favorites.contains(id)) {
                      favorites.remove(id);
                    } else {
                      favorites.add(id);
                    }
                    changed();
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(7),
                    child: Icon(
                      favorites.contains(settings.lookId)
                          ? Icons.bookmark
                          : Icons.bookmark_border,
                      size: 18,
                      color: Colors.white38,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: visible.isEmpty
                ? const Center(
                    child: Text(
                      'Bookmark a camera to keep it here.',
                      style: TextStyle(fontSize: 12, color: Colors.white38),
                    ),
                  )
                : listMode
                ? ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: visible.length,
                    itemBuilder: (context, index) {
                      final l = visible[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CameraIllustration(l, size: 48),
                        title: Text(
                          l.name,
                          style: const TextStyle(fontSize: 13),
                        ),
                        subtitle: Text(
                          l.description,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white38,
                          ),
                        ),
                        trailing: l.id == settings.lookId
                            ? const Icon(
                                Icons.check_circle,
                                color: Colors.white,
                                size: 18,
                              )
                            : null,
                        onTap: () => _selectLook(l),
                      );
                    },
                  )
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 5,
                          childAspectRatio: .79,
                          mainAxisSpacing: 5,
                          crossAxisSpacing: 5,
                        ),
                    itemCount: visible.length,
                    itemBuilder: (context, index) => _lookTile(visible[index]),
                  ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20, 7, 24, math.max(13, bottom)),
            child: Row(
              children: [
                _CircleButton(
                  label: 'Toggle instant border',
                  onTap: () {
                    settings.border = !settings.border;
                    changed();
                  },
                  child: Icon(
                    Icons.crop_free,
                    size: 17,
                    color: settings.border ? Colors.white70 : Colors.white30,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('·', style: TextStyle(color: Colors.white30)),
                ),
                for (var i = 0; i < 4; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _effectOrb(
                      i,
                      () {
                        settings.effect = i;
                        changed();
                      },
                      size: 30,
                      selected: settings.effect == i,
                    ),
                  ),
                const Spacer(),
                _CircleButton(
                  label: 'Close camera picker',
                  size: 45,
                  onTap: () => setState(() => picker = false),
                  child: const Icon(Icons.keyboard_arrow_down, size: 30),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _selectLook(CameraLook look) {
    settings.lookId = look.id;
    changed();
    HapticFeedback.selectionClick();
  }

  Widget _lookTile(CameraLook look) {
    final selected = look.id == settings.lookId;
    return Semantics(
      button: true,
      selected: selected,
      label: '${look.name} camera',
      child: GestureDetector(
        onTap: () => _selectLook(look),
        onLongPress: () {
          favorites.contains(look.id)
              ? favorites.remove(look.id)
              : favorites.add(look.id);
          changed();
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(child: CameraIllustration(look, size: 61)),
            const SizedBox(height: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
              decoration: BoxDecoration(
                color: selected ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(
                look.name,
                maxLines: 1,
                style: TextStyle(
                  color: selected ? Colors.black : Colors.white60,
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _effectOrb(
    int index,
    VoidCallback onTap, {
    double size = 32,
    bool selected = false,
  }) {
    const colors = <List<Color>>[
      [Color(0xfff0ce88), Color(0xff6d899e), Color(0xff191b1a)],
      [
        Color(0xffe7db72),
        Color(0xff89c9c0),
        Color(0xffb579c7),
        Color(0xff2a272a),
      ],
      [Color(0xffd3a3ef), Color(0xff7918a3), Color(0xff2c1835)],
      [Color(0xff6099c1), Color(0xff163747), Color(0xff101a24)],
    ];
    return Semantics(
      button: true,
      label: [
        'No extra effect',
        'Light leak',
        'Starlight',
        'Blue bloom',
      ][index],
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: size + 3,
          height: size + 3,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xff41413b), width: 2),
                  gradient: RadialGradient(
                    center: const Alignment(-.25, -.3),
                    radius: .8,
                    colors: colors[index],
                  ),
                  boxShadow: const [
                    BoxShadow(color: Colors.black54, blurRadius: 3),
                  ],
                ),
                child: index == 2
                    ? const Icon(
                        Icons.auto_awesome,
                        size: 16,
                        color: Color(0xffe8bcfc),
                      )
                    : null,
              ),
              if (selected)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      size: 10,
                      color: Colors.black,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Widget child;
  final bool compact;
  const _PillButton({
    required this.label,
    required this.onTap,
    required this.child,
    this.compact = false,
  });
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: Tooltip(
      message: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          constraints: BoxConstraints(
            minWidth: compact ? 36 : 60,
            minHeight: compact ? 26 : 27,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 11 : 16,
            vertical: compact ? 5 : 2,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(25),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xff292929), Color(0xff1b1b1b)],
            ),
            border: Border.all(color: const Color(0xff353535), width: .6),
          ),
          child: child,
        ),
      ),
    ),
  );
}

class _CircleButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Widget child;
  final double size;
  const _CircleButton({
    required this.label,
    required this.onTap,
    required this.child,
    this.size = 31,
  });
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: Tooltip(
      message: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xff242424),
            border: Border.all(color: const Color(0xff303030), width: .6),
          ),
          child: Center(child: child),
        ),
      ),
    ),
  );
}

class _IconButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool active;
  final String? badge;
  const _IconButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.active = false,
    this.badge,
  });
  @override
  Widget build(BuildContext context) => Tooltip(
    message: label,
    child: IconButton(
      onPressed: onTap,
      style: IconButton.styleFrom(
        minimumSize: const Size(40, 36),
        padding: const EdgeInsets.all(5),
      ),
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(
            icon,
            size: 23,
            color: active ? _yellow : const Color(0xffe1e1df),
          ),
          if (badge != null)
            Positioned(
              right: -6,
              bottom: -4,
              child: Text(
                badge!,
                style: const TextStyle(fontSize: 9, color: _yellow),
              ),
            ),
        ],
      ),
    ),
  );
}

class _PreviewPill extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Widget child;
  final bool active;
  const _PreviewPill({
    required this.label,
    required this.onTap,
    required this.child,
    this.active = false,
  });
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        height: 31,
        padding: const EdgeInsets.symmetric(horizontal: 9),
        decoration: BoxDecoration(
          color: active ? const Color(0xbb363215) : const Color(0x99504a2e),
          borderRadius: BorderRadius.circular(22),
          border: active
              ? Border.all(color: _yellow.withValues(alpha: .4))
              : null,
        ),
        child: Center(child: child),
      ),
    ),
  );
}

class _GridPainter extends CustomPainter {
  const _GridPainter();
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()
      ..color = Colors.white30
      ..strokeWidth = .5;
    for (var i = 1; i < 3; i++) {
      c.drawLine(
        Offset(s.width * i / 3, 0),
        Offset(s.width * i / 3, s.height),
        p,
      );
      c.drawLine(
        Offset(0, s.height * i / 3),
        Offset(s.width, s.height * i / 3),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) => false;
}
