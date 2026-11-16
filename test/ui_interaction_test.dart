import 'dart:io';

import 'package:carnation/assets/asset_catalog_loader.dart';
import 'package:carnation/player/novel_player.dart';
import 'package:carnation/script/script_parser.dart';
import 'package:carnation/ui/player_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('PlayerScreen handles speaker nameplates, typewriter advance, backlog, save/load, and flowchart', (tester) async {
    final assets = const YamlAssetCatalogParser()
        .parse(File('assets.yaml').readAsStringSync());
    final characters = const YamlCharacterCatalogParser()
        .parse(File('characters.yaml').readAsStringSync());
    final source = File('assets/scripts/ch01.yaml').readAsStringSync();
    final script = const YamlScriptParser().parse(source);
    final player = ScriptPlayer(script, characters: characters);

    await tester.pumpWidget(
      MaterialApp(
        home: PlayerScreen(
          player: player,
          assets: assets,
          characters: characters,
          initialDebugMode: true,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    // 1. Line d001: narrator nameplate is rendered
    expect(find.text('旁白'), findsOneWidget);

    // 2. Advance to d002 (zhou) and d003 (lin)
    player.next();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('周'), findsOneWidget);

    player.next();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('林'), findsOneWidget);

    // 3. Open Backlog modal and verify recorded entries
    await tester.tap(find.text('记录'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('历史记录'), findsOneWidget);
    expect(find.textContaining('值日早就做完了'), findsOneWidget);

    // Close Backlog modal
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pump(const Duration(milliseconds: 400));

    // 4. Open Save/Load modal, save to slot 1, advance, then load slot 1
    await tester.tap(find.text('存取'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('存取档'), findsOneWidget);

    await tester.tap(find.text('存入').first);
    await tester.pump();
    expect(find.text('放学后的教室'), findsWidgets);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pump(const Duration(milliseconds: 400));

    // Jump to rooftop, then load slot 1 via modal to return to classroom
    player.jumpToScene('ch01.rooftop');
    await tester.pump(const Duration(milliseconds: 300));
    expect(player.state.scene.id, 'ch01.rooftop');

    await tester.tap(find.text('存取'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('读取').first);
    await tester.pump(const Duration(milliseconds: 400));
    expect(player.state.scene.id, 'ch01.classroom');

    // 5. Open Flowchart tree modal and jump to hallway choice scene
    await tester.tap(find.text('流程图'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('夜间走廊'), findsOneWidget);
    await tester.tap(find.text('夜间走廊'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(player.state.scene.id, 'ch01.hallway');

    await player.dispose();
  });
}
