import 'dart:convert';
import 'dart:io';

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
  Map<int, SaveBookmark> loadAll({NovelScript? script}) {
    if (script == null) return Map.unmodifiable(_slots);
    final valid = <int, SaveBookmark>{};
    for (final entry in _slots.entries) {
      final reconciled = _reconcileWithScript(entry.value, script);
      if (reconciled != null) {
        valid[entry.key] = reconciled;
      }
    }
    return Map.unmodifiable(valid);
  }

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

class JsonFileSaveRepository implements SaveRepository {
  JsonFileSaveRepository(this.file);

  static const int currentFormatVersion = 1;

  final File file;
  final Map<int, SaveBookmark> _cache = {};
  bool _loadedFromDisk = false;

  @override
  Map<int, SaveBookmark> loadAll({NovelScript? script}) {
    if (!_loadedFromDisk) {
      _readFromDisk();
      _loadedFromDisk = true;
    }

    if (script == null) return Map.unmodifiable(_cache);

    final reconciledMap = <int, SaveBookmark>{};
    for (final entry in _cache.entries) {
      final reconciled = _reconcileWithScript(entry.value, script);
      if (reconciled != null) {
        reconciledMap[entry.key] = reconciled;
      }
    }
    return Map.unmodifiable(reconciledMap);
  }

  @override
  void save(SaveBookmark bookmark) {
    if (!_loadedFromDisk) {
      _readFromDisk();
      _loadedFromDisk = true;
    }
    _cache[bookmark.slot] = bookmark;
    _writeToDisk();
  }

  @override
  void delete(int slot) {
    if (!_loadedFromDisk) {
      _readFromDisk();
      _loadedFromDisk = true;
    }
    _cache.remove(slot);
    _writeToDisk();
  }

  @override
  void clear() {
    _cache.clear();
    _loadedFromDisk = true;
    _writeToDisk();
  }

  void _readFromDisk() {
    _cache.clear();
    try {
      if (!file.existsSync()) return;
      final rawContent = file.readAsStringSync();
      if (rawContent.trim().isEmpty) return;

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
          // Skip individual corrupted slot without failing the entire save file.
          continue;
        }
      }
    } on Object {
      // Corrupted JSON or IO error: degrade gracefully to empty saves.
      _cache.clear();
    }
  }

  void _writeToDisk() {
    try {
      file.parent.createSync(recursive: true);
      final payload = {
        'version': currentFormatVersion,
        'slots': {
          for (final entry in _cache.entries) '${entry.key}': entry.value.toJson(),
        },
      };
      file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(payload));
    } on Object {
      // Ignore write failures in read-only environments while keeping in-memory cache intact.
    }
  }
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
