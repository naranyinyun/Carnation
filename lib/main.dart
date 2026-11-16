import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'assets/asset_catalog_loader.dart';
import 'assets/asset_models.dart';
import 'player/novel_player.dart';
import 'script/script_parser.dart';
import 'script/script_validator.dart';
import 'ui/motion.dart';
import 'ui/player_screen.dart';

void main(List<String> args) {
  const envDebug =
      bool.fromEnvironment('DEBUG') || bool.fromEnvironment('CARNATION_DEBUG');
  final debugMode =
      envDebug || args.contains('--debug') || args.contains('-d');
  runApp(CarnationApp(initialDebugMode: debugMode));
}

class CarnationApp extends StatelessWidget {
  const CarnationApp({super.key, this.initialDebugMode = false});

  final bool initialDebugMode;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Carnation',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF101319),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFE55B45),
          secondary: Color(0xFFF0C66B),
          surface: Color(0xFFE8E0C0),
        ),
        fontFamily: 'serif',
      ),
      home: _ScriptLoader(initialDebugMode: initialDebugMode),
    );
  }
}

class _LoadedBundle {
  const _LoadedBundle({
    required this.player,
    required this.assets,
    required this.characters,
  });

  final NovelPlayer player;
  final AssetCatalog assets;
  final CharacterCatalog characters;
}

class _ScriptLoader extends StatefulWidget {
  const _ScriptLoader({required this.initialDebugMode});

  final bool initialDebugMode;

  @override
  State<_ScriptLoader> createState() => _ScriptLoaderState();
}

class _ScriptLoaderState extends State<_ScriptLoader> {
  late final Future<_LoadedBundle> _bundle = _loadBundle();

  Future<_LoadedBundle> _loadBundle() async {
    final assetsRaw = await rootBundle.loadString('assets.yaml');
    final charactersRaw = await rootBundle.loadString('characters.yaml');
    final scriptRaw = await rootBundle.loadString('assets/scripts/ch01.yaml');

    final assets = const YamlAssetCatalogParser().parse(assetsRaw);
    final characters = const YamlCharacterCatalogParser().parse(charactersRaw);
    final validator = ScriptValidator(
      assets: assets,
      characters: characters,
    );

    final script = YamlScriptParser(validator: validator).parse(scriptRaw);
    await validator.validateAsync(
      script,
      assetExists: (path) async {
        try {
          await rootBundle.load(path);
          return true;
        } on Object {
          return false;
        }
      },
    );

    final saveRepo = createDefaultSaveRepository();

    final player = ScriptPlayer(
      script,
      characters: characters,
      saveRepository: saveRepo,
    );

    return _LoadedBundle(
      player: player,
      assets: assets,
      characters: characters,
    );
  }

  @override
  void dispose() {
    _bundle.then((b) => b.player.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_LoadedBundle>(
      future: _bundle,
      builder: (context, snapshot) {
        final Widget child;
        if (snapshot.hasError) {
          child = Scaffold(
            key: const ValueKey('error'),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text('无法载入剧本：${snapshot.error}', textAlign: TextAlign.center),
              ),
            ),
          );
        } else if (!snapshot.hasData) {
          child = const Scaffold(
            key: ValueKey('loading'),
            body: Center(child: CircularProgressIndicator()),
          );
        } else {
          final bundle = snapshot.requireData;
          child = PlayerScreen(
            key: const ValueKey('player'),
            player: bundle.player,
            assets: bundle.assets,
            characters: bundle.characters,
            initialDebugMode: widget.initialDebugMode,
          );
        }

        return AnimatedSwitcher(
          duration: M3Motion.long,
          switchInCurve: M3Motion.emphasizedDecelerate,
          switchOutCurve: M3Motion.emphasizedAccelerate,
          child: child,
        );
      },
    );
  }
}
