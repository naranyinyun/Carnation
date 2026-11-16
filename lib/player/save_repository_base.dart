import 'dart:convert';

import '../script/script_models.dart';
import 'playback_models.dart';

abstract interface class SaveRepository {
  Map<int, SaveBookmark> loadAll({NovelScript? script});
  void save(SaveBookmark bookmark);
  void delete(int slot);
  void clear();
}

class InMemorySaveRepository implements SaveRepository {
  final Map<int, SaveBookmark> _slots = {};

  @override
  Map<int, SaveBookmark> loadAll({NovelScript? script}) =>
      _reconcileMap(_slots, script);

  @override
  void save(SaveBookmark bookmark) {
    _slots[bookmark.slot] = bookmark;
  }

  @override
  void delete(int slot) {
    _slots.remove(slot);
  }

  @override
  void clear() {
    _slots.clear();
  }
}

/// A [SaveRepository] that persists save slots as versioned JSON via
/// platform-supplied [readRaw] and [writeRaw] callbacks.
class JsonSaveRepository implements SaveRepository {
  JsonSaveRepository({
    required String? Function() readRaw,
    required void Function(String raw) writeRaw,
  })  : _readRaw = readRaw,
        _writeRaw = writeRaw;

  static const int currentFormatVersion = 1;

  final String? Function() _readRaw;
  final void Function(String raw) _writeRaw;
  final Map<int, SaveBookmark> _cache = {};
  bool _loaded = false;

  @override
  Map<int, SaveBookmark> loadAll({NovelScript? script}) {
    _ensureLoaded();
    return _reconcileMap(_cache, script);
  }

  @override
  void save(SaveBookmark bookmark) {
    _ensureLoaded();
    _cache[bookmark.slot] = bookmark;
    _persist();
  }

  @override
  void delete(int slot) {
    _ensureLoaded();
    _cache.remove(slot);
    _persist();
  }

  @override
  void clear() {
    _cache.clear();
    _loaded = true;
    _persist();
  }

  void _ensureLoaded() {
    if (_loaded) return;
    _loaded = true;
    _cache.clear();
    try {
      final rawContent = _readRaw();
      if (rawContent == null || rawContent.trim().isEmpty) return;

      final decoded = jsonDecode(rawContent);
      if (decoded is! Map) return;

      final version = decoded['version'];
      if (version != currentFormatVersion) return;

      final slots = decoded['slots'];
      if (slots is! Map) return;

      for (final entry in slots.entries) {
        final value = entry.value;
        if (value is! Map) continue;
        try {
          final typedMap = <String, Object?>{
            for (final kv in value.entries)
              if (kv.key is String) kv.key as String: kv.value,
          };
          final bookmark = SaveBookmark.fromJson(typedMap);
          _cache[bookmark.slot] = bookmark;
        } on FormatException {
          // Skip individual corrupted slot without failing the entire save store.
          continue;
        }
      }
    } on Object {
      // Corrupted JSON or storage error: degrade gracefully to empty saves.
      _cache.clear();
    }
  }

  void _persist() {
    try {
      final payload = {
        'version': currentFormatVersion,
        'slots': {
          for (final entry in _cache.entries) '${entry.key}': entry.value.toJson(),
        },
      };
      _writeRaw(const JsonEncoder.withIndent('  ').convert(payload));
    } on Object {
      // Ignore write failures in restricted environments while keeping in-memory cache intact.
    }
  }
}

Map<int, SaveBookmark> _reconcileMap(
  Map<int, SaveBookmark> source,
  NovelScript? script,
) {
  if (script == null) return Map.unmodifiable(source);
  final valid = <int, SaveBookmark>{};
  for (final entry in source.entries) {
    final reconciled = _reconcileWithScript(entry.value, script);
    if (reconciled != null) {
      valid[entry.key] = reconciled;
    }
  }
  return Map.unmodifiable(valid);
}

SaveBookmark? _reconcileWithScript(SaveBookmark bookmark, NovelScript script) {
  final sceneIndex = script.scenes.indexWhere((s) => s.id == bookmark.sceneId);
  if (sceneIndex < 0) return null;
  final scene = script.scenes[sceneIndex];
  if (bookmark.lineIndex < 0 || bookmark.lineIndex >= scene.lines.length) {
    return null;
  }
  if (sceneIndex == bookmark.sceneIndex) return bookmark;
  return SaveBookmark(
    slot: bookmark.slot,
    sceneId: bookmark.sceneId,
    sceneIndex: sceneIndex,
    lineIndex: bookmark.lineIndex,
    speakerId: bookmark.speakerId,
    previewText: bookmark.previewText,
    backgroundId: bookmark.backgroundId,
    savedAt: bookmark.savedAt,
  );
}
