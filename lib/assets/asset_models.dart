class AssetLookupException implements Exception {
  const AssetLookupException({
    required this.category,
    required this.id,
    this.ownerId,
    required this.message,
  });

  final String category;
  final String id;
  final String? ownerId;
  final String message;

  @override
  String toString() => 'AssetLookupException($category: ${ownerId != null ? "$ownerId." : ""}$id): $message';
}

class AssetCatalog {
  AssetCatalog({
    required Map<String, String> backgrounds,
    required Map<String, Map<String, String>> sprites,
    required Map<String, String> cgs,
    required Map<String, String> bgms,
    required Map<String, String> voices,
  })  : backgrounds = Map.unmodifiable(backgrounds),
        sprites = Map.unmodifiable({
          for (final entry in sprites.entries) entry.key: Map<String, String>.unmodifiable(entry.value),
        }),
        cgs = Map.unmodifiable(cgs),
        bgms = Map.unmodifiable(bgms),
        voices = Map.unmodifiable(voices);

  final Map<String, String> backgrounds;
  final Map<String, Map<String, String>> sprites;
  final Map<String, String> cgs;
  final Map<String, String> bgms;
  final Map<String, String> voices;

  bool hasBackground(String id) => backgrounds.containsKey(id);

  bool hasCharacterSprites(String characterId) => sprites.containsKey(characterId);

  bool hasSprite(String characterId, String spriteId) =>
      sprites[characterId]?.containsKey(spriteId) ?? false;

  bool hasCg(String id) => cgs.containsKey(id);

  bool hasBgm(String id) => bgms.containsKey(id);

  bool hasVoice(String id) => voices.containsKey(id);

  String backgroundPath(String id) {
    final path = backgrounds[id];
    if (path == null) {
      throw AssetLookupException(
        category: 'background',
        id: id,
        message: 'Unknown background asset id "$id"',
      );
    }
    return path;
  }

  String spritePath(String characterId, String spriteId) {
    final charSprites = sprites[characterId];
    if (charSprites == null) {
      throw AssetLookupException(
        category: 'sprite',
        id: spriteId,
        ownerId: characterId,
        message: 'Unknown character "$characterId" in sprite catalog',
      );
    }
    final path = charSprites[spriteId];
    if (path == null) {
      throw AssetLookupException(
        category: 'sprite',
        id: spriteId,
        ownerId: characterId,
        message: 'Unknown sprite "$spriteId" for character "$characterId"',
      );
    }
    return path;
  }

  String cgPath(String id) {
    final path = cgs[id];
    if (path == null) {
      throw AssetLookupException(
        category: 'cg',
        id: id,
        message: 'Unknown cg asset id "$id"',
      );
    }
    return path;
  }

  String bgmPath(String id) {
    final path = bgms[id];
    if (path == null) {
      throw AssetLookupException(
        category: 'bgm',
        id: id,
        message: 'Unknown bgm asset id "$id"',
      );
    }
    return path;
  }

  String voicePath(String id) {
    final path = voices[id];
    if (path == null) {
      throw AssetLookupException(
        category: 'voice',
        id: id,
        message: 'Unknown voice asset id "$id"',
      );
    }
    return path;
  }

  Iterable<({String category, String id, String path})> get visualEntries sync* {
    for (final entry in backgrounds.entries) {
      yield (category: 'background', id: entry.key, path: entry.value);
    }
    for (final charEntry in sprites.entries) {
      for (final spriteEntry in charEntry.value.entries) {
        yield (
          category: 'sprite',
          id: '${charEntry.key}.${spriteEntry.key}',
          path: spriteEntry.value,
        );
      }
    }
    for (final entry in cgs.entries) {
      yield (category: 'cg', id: entry.key, path: entry.value);
    }
  }

  Iterable<({String category, String id, String path})> get audioEntries sync* {
    for (final entry in bgms.entries) {
      yield (category: 'bgm', id: entry.key, path: entry.value);
    }
    for (final entry in voices.entries) {
      yield (category: 'voice', id: entry.key, path: entry.value);
    }
  }
}

class CharacterProfile {
  const CharacterProfile({
    required this.id,
    required this.name,
    required this.colorHex,
    this.defaultSprite,
  });

  final String id;
  final String name;
  final String colorHex;
  final String? defaultSprite;

  bool get isNarrator => id == CharacterCatalog.narratorId;
}

class CharacterCatalog {
  CharacterCatalog({
    required Map<String, CharacterProfile> characters,
  }) : characters = Map.unmodifiable(characters);

  static const String narratorId = 'narrator';

  static const CharacterProfile narratorProfile = CharacterProfile(
    id: narratorId,
    name: '旁白',
    colorHex: '#D6CBB8',
  );

  final Map<String, CharacterProfile> characters;

  bool hasCharacter(String id) => characters.containsKey(id);

  bool isValidSpeaker(String id) => id == narratorId || hasCharacter(id);

  CharacterProfile profileFor(String speakerId) {
    if (speakerId == narratorId) return narratorProfile;
    final profile = characters[speakerId];
    if (profile == null) {
      throw AssetLookupException(
        category: 'character',
        id: speakerId,
        message: 'Unknown character id "$speakerId"',
      );
    }
    return profile;
  }
}
