import 'dart:math' as math;
import 'package:flutter/material.dart';

enum CameraBody {
  phone,
  silver,
  camcorder,
  movie,
  disposable,
  instant,
  square,
  black,
}

class CameraLook {
  final String id, name, description;
  final CameraBody body;
  final Color color;
  final double saturation, contrast, warmth, fade, grain, vignette;
  final bool instant, square;
  const CameraLook({
    required this.id,
    required this.name,
    required this.description,
    required this.body,
    this.color = const Color(0xffe5dec9),
    this.saturation = 1,
    this.contrast = 1,
    this.warmth = 0,
    this.fade = 0,
    this.grain = .2,
    this.vignette = .15,
    this.instant = false,
    this.square = false,
  });
}

const cameraLooks = <CameraLook>[
  CameraLook(
    id: 'original-v',
    name: 'Original V',
    description: 'Clean color. A little cinematic.',
    body: CameraBody.phone,
    saturation: .9,
    contrast: 1.08,
    grain: .08,
  ),
  CameraLook(
    id: 'sv10-v',
    name: 'SV10 V',
    description: 'The silver digicam, after dark.',
    body: CameraBody.silver,
    saturation: .76,
    contrast: 1.18,
    warmth: -.15,
    fade: 7,
    grain: .35,
  ),
  CameraLook(
    id: 'vhs',
    name: 'VHS',
    description: 'Soft color from a home-video summer.',
    body: CameraBody.camcorder,
    saturation: .65,
    contrast: .88,
    warmth: -.15,
    fade: 13,
    grain: .65,
    vignette: .28,
  ),
  CameraLook(
    id: 'm24',
    name: 'M24',
    description: 'Warm 24-frame movie memories.',
    body: CameraBody.movie,
    saturation: .8,
    contrast: 1.12,
    warmth: .5,
    fade: 9,
    grain: .45,
    vignette: .3,
  ),
  CameraLook(
    id: 'funs',
    name: 'FunS V',
    description: 'Sunny, imperfect, disposable.',
    body: CameraBody.disposable,
    color: Color(0xffedc52d),
    saturation: 1.25,
    contrast: 1.12,
    warmth: .65,
    grain: .65,
    vignette: .4,
  ),
  CameraLook(
    id: 'inst',
    name: 'Inst',
    description: 'Soft highlights. Instant nostalgia.',
    body: CameraBody.instant,
    saturation: .8,
    contrast: .92,
    warmth: .3,
    fade: 9,
    grain: .32,
    vignette: .25,
    instant: true,
  ),
  CameraLook(
    id: 'inst-sqc',
    name: 'Inst Sqc',
    description: 'A square little piece of the day.',
    body: CameraBody.square,
    color: Color(0xffc5b3a6),
    saturation: .72,
    contrast: .94,
    warmth: .2,
    fade: 12,
    grain: .4,
    vignette: .23,
    instant: true,
    square: true,
  ),
  CameraLook(
    id: 'original',
    name: 'Original',
    description: 'Your camera, beautifully untouched.',
    body: CameraBody.phone,
    grain: 0,
    vignette: 0,
  ),
  CameraLook(
    id: 'sv10',
    name: 'SV10',
    description: '2000s flash. Silver-pocket-camera color.',
    body: CameraBody.silver,
    saturation: .82,
    contrast: 1.18,
    warmth: -.28,
    fade: 3,
    grain: .3,
    vignette: .3,
  ),
  CameraLook(
    id: 'inst-sq',
    name: 'Inst SQ',
    description: 'Deep blacks in an instant square.',
    body: CameraBody.black,
    saturation: .74,
    contrast: 1.12,
    warmth: -.1,
    fade: 5,
    grain: .4,
    vignette: .35,
    instant: true,
    square: true,
  ),
];

const identityMatrix = <double>[
  1,
  0,
  0,
  0,
  0,
  0,
  1,
  0,
  0,
  0,
  0,
  0,
  1,
  0,
  0,
  0,
  0,
  0,
  1,
  0,
];

List<double> lookMatrix(
  CameraLook look, {
  double strength = 1,
  double exposure = 0,
  double warmth = 0,
}) {
  final s = 1 + (look.saturation - 1) * strength;
  final c = 1 + (look.contrast - 1) * strength;
  final t = look.warmth * strength + warmth;
  final f = look.fade * strength;
  final e = math.pow(2, exposure).toDouble();
  final r = (1 - s) * .2126, g = (1 - s) * .7152, b = (1 - s) * .0722;
  final bias = 128 * (1 - c) + f;
  return [
    (r + s) * c * e,
    g * c * e,
    b * c * e,
    0,
    (bias + t * 19) * e,
    r * c * e,
    (g + s) * c * e,
    b * c * e,
    0,
    (bias + t * 5) * e,
    r * c * e,
    g * c * e,
    (b + s) * c * e,
    0,
    (bias - t * 22) * e,
    0,
    0,
    0,
    1,
    0,
  ];
}

class PhotoSettings {
  String lookId;
  bool highResolution,
      saveOriginal,
      saveToGallery,
      grain,
      border,
      dateStamp,
      grid,
      sound,
      mirrorSelfies;
  double strength, warmth, exposure;
  int effect, timer;
  PhotoSettings({
    this.lookId = 'inst',
    this.highResolution = true,
    this.saveOriginal = false,
    this.saveToGallery = true,
    this.grain = true,
    this.border = true,
    this.dateStamp = false,
    this.grid = false,
    this.sound = true,
    this.mirrorSelfies = true,
    this.strength = 1,
    this.warmth = 0,
    this.exposure = 0,
    this.effect = 0,
    this.timer = 0,
  });
  CameraLook get look => cameraLooks.firstWhere(
    (l) => l.id == lookId,
    orElse: () => cameraLooks[5],
  );
  Map<String, dynamic> toJson() => {
    'lookId': lookId,
    'highResolution': highResolution,
    'saveOriginal': saveOriginal,
    'saveToGallery': saveToGallery,
    'grain': grain,
    'border': border,
    'dateStamp': dateStamp,
    'grid': grid,
    'sound': sound,
    'mirrorSelfies': mirrorSelfies,
    'strength': strength,
    'warmth': warmth,
    'exposure': exposure,
    'effect': effect,
    'timer': timer,
  };
  factory PhotoSettings.fromJson(Map<String, dynamic> j) => PhotoSettings(
    lookId: j['lookId'] as String? ?? 'inst',
    highResolution: j['highResolution'] as bool? ?? true,
    saveOriginal: j['saveOriginal'] as bool? ?? false,
    saveToGallery: j['saveToGallery'] as bool? ?? true,
    grain: j['grain'] as bool? ?? true,
    border: j['border'] as bool? ?? true,
    dateStamp: j['dateStamp'] as bool? ?? false,
    grid: j['grid'] as bool? ?? false,
    sound: j['sound'] as bool? ?? true,
    mirrorSelfies: j['mirrorSelfies'] as bool? ?? true,
    strength: (j['strength'] as num?)?.toDouble() ?? 1,
    warmth: (j['warmth'] as num?)?.toDouble() ?? 0,
    exposure: (j['exposure'] as num?)?.toDouble() ?? 0,
    effect: j['effect'] as int? ?? 0,
    timer: j['timer'] as int? ?? 0,
  );
  PhotoSettings copy() => PhotoSettings.fromJson(toJson());
}
