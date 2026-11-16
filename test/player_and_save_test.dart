import 'dart:io';

import 'package:carnation/assets/asset_catalog_loader.dart';
import 'package:carnation/player/novel_player.dart';
import 'package:carnation/script/script_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ScriptPlayer & SaveRepository Persistence', () {
    late Directory tempDir;
    late File saveFile;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('carnation_test_');
      saveFile = File('${tempDir.path}/saves.json');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('executes scenes, character inheritance, branching, rollback, and persists saves across restarts', () async {
      final characters = const YamlCharacterCatalogParser()
          .parse(File('characters.yaml').readAsStringSync());
      final source = File('assets/scripts/ch01.yaml').readAsStringSync();
      final script = const YamlScriptParser().parse(source);

      final repo1 = JsonFileSaveRepository(saveFile);
      final player1 = ScriptPlayer(
        script,
        characters: characters,
        saveRepository: repo1,
      );

      expect(player1.state.scene.id, 'ch01.classroom');
      expect(player1.state.activeBackgroundId, 'classroom_noon');

      // Advance to d002 (zhou) and d003 (lin)
      player1.next();
      player1.next();
      expect(player1.state.characters.length, 2);

      // Jump to hallway choice and save to slot 2
      player1.jumpToScene('ch01.hallway');
      while (!player1.state.isWaitingForChoice) {
        player1.next();
      }
      player1.saveSlot(2);
      expect(saveFile.existsSync(), isTrue);

      // Branch to gate_call and test rollback
      player1.choose('call');
      expect(player1.state.scene.id, 'ch01.gate_call');
      player1.stepBack();
      expect(player1.state.scene.id, 'ch01.hallway');
      expect(player1.state.isWaitingForChoice, isTrue);

      await player1.dispose();

      // Simulate application restart with a fresh repository and player reading the same file
      final repo2 = JsonFileSaveRepository(saveFile);
      final player2 = ScriptPlayer(
        script,
        characters: characters,
        saveRepository: repo2,
      );

      expect(player2.saves.containsKey(2), isTrue);
      expect(player2.saves[2]!.sceneId, 'ch01.hallway');

      player2.loadSlot(2);
      expect(player2.state.scene.id, 'ch01.hallway');
      expect(player2.state.isWaitingForChoice, isTrue);

      await player2.dispose();
    });

    test('gracefully handles corrupted JSON and incompatible or out-of-range save data', () async {
      final source = File('assets/scripts/ch01.yaml').readAsStringSync();
      final script = const YamlScriptParser().parse(source);

      // 1. Corrupted JSON syntax
      saveFile.writeAsStringSync('{not valid json');
      final corruptedRepo = JsonFileSaveRepository(saveFile);
      expect(corruptedRepo.loadAll(script: script), isEmpty);

      // 2. Out-of-bounds lineIndex and non-existent sceneId mixed with 1 valid slot
      saveFile.writeAsStringSync('''
{
  "version": 1,
  "slots": {
    "1": {
      "slot": 1,
      "sceneId": "ch01.rooftop",
      "sceneIndex": 1,
      "lineIndex": 2,
      "speakerId": "narrator",
      "previewText": "有效存档",
      "backgroundId": "rooftop_night_rain",
      "savedAt": "2026-11-16T18:00:00.000"
    },
    "2": {
      "slot": 2,
      "sceneId": "ch01.rooftop",
      "sceneIndex": 1,
      "lineIndex": 999,
      "speakerId": "narrator",
      "previewText": "越界行号",
      "backgroundId": "rooftop_night_rain",
      "savedAt": "2026-11-16T18:00:00.000"
    },
    "3": {
      "slot": 3,
      "sceneId": "deleted_scene",
      "sceneIndex": 0,
      "lineIndex": 0,
      "speakerId": "narrator",
      "previewText": "不存在的场景",
      "backgroundId": "classroom_noon",
      "savedAt": "2026-11-16T18:00:00.000"
    }
  }
}
''');

      final partialRepo = JsonFileSaveRepository(saveFile);
      final player = ScriptPlayer(script, saveRepository: partialRepo);
      expect(player.saves.keys.toList(), [1]);
      expect(player.saves[1]!.previewText, '有效存档');

      await player.dispose();
    });
  });
}
