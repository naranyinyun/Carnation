import 'dart:io';

import 'package:carnation/assets/asset_catalog_loader.dart';
import 'package:carnation/script/script_parser.dart';
import 'package:carnation/script/script_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AI-Native Project Validator: validates assets.yaml, characters.yaml, and all scripts', () {
    final assetsFile = File('assets.yaml');
    final charactersFile = File('characters.yaml');
    expect(assetsFile.existsSync(), isTrue, reason: 'assets.yaml is missing at project root');
    expect(charactersFile.existsSync(), isTrue, reason: 'characters.yaml is missing at project root');

    final assets = const YamlAssetCatalogParser().parse(assetsFile.readAsStringSync());
    final characters = const YamlCharacterCatalogParser().parse(charactersFile.readAsStringSync());

    final validator = ScriptValidator(
      assets: assets,
      characters: characters,
      fileExists: (path) => File(path).existsSync(),
    );

    final scriptsDir = Directory('assets/scripts');
    expect(scriptsDir.existsSync(), isTrue, reason: 'assets/scripts/ directory is missing');

    final scriptFiles = scriptsDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.yaml') || f.path.endsWith('.yml'))
        .toList();

    expect(scriptFiles, isNotEmpty, reason: 'No YAML scripts found in assets/scripts/');

    for (final file in scriptFiles) {
      final script = YamlScriptParser(validator: validator).parse(file.readAsStringSync());
      // ignore: avoid_print
      print('[OK] ${file.path} (${script.scenes.length} scenes, start: ${script.startSceneId})');
    }
  });
}
