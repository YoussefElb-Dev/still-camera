import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import '../models/camera_look.dart';

class SavedPhoto {
  String get originalPath =>
      path.replaceFirst(RegExp(r'_[^_]+\.jpg$'), '_original.jpg');
  final String path, lookName;
  final DateTime date;
  final int width, height;
  SavedPhoto({
    required this.path,
    required this.lookName,
    required this.date,
    required this.width,
    required this.height,
  });
  Map<String, dynamic> toJson() => {
    'path': path.split(RegExp(r'[/\\]')).last,
    'look': lookName,
    'date': date.toIso8601String(),
    'width': width,
    'height': height,
  };
}

class PhotoLibrary extends ChangeNotifier {
  PhotoLibrary({Directory? directory}) : _folder = directory;
  final List<SavedPhoto> photos = [];
  Directory? _folder;
  Future<Directory> get folder async => _folder ??= await Directory(
    '${(await getApplicationDocumentsDirectory()).path}/Still',
  ).create(recursive: true);
  Future<void> load() async {
    try {
      final dir = await folder;
      final index = File('${dir.path}/library.json');
      if (!await index.exists()) {
        return;
      }
      final records = jsonDecode(await index.readAsString()) as List;
      photos.clear();
      for (final r in records) {
        final path = '${dir.path}/${r['path']}';
        if (await File(path).exists()) {
          photos.add(
            SavedPhoto(
              path: path,
              lookName: r['look'] as String,
              date: DateTime.parse(r['date'] as String),
              width: r['width'] as int,
              height: r['height'] as int,
            ),
          );
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Photo library could not be read: $e');
    }
  }

  Future<SavedPhoto> save(
    Uint8List bytes,
    PhotoSettings settings,
    int width,
    int height, {
    Uint8List? original,
  }) async {
    final dir = await folder, date = DateTime.now();
    final id = date.microsecondsSinceEpoch;
    final file = File('${dir.path}/STILL_${id}_${settings.look.id}.jpg');
    await file.writeAsBytes(bytes, flush: true);
    if (original != null && settings.saveOriginal) {
      await File(
        '${dir.path}/STILL_${id}_original.jpg',
      ).writeAsBytes(original, flush: true);
    }
    final photo = SavedPhoto(
      path: file.path,
      lookName: settings.look.name,
      date: date,
      width: width,
      height: height,
    );
    photos.insert(0, photo);
    await _persist();
    notifyListeners();
    return photo;
  }

  Future<void> export(SavedPhoto photo) async {
    if (!await Gal.hasAccess()) {
      await Gal.requestAccess();
    }
    await Gal.putImage(photo.path);
  }

  Future<void> delete(SavedPhoto photo) async {
    final f = File(photo.path);
    if (await f.exists()) {
      await f.delete();
    }
    final original = File(photo.originalPath);
    if (await original.exists()) {
      await original.delete();
    }
    photos.remove(photo);
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final dir = await folder;
    final temp = File('${dir.path}/library.json.tmp');
    await temp.writeAsString(
      jsonEncode(photos.map((p) => p.toJson()).toList()),
      flush: true,
    );
    final target = File('${dir.path}/library.json');
    if (await target.exists()) {
      await target.delete();
    }
    await temp.rename(target.path);
  }
}
