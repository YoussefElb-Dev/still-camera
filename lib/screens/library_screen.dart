import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../services/photo_library.dart';

class LibraryScreen extends StatelessWidget {
  final PhotoLibrary library;
  const LibraryScreen({super.key, required this.library});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      backgroundColor: Colors.black,
      title: const Text(
        'Your little time capsule.',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w500,
          letterSpacing: -.5,
        ),
      ),
    ),
    body: ListenableBuilder(
      listenable: library,
      builder: (context, _) => library.photos.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.photo_library_outlined,
                    size: 38,
                    color: Colors.white30,
                  ),
                  SizedBox(height: 20),
                  Text(
                    'The good days start here.',
                    style: TextStyle(fontSize: 18),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Your photos will appear after your first shot.',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(3),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 3,
                mainAxisSpacing: 3,
              ),
              itemCount: library.photos.length,
              itemBuilder: (context, index) {
                final photo = library.photos[index];
                return GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          PhotoScreen(library: library, photo: photo),
                    ),
                  ),
                  child: Hero(
                    tag: photo.path,
                    child: Image.file(
                      File(photo.path),
                      fit: BoxFit.cover,
                      cacheWidth: 450,
                    ),
                  ),
                );
              },
            ),
    ),
  );
}

class PhotoScreen extends StatefulWidget {
  final PhotoLibrary library;
  final SavedPhoto photo;
  const PhotoScreen({super.key, required this.library, required this.photo});
  @override
  State<PhotoScreen> createState() => _PhotoScreenState();
}

class _PhotoScreenState extends State<PhotoScreen> {
  bool busy = false;
  void message(String s) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
    }
  }

  Future<void> save() async {
    setState(() => busy = true);
    try {
      await widget.library.export(widget.photo);
      message('Saved to Photos.');
    } catch (_) {
      message('Allow photo-library access in your phone’s settings to save.');
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> share({bool original = false}) async {
    final box = context.findRenderObject() as RenderBox?;
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile(original ? widget.photo.originalPath : widget.photo.path),
          ],
          sharePositionOrigin: box == null
              ? null
              : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } catch (_) {
      message(
        'Sharing is unavailable. You can save this photo to Photos instead.',
      );
    }
  }

  Future<void> remove() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete this photo?'),
        content: const Text(
          'This removes the copy in Still. Photos saved to your phone stay in Photos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.library.delete(widget.photo);
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.photo;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(p.lookName, style: const TextStyle(fontSize: 15)),
            Text(
              '${p.width} × ${p.height}  ·  ${(p.width * p.height / 1000000).toStringAsFixed(1)} MP',
              style: const TextStyle(fontSize: 10, color: Colors.white38),
            ),
          ],
        ),
        actions: [
          if (File(p.originalPath).existsSync())
            PopupMenuButton<String>(
              tooltip: 'Original photo',
              onSelected: (_) => share(original: true),
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'original',
                  child: Text('Share untouched original'),
                ),
              ],
            ),
          IconButton(
            tooltip: 'Delete photo',
            onPressed: remove,
            icon: const Icon(Icons.delete_outline, size: 22),
          ),
        ],
      ),
      body: Center(
        child: Hero(
          tag: p.path,
          child: InteractiveViewer(
            minScale: .8,
            maxScale: 5,
            child: Image.file(File(p.path), fit: BoxFit.contain),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton.icon(
                onPressed: busy ? null : save,
                icon: busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_alt, size: 20),
                label: const Text('Save to Photos'),
              ),
              TextButton.icon(
                onPressed: share,
                icon: const Icon(Icons.ios_share, size: 20),
                label: const Text('Share'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
