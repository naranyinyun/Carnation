import 'package:flutter/material.dart';

import '../../player/playback_models.dart';
import '../scene_metadata.dart';
import 'glass_modal_shell.dart';

class SaveLoadModal extends StatefulWidget {
  const SaveLoadModal({
    super.key,
    required this.getSaves,
    required this.onSave,
    required this.onLoad,
    this.slotCount = 4,
  });

  final Map<int, SaveBookmark> Function() getSaves;
  final ValueChanged<int> onSave;
  final ValueChanged<int> onLoad;
  final int slotCount;

  @override
  State<SaveLoadModal> createState() => _SaveLoadModalState();
}

class _SaveLoadModalState extends State<SaveLoadModal> {
  @override
  Widget build(BuildContext context) {
    final saves = widget.getSaves();
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 500),
        child: GlassModalShell(
          title: '存取档',
          onClose: () => Navigator.of(context).pop(),
          child: ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: widget.slotCount,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final slot = index + 1;
              final bookmark = saves[slot];
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0x33161E30),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: bookmark != null ? const Color(0x66F0C66B) : Colors.white12,
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      '0$slot',
                      style: const TextStyle(
                        color: Color(0xFFF0C66B),
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: bookmark == null
                          ? const Text(
                              '空',
                              style: TextStyle(color: Colors.white38, fontSize: 14),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  sceneDisplayTitle(bookmark.sceneId),
                                  style: const TextStyle(
                                    color: Color(0xFFF0C66B),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  bookmark.previewText,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white, fontSize: 14),
                                ),
                              ],
                            ),
                    ),
                    const SizedBox(width: 10),
                    TextButton(
                      onPressed: () {
                        widget.onSave(slot);
                        setState(() {});
                      },
                      style: TextButton.styleFrom(foregroundColor: const Color(0xFFF0C66B)),
                      child: const Text('存入'),
                    ),
                    const SizedBox(width: 4),
                    TextButton(
                      onPressed: bookmark == null
                          ? null
                          : () {
                              Navigator.of(context).pop();
                              widget.onLoad(slot);
                            },
                      style: TextButton.styleFrom(foregroundColor: Colors.white),
                      child: const Text('读取'),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
