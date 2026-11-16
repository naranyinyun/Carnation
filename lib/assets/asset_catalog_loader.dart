import 'package:yaml/yaml.dart';

import 'asset_models.dart';

class YamlAssetCatalogParser {
  const YamlAssetCatalogParser();

  AssetCatalog parse(String source) {
    final root = _map(loadYaml(source), 'assets document');
    _onlyKeys(root, {'background', 'sprite', 'cg', 'bgm', 'voice'}, 'assets document');

    final backgrounds = _flatStringMap(root['background'], 'background');
    final sprites = _nestedStringMap(root['sprite'], 'sprite');
    final cgs = _flatStringMap(root['cg'], 'cg');
    final bgms = _flatStringMap(root['bgm'], 'bgm');
    final voices = _flatStringMap(root['voice'], 'voice');

    return AssetCatalog(
      backgrounds: backgrounds,
      sprites: sprites,
      cgs: cgs,
      bgms: bgms,
      voices: voices,
    );
  }

  Map<String, String> _flatStringMap(Object? value, String context) {
    if (value == null) return const {};
    final map = _map(value, context);
    final result = <String, String>{};
    for (final entry in map.entries) {
      final path = _nonEmptyString(entry.value, '$context.${entry.key}');
      result[entry.key] = path;
    }
    return result;
  }

  Map<String, Map<String, String>> _nestedStringMap(Object? value, String context) {
    if (value == null) return const {};
    final map = _map(value, context);
    final result = <String, Map<String, String>>{};
    for (final entry in map.entries) {
      if (entry.key == CharacterCatalog.narratorId) {
        throw const FormatException('Reserved speaker "narrator" cannot declare sprites');
      }
      result[entry.key] = _flatStringMap(entry.value, '$context.${entry.key}');
    }
    return result;
  }

  Map<String, Object?> _map(Object? value, String context) {
    if (value is! Map) throw FormatException('$context must be a map');
    final result = <String, Object?>{};
    for (final entry in value.entries) {
      if (entry.key is! String) throw FormatException('$context keys must be strings');
      result[entry.key as String] = entry.value;
    }
    return result;
  }

  void _onlyKeys(Map<String, Object?> value, Set<String> allowed, String context) {
    final unknown = value.keys.where((key) => !allowed.contains(key));
    if (unknown.isNotEmpty) {
      throw FormatException('Unknown $context field "${unknown.first}"');
    }
  }

  String _nonEmptyString(Object? value, String context) {
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('$context must be a non-empty string');
    }
    return value;
  }
}

class YamlCharacterCatalogParser {
  const YamlCharacterCatalogParser();

  CharacterCatalog parse(String source) {
    final root = _map(loadYaml(source), 'characters document');
    _onlyKeys(root, {'characters'}, 'characters document');
    final rawCharacters = _map(root['characters'], 'characters');
    if (rawCharacters.isEmpty) {
      throw const FormatException('characters must be a non-empty map');
    }

    final characters = <String, CharacterProfile>{};
    for (final entry in rawCharacters.entries) {
      final id = entry.key;
      if (id == CharacterCatalog.narratorId || id == 'options') {
        throw FormatException('Character id "$id" is reserved');
      }
      final def = _map(entry.value, 'characters.$id');
      _onlyKeys(def, {'name', 'color', 'default_sprite'}, 'characters.$id');
      final name = _nonEmptyString(def['name'], 'characters.$id.name');
      final color = def['color'] == null
          ? '#E8E0C0'
          : _nonEmptyString(def['color'], 'characters.$id.color');
      final defaultSprite = _nonEmptyString(
        def['default_sprite'],
        'characters.$id.default_sprite',
      );
      characters[id] = CharacterProfile(
        id: id,
        name: name,
        colorHex: color,
        defaultSprite: defaultSprite,
      );
    }

    return CharacterCatalog(characters: characters);
  }

  Map<String, Object?> _map(Object? value, String context) {
    if (value is! Map) throw FormatException('$context must be a map');
    final result = <String, Object?>{};
    for (final entry in value.entries) {
      if (entry.key is! String) throw FormatException('$context keys must be strings');
      result[entry.key as String] = entry.value;
    }
    return result;
  }

  void _onlyKeys(Map<String, Object?> value, Set<String> allowed, String context) {
    final unknown = value.keys.where((key) => !allowed.contains(key));
    if (unknown.isNotEmpty) {
      throw FormatException('Unknown $context field "${unknown.first}"');
    }
  }

  String _nonEmptyString(Object? value, String context) {
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('$context must be a non-empty string');
    }
    return value;
  }
}
