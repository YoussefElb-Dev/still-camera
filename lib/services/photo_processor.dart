import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import '../models/camera_look.dart';

class ProcessedPhoto {
  final Uint8List bytes;
  final int width, height;
  const ProcessedPhoto(this.bytes, this.width, this.height);
}

/// Uses the same matrix and overlay painter as the viewfinder. High resolution
/// keeps source pixels; the retro option limits the long edge to 1600 pixels.
Future<ProcessedPhoto> processPhoto(
  Uint8List input,
  PhotoSettings settings, {
  bool mirror = false,
  DateTime? date,
}) async {
  final codec = await ui.instantiateImageCodec(input);
  final frame = await codec.getNextFrame();
  final source = frame.image;
  final look = settings.look;
  final sw = source.width.toDouble(), sh = source.height.toDouble();
  final side = math.min(sw, sh);
  final crop = look.square
      ? Rect.fromLTWH((sw - side) / 2, (sh - side) / 2, side, side)
      : Rect.fromLTWH(0, 0, sw, sh);
  final scale = settings.highResolution
      ? 1.0
      : math.min(1.0, 1600 / math.max(crop.width, crop.height));
  final w = (crop.width * scale).round(), h = (crop.height * scale).round();
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final rect = Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble());
  canvas.save();
  if (mirror) {
    canvas.translate(w.toDouble(), 0);
    canvas.scale(-1, 1);
  }
  canvas.drawImageRect(
    source,
    crop,
    rect,
    Paint()
      ..filterQuality = FilterQuality.high
      ..colorFilter = ColorFilter.matrix(
        lookMatrix(
          look,
          strength: settings.strength,
          exposure: settings.exposure,
          warmth: settings.warmth,
        ),
      ),
  );
  canvas.restore();
  FilmOverlayPainter(
    settings,
    date: date ?? DateTime.now(),
    export: true,
  ).paint(canvas, Size(w.toDouble(), h.toDouble()));
  final picture = recorder.endRecording();
  final result = await picture.toImage(w, h);
  final pixels = await result.toByteData(format: ui.ImageByteFormat.rawRgba);
  if (pixels == null) {
    throw StateError('Could not encode this photo.');
  }
  final bytes = await compute(_encodeJpeg, (pixels.buffer.asUint8List(), w, h));
  result.dispose();
  picture.dispose();
  source.dispose();
  codec.dispose();
  return ProcessedPhoto(bytes, w, h);
}

Uint8List _encodeJpeg((Uint8List, int, int) input) {
  final photo = img.Image.fromBytes(
    width: input.$2,
    height: input.$3,
    bytes: input.$1.buffer,
    numChannels: 4,
  );
  return Uint8List.fromList(
    img.encodeJpg(photo, quality: 97, chroma: img.JpegChroma.yuv444),
  );
}

class FilmOverlayPainter extends CustomPainter {
  final PhotoSettings settings;
  final DateTime date;
  final bool export;
  FilmOverlayPainter(this.settings, {DateTime? date, this.export = false})
    : date = date ?? DateTime.now();
  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    final look = settings.look;
    final strength = settings.strength;
    if (look.vignette > 0 && strength > 0) {
      canvas.drawRect(
        r,
        Paint()
          ..shader = RadialGradient(
            radius: .85,
            colors: [
              Colors.transparent,
              Colors.black.withValues(alpha: look.vignette * strength),
            ],
            stops: const [.35, 1],
          ).createShader(r),
      );
    }
    if (settings.effect == 1) {
      canvas.drawRect(
        r,
        Paint()
          ..blendMode = BlendMode.screen
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xfffd6e2a).withValues(alpha: .45),
              Colors.transparent,
              Colors.transparent,
              const Color(0xffb22960).withValues(alpha: .22),
            ],
            stops: const [0, .36, .7, 1],
          ).createShader(r),
      );
    } else if (settings.effect == 2) {
      final rnd = math.Random(79);
      for (var i = 0; i < 12; i++) {
        final x = rnd.nextDouble() * size.width,
            y = rnd.nextDouble() * size.height;
        final length = size.shortestSide * (.012 + rnd.nextDouble() * .024);
        final p = Paint()
          ..color = Colors.white.withValues(alpha: .26)
          ..strokeWidth = math.max(.6, size.width / 1600);
        canvas.drawLine(Offset(x - length, y), Offset(x + length, y), p);
        canvas.drawLine(Offset(x, y - length), Offset(x, y + length), p);
      }
    } else if (settings.effect == 3) {
      canvas.drawRect(
        r,
        Paint()
          ..blendMode = BlendMode.screen
          ..shader = RadialGradient(
            center: const Alignment(.8, -.8),
            radius: 1,
            colors: [
              const Color(0xff5c91c9).withValues(alpha: .25),
              Colors.transparent,
            ],
          ).createShader(r),
      );
    }
    if (settings.grain && look.grain > 0 && strength > 0) {
      final rnd = math.Random(24);
      final grainScale = math.max(1.0, size.shortestSide / 650);
      final points = Float32List(2 * (export ? 18000 : 4500));
      for (var i = 0; i < points.length; i += 2) {
        points[i] = rnd.nextDouble() * size.width;
        points[i + 1] = rnd.nextDouble() * size.height;
      }
      canvas.drawRawPoints(
        ui.PointMode.points,
        points,
        Paint()
          ..color = Colors.white.withValues(alpha: look.grain * .18 * strength)
          ..strokeWidth = grainScale,
      );
    }
    if (look.id == 'vhs') {
      final p = Paint()
        ..color = Colors.black.withValues(alpha: .035 * strength)
        ..strokeWidth = math.max(.4, size.width / 1600);
      final step = math.max(3.0, size.height / 400);
      for (double y = 0; y < size.height; y += step) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
      }
    }
    if (settings.border && look.instant) {
      final edge = size.shortestSide * .048;
      final p = Paint()..color = const Color(0xfff1eee3);
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, edge), p);
      canvas.drawRect(Rect.fromLTWH(0, 0, edge, size.height), p);
      canvas.drawRect(
        Rect.fromLTWH(size.width - edge, 0, edge, size.height),
        p,
      );
      canvas.drawRect(
        Rect.fromLTWH(0, size.height - edge * 2.9, size.width, edge * 2.9),
        p,
      );
    }
    if (settings.dateStamp) {
      final text =
          "${date.year.toString().substring(2)}  ${date.month.toString().padLeft(2, '0')}  ${date.day.toString().padLeft(2, '0')}";
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: const Color(0xffffad5c),
            fontFamily: 'monospace',
            fontWeight: FontWeight.w500,
            fontSize: size.shortestSide * .032,
            shadows: const [Shadow(color: Color(0xffdf531c), blurRadius: 3)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(
        canvas,
        Offset(
          size.width - painter.width - size.width * .08,
          size.height -
              size.height * (settings.border && look.instant ? .16 : .055) -
              painter.height,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(FilmOverlayPainter oldDelegate) => true;
}
