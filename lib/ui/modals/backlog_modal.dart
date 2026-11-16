import 'package:flutter/material.dart';

import '../../assets/asset_models.dart';
import '../../player/playback_models.dart';
import '../scene_metadata.dart';
import 'glass_modal_shell.dart';

class BacklogModal extends StatelessWidget {
  const BacklogModal({
    super.key,
    required this.entries,
    required this.characters,
    required this.debugMode,
    required this.onJump,
  });

  final List<BacklogEntry> entries;
  final CharacterCatalog characters;
  final bool debugMode;
  final void Function(int sceneIndex, int lineIndex) onJump;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 540),
        child: GlassModalShell(
          title: '历史记录',
          onClose: () => Navigator.of(context).pop(),
          child: ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: entries.length,
            separatorBuilder: (_, __) => const Divider(color: Colors.white12, height: 18),
            itemBuilder: (context, index) {
              final item = entries[index];
              final profile = characters.profileFor(item.speakerId);
              final speakerColor = parseHexColor(profile.colorHex);
              return InkWell(
                onTap: () => onJump(item.sceneIndex, item.lineIndex),
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 56,
                        child: Text(
                          profile.isNarrator ? '' : profile.name,
                          style: TextStyle(
                            color: speakerColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          item.text,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            height: 1.5,
                          ),
                        ),
                      ),
                      if (debugMode)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Text(
                            '${item.sceneId}/${item.lineId}',
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 11,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
