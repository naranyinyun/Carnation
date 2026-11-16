import 'dart:io';

import 'package:carnation/assets/asset_catalog_loader.dart';
import 'package:carnation/assets/asset_models.dart';
import 'package:carnation/script/script_parser.dart';
import 'package:carnation/script/script_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ScriptValidator', () {
    late AssetCatalog assets;
    late CharacterCatalog characters;

    setUp(() {
      assets = const YamlAssetCatalogParser()
          .parse(File('assets.yaml').readAsStringSync());
      characters = const YamlCharacterCatalogParser()
          .parse(File('characters.yaml').readAsStringSync());
    });

    test('ch01.yaml passes full validation including disk visual file existence', () {
      final validator = ScriptValidator(
        assets: assets,
        characters: characters,
        fileExists: (path) => File(path).existsSync(),
      );
      final source = File('assets/scripts/ch01.yaml').readAsStringSync();
      final script = YamlScriptParser(validator: validator).parse(source);
      expect(script.scenes.length, 5);
    });

    test('reports duplicate option IDs with exact location', () {
      final validator = ScriptValidator(assets: assets, characters: characters);
      expect(
        () => YamlScriptParser(validator: validator).parse('''
scenes:
  - id: s1
    backgrounds: [classroom_noon]
    initial: classroom_noon
    start: true
    dialog:
      d1:
        lin:
          say: "选哪个？"
        options:
          - {id: dup, say: "A", to: s2}
          - {id: dup, say: "B", to: s2}
  - id: s2
    backgrounds: [classroom_noon]
    initial: classroom_noon
    end: true
    dialog:
      d1:
        narrator:
          say: "完"
'''),
        throwsA(
          isA<ScriptValidationException>()
              .having((e) => e.location, 'location', contains('s1/d1.options'))
              .having((e) => e.reason, 'reason', contains('Duplicate option id "dup"')),
        ),
      );
    });

    test('reports unknown character reference', () {
      final validator = ScriptValidator(assets: assets, characters: characters);
      expect(
        () => YamlScriptParser(validator: validator).parse('''
scenes:
  - id: s1
    backgrounds: [classroom_noon]
    initial: classroom_noon
    start: true
    end: true
    dialog:
      d1:
        stranger:
          say: "我是谁？"
'''),
        throwsA(
          isA<ScriptValidationException>()
              .having((e) => e.location, 'location', 's1/d1')
              .having((e) => e.reason, 'reason', contains('Unknown character "stranger"')),
        ),
      );
    });

    test('reports unknown sprite reference for valid character', () {
      final validator = ScriptValidator(assets: assets, characters: characters);
      expect(
        () => YamlScriptParser(validator: validator).parse('''
scenes:
  - id: s1
    backgrounds: [classroom_noon]
    initial: classroom_noon
    start: true
    end: true
    dialog:
      d1:
        lin:
          sprite: furious
          say: "生气！"
'''),
        throwsA(
          isA<ScriptValidationException>()
              .having((e) => e.location, 'location', 's1/d1.lin.sprite')
              .having((e) => e.reason, 'reason', contains('Unknown sprite "furious"')),
        ),
      );
    });

    test('reports unknown audio (bgm and voice) references', () {
      final validator = ScriptValidator(assets: assets, characters: characters);
      expect(
        () => YamlScriptParser(validator: validator).parse('''
scenes:
  - id: s1
    backgrounds: [classroom_noon]
    initial: classroom_noon
    bgm: missing_bgm
    start: true
    end: true
    dialog:
      d1:
        narrator:
          say: "测试"
'''),
        throwsA(
          isA<ScriptValidationException>()
              .having((e) => e.location, 'location', 'scene "s1".bgm')
              .having((e) => e.reason, 'reason', contains('BGM "missing_bgm"')),
        ),
      );

      expect(
        () => YamlScriptParser(validator: validator).parse('''
scenes:
  - id: s1
    backgrounds: [classroom_noon]
    initial: classroom_noon
    start: true
    end: true
    dialog:
      d1:
        lin:
          voice: missing_voice
          say: "测试"
'''),
        throwsA(
          isA<ScriptValidationException>()
              .having((e) => e.location, 'location', 's1/d1.lin.voice')
              .having((e) => e.reason, 'reason', contains('Unknown voice "missing_voice"')),
        ),
      );
    });

    test('reports narrator illegal sprite/voice/animation usage', () {
      final validator = ScriptValidator(assets: assets, characters: characters);
      expect(
        () => YamlScriptParser(validator: validator).parse('''
scenes:
  - id: s1
    backgrounds: [classroom_noon]
    initial: classroom_noon
    start: true
    end: true
    dialog:
      d1:
        narrator:
          sprite: neutral
          say: "旁白不该有立绘"
'''),
        throwsA(
          isA<ScriptValidationException>()
              .having((e) => e.location, 'location', 's1/d1.narrator.sprite'),
        ),
      );
    });

    test('reports missing asset file on disk when fileExists returns false', () {
      final validator = ScriptValidator(
        assets: assets,
        characters: characters,
        fileExists: (path) => !path.endsWith('after_rain.svg'),
      );
      final source = File('assets/scripts/ch01.yaml').readAsStringSync();
      expect(
        () => YamlScriptParser(validator: validator).parse(source),
        throwsA(
          isA<ScriptValidationException>()
              .having((e) => e.location, 'location', 'assets.cg.after_rain')
              .having((e) => e.reason, 'reason', contains('after_rain.svg')),
        ),
      );
    });

    test('detects cycles in scene graph', () {
      final validator = ScriptValidator(assets: assets, characters: characters);
      expect(
        () => YamlScriptParser(validator: validator).parse('''
scenes:
  - id: s1
    backgrounds: [classroom_noon]
    initial: classroom_noon
    start: true
    dialog:
      d1:
        narrator:
          say: "去 s2"
  - id: s2
    backgrounds: [classroom_noon]
    initial: classroom_noon
    dialog:
      d1:
        narrator:
          say: "跳回 s1"
        options:
          - {id: back, say: "回去", to: s1}
'''),
        throwsA(
          isA<ScriptValidationException>()
              .having((e) => e.reason, 'reason', contains('cycle')),
        ),
      );
    });
  });
}
