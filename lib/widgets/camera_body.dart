import 'package:flutter/material.dart';
import '../models/camera_look.dart';

/// Original vector camera illustrations, painted at the device pixel ratio.
class CameraIllustration extends StatelessWidget {
  final CameraLook look;
  final double size;
  const CameraIllustration(this.look, {super.key, this.size = 72});
  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(painter: _CameraPainter(look)),
  );
}

class _CameraPainter extends CustomPainter {
  final CameraLook look;
  _CameraPainter(this.look);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    final shadow = Paint()
      ..color = Colors.black54
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawOval(const Rect.fromLTWH(12, 87, 76, 6), shadow);
    switch (look.body) {
      case CameraBody.phone:
        _phone(canvas);
        break;
      case CameraBody.silver:
        _silver(canvas);
        break;
      case CameraBody.camcorder:
        _camcorder(canvas);
        break;
      case CameraBody.movie:
        _movie(canvas);
        break;
      case CameraBody.disposable:
        _disposable(canvas);
        break;
      case CameraBody.instant:
        _instant(canvas, false);
        break;
      case CameraBody.square:
        _instant(canvas, true);
        break;
      case CameraBody.black:
        _instant(canvas, true, dark: true);
        break;
    }
    canvas.restore();
  }

  void body(Canvas c, Rect rect, List<Color> colors, {double radius = 10}) {
    final r = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    c.drawRRect(
      r,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
          stops: colors.length == 4 ? const [0, .16, .55, 1] : null,
        ).createShader(rect),
    );
    c.drawRRect(
      r.deflate(.8),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Colors.white.withValues(alpha: .28),
    );
    c.drawLine(
      rect.topLeft + Offset(radius, 2),
      rect.topRight + Offset(-radius, 2),
      Paint()
        ..color = Colors.white54
        ..strokeWidth = 1,
    );
  }

  void lens(Canvas c, Offset o, double r, {bool cream = false}) {
    c.drawCircle(
      o + const Offset(0, 2),
      r + 1,
      Paint()
        ..color = Colors.black38
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    c.drawCircle(
      o,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: cream
              ? const [
                  Color(0xfff9f5e7),
                  Color(0xffe0dac9),
                  Color(0xffa9a594),
                  Color(0xfffaf6e9),
                ]
              : const [
                  Color(0xff333737),
                  Color(0xff646765),
                  Color(0xff222625),
                  Color(0xffa8aaa5),
                ],
          stops: const [0, .72, .88, 1],
        ).createShader(Rect.fromCircle(center: o, radius: r)),
    );
    c.drawCircle(o, r * .64, Paint()..color = const Color(0xff161b1b));
    c.drawCircle(
      o,
      r * .48,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-.25, -.3),
          colors: [Color(0xff526b78), Color(0xff152328), Color(0xff050a0c)],
        ).createShader(Rect.fromCircle(center: o, radius: r * .5)),
    );
    c.drawCircle(
      o + Offset(-r * .16, -r * .2),
      r * .13,
      Paint()..color = const Color(0xffb9d6d7).withValues(alpha: .55),
    );
    c.drawCircle(
      o + Offset(r * .15, r * .14),
      r * .08,
      Paint()..color = const Color(0xff5d5889).withValues(alpha: .65),
    );
    c.drawCircle(
      o,
      r * .74,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .65
        ..color = Colors.white38,
    );
  }

  void flash(Canvas c, Rect r) {
    body(c, r, const [Color(0xffc9c7b9), Color(0xff55584e)], radius: 2);
    c.drawRRect(
      RRect.fromRectAndRadius(r.deflate(2), const Radius.circular(1)),
      Paint()..color = const Color(0xfff9f3ce),
    );
    for (double x = r.left + 3; x < r.right - 2; x += 2) {
      c.drawLine(
        Offset(x, r.top + 2),
        Offset(x, r.bottom - 2),
        Paint()
          ..color = Colors.black12
          ..strokeWidth = .6,
      );
    }
  }

  void _phone(Canvas c) {
    body(c, const Rect.fromLTWH(24, 5, 54, 85), const [
      Color(0xff777a75),
      Color(0xff3a3b38),
      Color(0xff252623),
      Color(0xff171916),
    ], radius: 12);
    body(c, const Rect.fromLTWH(29, 10, 37, 38), const [
      Color(0xff4c504a),
      Color(0xff252824),
    ], radius: 10);
    lens(c, const Offset(39, 21), 8);
    lens(c, const Offset(55, 34), 8);
    lens(c, const Offset(39, 39), 8);
    c.drawCircle(
      const Offset(56, 17),
      3,
      Paint()..color = const Color(0xffdad6be),
    );
    c.drawCircle(
      const Offset(50, 65),
      5,
      Paint()..color = Colors.white.withValues(alpha: .06),
    );
  }

  void _silver(Canvas c) {
    body(c, const Rect.fromLTWH(5, 24, 90, 57), const [
      Color(0xfff0f0ed),
      Color(0xff8c8d8a),
      Color(0xffd1d0cc),
      Color(0xff6b6c68),
    ], radius: 7);
    body(c, const Rect.fromLTWH(11, 26, 18, 52), const [
      Color(0xffe7e7e3),
      Color(0xff626461),
      Color(0xffb8b9b3),
      Color(0xffe7e6de),
    ], radius: 5);
    body(c, const Rect.fromLTWH(77, 26, 16, 52), const [
      Color(0xff353734),
      Color(0xff151713),
    ], radius: 5);
    lens(c, const Offset(85, 39), 6);
    flash(c, const Rect.fromLTWH(79, 53, 12, 7));
    c.drawLine(
      const Offset(36, 30),
      const Offset(36, 74),
      Paint()..color = Colors.white38,
    );
    body(c, const Rect.fromLTWH(58, 21, 17, 4), const [
      Color(0xffdedfd9),
      Color(0xff62635e),
    ], radius: 2);
  }

  void _instant(Canvas c, bool square, {bool dark = false}) {
    final colors = dark
        ? const [
            Color(0xff5e625c),
            Color(0xff252824),
            Color(0xff323530),
            Color(0xff121511),
          ]
        : square
        ? [
            look.color.withValues(red: .86, green: .82, blue: .77),
            look.color,
            const Color(0xffa69788),
            const Color(0xffddd0bc),
          ]
        : const [
            Color(0xfffffdf0),
            Color(0xffe9e5d1),
            Color(0xffc6c2ad),
            Color(0xfff6f1df),
          ];
    body(c, Rect.fromLTWH(10, 8, 80, 82), colors, radius: square ? 9 : 19);
    if (!square) {
      body(c, const Rect.fromLTWH(14, 13, 21, 70), const [
        Color(0xfff3efdc),
        Color(0xffd5d0ba),
      ], radius: 10);
    }
    body(c, const Rect.fromLTWH(44, 6, 31, 8), [
      colors.first,
      colors[1],
    ], radius: 3);
    flash(c, Rect.fromLTWH(square ? 60 : 20, 16, square ? 23 : 10, 14));
    body(c, Rect.fromLTWH(square ? 20 : 43, 16, 12, 11), const [
      Color(0xffa7aaa0),
      Color(0xff292f29),
    ], radius: 3);
    c.drawCircle(
      Offset(square ? 20 : 26, square ? 40 : 47),
      4,
      Paint()..color = const Color(0xffbbb7a5),
    );
    lens(
      c,
      Offset(square ? 53 : 58, square ? 59 : 58),
      square ? 26 : 25,
      cream: !dark,
    );
    if (square) {
      c.drawLine(
        const Offset(15, 31),
        const Offset(86, 31),
        Paint()..color = Colors.black12,
      );
    }
    for (int i = 0; i < 5; i++) {
      c.drawLine(
        Offset(15 + i * 2, 77),
        Offset(15 + i * 2, 83),
        Paint()
          ..color = Colors.black12
          ..strokeWidth = .7,
      );
    }
    c.drawCircle(
      const Offset(75, 82),
      2,
      Paint()..color = dark ? Colors.white24 : Colors.black12,
    );
  }

  void _camcorder(Canvas c) {
    c.save();
    c.translate(1, 4);
    c.rotate(-.04);
    body(c, const Rect.fromLTWH(61, 4, 14, 29), const [
      Color(0xff5a605b),
      Color(0xff1b1e1a),
    ], radius: 5);
    lens(c, const Offset(68, 10), 7);
    body(c, const Rect.fromLTWH(17, 25, 71, 57), const [
      Color(0xfff3f3ec),
      Color(0xffa6aaa4),
      Color(0xffe5e6e0),
      Color(0xff777b75),
    ], radius: 12);
    body(c, const Rect.fromLTWH(5, 35, 21, 38), const [
      Color(0xffcccfc7),
      Color(0xff777b75),
    ], radius: 7);
    body(c, const Rect.fromLTWH(28, 34, 49, 36), const [
      Color(0xffe3e5de),
      Color(0xff9da398),
    ], radius: 5);
    c.drawOval(
      const Rect.fromLTWH(47, 44, 22, 13),
      Paint()..color = const Color(0xffb2b7ad),
    );
    c.drawLine(
      const Offset(83, 33),
      const Offset(83, 76),
      Paint()
        ..color = Colors.black38
        ..strokeWidth = 3,
    );
    c.restore();
  }

  void _movie(Canvas c) {
    c.save();
    c.rotate(-.04);
    body(c, const Rect.fromLTWH(35, 56, 18, 36), const [
      Color(0xff8d8d80),
      Color(0xff2c302a),
    ], radius: 4);
    body(c, const Rect.fromLTWH(9, 15, 83, 51), const [
      Color(0xffc8c7b8),
      Color(0xff888a7c),
    ], radius: 5);
    body(c, const Rect.fromLTWH(13, 24, 75, 39), const [
      Color(0xff3b3f38),
      Color(0xff191c17),
    ], radius: 4);
    body(c, const Rect.fromLTWH(5, 21, 8, 20), const [
      Color(0xffd9d8ca),
      Color(0xff5b6155),
    ], radius: 3);
    body(c, const Rect.fromLTWH(87, 21, 9, 34), const [
      Color(0xff717669),
      Color(0xff151a12),
    ], radius: 3);
    c.restore();
  }

  void _disposable(Canvas c) {
    body(c, const Rect.fromLTWH(6, 26, 89, 55), const [
      Color(0xff737c79),
      Color(0xff282d29),
    ], radius: 12);
    final path = Path()
      ..moveTo(19, 29)
      ..lineTo(49, 28)
      ..quadraticBezierTo(37, 51, 44, 77)
      ..lineTo(17, 77)
      ..quadraticBezierTo(9, 63, 19, 29);
    c.drawPath(
      path,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xffffe949), Color(0xffc3a312)],
        ).createShader(const Rect.fromLTWH(10, 28, 40, 50)),
    );
    final p = Path()
      ..moveTo(72, 29)
      ..lineTo(84, 29)
      ..lineTo(84, 77)
      ..lineTo(69, 77)
      ..quadraticBezierTo(82, 51, 72, 29);
    c.drawPath(p, Paint()..color = const Color(0xffe1c020));
    flash(c, const Rect.fromLTWH(75, 30, 17, 13));
    lens(c, const Offset(59, 54), 20);
    c.drawCircle(const Offset(57, 32), 3, Paint()..color = Colors.white30);
  }

  @override
  bool shouldRepaint(_CameraPainter oldDelegate) =>
      oldDelegate.look.id != look.id;
}
