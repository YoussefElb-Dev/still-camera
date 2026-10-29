import 'package:flutter/material.dart';
import '../models/camera_look.dart';

Future<void> showCameraSettings(
  BuildContext context,
  PhotoSettings settings,
  VoidCallback onChanged,
) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        void update(VoidCallback fn) {
          setState(fn);
          onChanged();
        }

        Widget toggle(
          String title,
          String subtitle,
          bool value,
          ValueChanged<bool> action,
        ) => SwitchListTile.adaptive(
          title: Text(title, style: const TextStyle(fontSize: 15)),
          subtitle: Text(
            subtitle,
            style: const TextStyle(fontSize: 12, color: Colors.white38),
          ),
          value: value,
          onChanged: (v) => update(() => action(v)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 24),
        );
        return DraggableScrollableSheet(
          initialChildSize: .84,
          minChildSize: .4,
          maxChildSize: .94,
          expand: false,
          builder: (context, scroll) => ListView(
            controller: scroll,
            padding: const EdgeInsets.only(bottom: 28),
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(24, 0, 24, 20),
                child: Row(
                  children: [
                    Text(
                      'Make it yours.',
                      style: TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -.8,
                      ),
                    ),
                    Spacer(),
                    Text(
                      'STILL',
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 3,
                        color: Colors.white38,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: const Color(0xff242318),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xff454025)),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.auto_awesome_outlined,
                        color: Color(0xffe8cf39),
                        size: 22,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Every camera. Every effect. Always free.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xffe8dfaf),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const _Section('PHOTO QUALITY'),
              toggle(
                'High resolution',
                'Keep the full resolution your camera provides.',
                settings.highResolution,
                (v) => settings.highResolution = v,
              ),
              if (!settings.highResolution)
                const Padding(
                  padding: EdgeInsets.fromLTRB(24, 0, 24, 12),
                  child: Text(
                    'Retro resolution · 1600 px on the long edge',
                    style: TextStyle(fontSize: 12, color: Color(0xffe8cf39)),
                  ),
                ),
              toggle(
                'Keep original too',
                'Save an untouched copy in the app’s local files.',
                settings.saveOriginal,
                (v) => settings.saveOriginal = v,
              ),
              toggle(
                'Save to Photos',
                'Also add each capture to your phone’s photo library.',
                settings.saveToGallery,
                (v) => settings.saveToGallery = v,
              ),
              const _Section('THE LOOK'),
              toggle(
                'Film grain',
                'A little texture, just like the old days.',
                settings.grain,
                (v) => settings.grain = v,
              ),
              toggle(
                'Instant border',
                'The classic paper frame on instant cameras.',
                settings.border,
                (v) => settings.border = v,
              ),
              toggle(
                'Date stamp',
                'Burn today’s date into the corner.',
                settings.dateStamp,
                (v) => settings.dateStamp = v,
              ),
              const _Section('CAMERA'),
              toggle(
                'Composition grid',
                'Keep the horizon where you want it.',
                settings.grid,
                (v) => settings.grid = v,
              ),
              toggle(
                'Shutter sound',
                'A small click for a small memory.',
                settings.sound,
                (v) => settings.sound = v,
              ),
              toggle(
                'Mirror selfies',
                'Save the front camera as you see it.',
                settings.mirrorSelfies,
                (v) => settings.mirrorSelfies = v,
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(24, 24, 24, 8),
                child: Text(
                  'STILL CAMERA  /  1.0\nMade for memories, not subscriptions.\nYour photos stay on your device.',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white30,
                    height: 1.8,
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: TextButton(
                    onPressed: () => showLicensePage(
                      context: context,
                      applicationName: 'Still Camera',
                      applicationVersion: '1.0.0',
                    ),
                    child: const Text(
                      'Open-source licenses',
                      style: TextStyle(fontSize: 11, color: Colors.white38),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

class _Section extends StatelessWidget {
  final String title;
  const _Section(this.title);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 26, 24, 8),
    child: Text(
      title,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: Colors.white38,
        letterSpacing: 2,
      ),
    ),
  );
}
