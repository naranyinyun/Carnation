import 'dart:io';

import 'package:carnation/assets/asset_catalog_loader.dart';
import 'package:carnation/assets/asset_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AssetCatalog & CharacterCatalog', () {
    late AssetCatalog assets;
    late CharacterCatalog characters;

    setUp(() {
      assets = const YamlAssetCatalogParser()
          .parse(File('assets.yaml').readAsStringSync());
      characters = const YamlCharacterCatalogParser()
          .parse(File('characters.yaml').readAsStringSync());
    });

    test('resolves registered background, sprite, cg, bgm, and voice paths', () {
      expect(
        assets.backgroundPath('classroom_noon'),
        'assets/backgrounds/classroom_noon.svg',
      );
      expect(
        assets.spritePath('lin', 'smile'),
        'assets/characters/lin_smile.svg',
      );
      expect(
        assets.cgPath('after_rain'),
        'assets/cg/after_rain.svg',
      );
      expect(
        assets.bgmPath('after_school'),
        'audio/bgm/after_school.ogg',
      );
      expect(
        assets.voicePath('lin_001'),
        'audio/voice/lin_001.ogg',
      );
    });

    test('throws AssetLookupException when querying unregistered asset IDs', () {
      expect(
        () => assets.backgroundPath('unknown_bg'),
        throwsA(isA<AssetLookupException>()),
      );
      expect(
        () => assets.spritePath('lin', 'angry'),
        throwsA(isA<AssetLookupException>()),
      );
      expect(
        () => assets.spritePath('unknown_char', 'neutral'),
        throwsA(isA<AssetLookupException>()),
      );
      expect(
        () => assets.cgPath('unknown_cg'),
        throwsA(isA<AssetLookupException>()),
      );
      expect(
        () => assets.bgmPath('unknown_bgm'),
        throwsA(isA<AssetLookupException>()),
      );
      expect(
        () => assets.voicePath('unknown_voice'),
        throwsA(isA<AssetLookupException>()),
      );
    });

    test('resolves character profiles and built-in narrator', () {
      final lin = characters.profileFor('lin');
      expect(lin.name, '林');
      expect(lin.defaultSprite, 'neutral');
      expect(lin.isNarrator, isFalse);

      final narrator = characters.profileFor('narrator');
      expect(narrator.name, '旁白');
      expect(narrator.isNarrator, isTrue);

      expect(
        () => characters.profileFor('ghost'),
        throwsA(isA<AssetLookupException>()),
      );
    });

    test('rejects reserved character IDs in characters.yaml and assets.yaml', () {
      expect(
        () => const YamlCharacterCatalogParser().parse('''
characters:
  narrator:
    name: 旁白
    default_sprite: neutral
'''),
        throwsFormatException,
      );

      expect(
        () => const YamlAssetCatalogParser().parse('''
background: {}
sprite:
  narrator:
    neutral: assets/characters/lin_neutral.svg
cg: {}
bgm: {}
voice: {}
'''),
        throwsFormatException,
      );
    });
  });
}
