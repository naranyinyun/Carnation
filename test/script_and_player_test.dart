import 'dart:io';

import 'package:carnation/player/novel_player.dart';
import 'package:carnation/script/script_parser.dart';
import 'package:carnation/ui/player_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ch01.yaml parses and exercises all visual novel features', () {
    final source = File('assets/scripts/ch01.yaml').readAsStringSync();
    final script = YamlScriptParser().parse(source);

    expect(script.scenes.length, 5);
    expect(script.startSceneId, 'ch01.classroom');

    final player = ScriptPlayer(script);
    expect(player.state.scene.id, 'ch01.classroom');
    expect(player.state.activeBackgroundId, 'classroom_noon');
    expect(player.state.activeBgmId, 'after_school');

    // d002: zhou enters on right
    player.next();
    expect(player.state.line.id, 'd002');
    expect(player.state.characters.length, 1);
    expect(player.state.characters.single.characterId, 'zhou');
    expect(player.state.characters.single.isSpeaking, isTrue);

    // d003: lin enters on left -> both zhou and lin are on stage simultaneously
    player.next();
    expect(player.state.line.id, 'd003');
    expect(player.state.characters.length, 2);
    final lin = player.state.characters.firstWhere((c) => c.characterId == 'lin');
    final zhou = player.state.characters.firstWhere((c) => c.characterId == 'zhou');
    expect(lin.isSpeaking, isTrue);
    expect(zhou.isSpeaking, isFalse);

    // d004: zhou inherits sprite(laugh) & position(0.76)
    player.next();
    final zhouD004 = player.state.characters.firstWhere((c) => c.characterId == 'zhou');
    expect(zhouD004.spriteId, 'laugh');
    expect(zhouD004.position.x, closeTo(0.76, 0.001));

    // Jump to hallway choice line and test branching + CG + save/load + rollback
    player.jumpToScene('ch01.hallway');
    expect(player.state.scene.id, 'ch01.hallway');
    expect(player.state.characters, isEmpty); // R7: new scene resets stage characters

    while (!player.state.isWaitingForChoice) {
      player.next();
    }
    expect(player.state.line.options.length, 2);

    // Save at choice
    player.saveSlot(1);
    expect(player.saves[1]?.sceneId, 'ch01.hallway');

    // Choose True End (ch01.gate_call)
    player.choose('call');
    expect(player.state.scene.id, 'ch01.gate_call');

    // Step through to CG line d004
    player.next(); // d002
    player.next(); // d003 (gate_night)
    expect(player.state.activeBackgroundId, 'gate_night');
    player.next(); // d004 (cg: after_rain)
    expect(player.state.activeCgId, 'after_rain');

    // Rollback restores previous state
    player.stepBack();
    expect(player.state.activeCgId, isNull);

    // Load slot 1 returns to choice in hallway
    player.loadSlot(1);
    expect(player.state.scene.id, 'ch01.hallway');
    expect(player.state.isWaitingForChoice, isTrue);

    player.dispose();
  });

  testWidgets('PlayerScreen renders speaker nameplates for narrator and characters', (tester) async {
    final source = File('assets/scripts/ch01.yaml').readAsStringSync();
    final script = YamlScriptParser().parse(source);
    final player = ScriptPlayer(script);

    await tester.pumpWidget(
      MaterialApp(
        home: PlayerScreen(player: player, initialDebugMode: true),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    // Line d001: narrator nameplate is visible
    expect(find.text('旁白'), findsOneWidget);

    // Advance to d002: zhou nameplate is visible
    player.next();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('周'), findsOneWidget);

    // Advance to d003: lin nameplate is visible
    player.next();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('林'), findsOneWidget);

    await player.dispose();
  });
}
