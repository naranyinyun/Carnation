import 'package:flutter/material.dart';

import '../assets/asset_catalog_loader.dart';
import '../assets/asset_models.dart';

Color parseHexColor(String hex, {Color fallback = const Color(0xFFD6CBB8)}) {
  final cleaned = hex.trim().replaceFirst('#', '');
  if (cleaned.length == 6) {
    final value = int.tryParse('FF$cleaned', radix: 16);
    if (value != null) return Color(value);
  } else if (cleaned.length == 8) {
    final value = int.tryParse(cleaned, radix: 16);
    if (value != null) return Color(value);
  }
  return fallback;
}

String sceneDisplayTitle(String sceneId) {
  return switch (sceneId) {
    'ch01.classroom' => '放学后的教室',
    'ch01.rooftop' => '雨中的天台',
    'ch01.hallway' => '夜间走廊',
    'ch01.gate_call' => '雨霁同归',
    'ch01.gate_quiet' => '余音独行',
    _ => sceneId,
  };
}

String shortenOptionText(String text) {
  final cleaned = text.replaceAll(RegExp(r'[「」（）()]'), '').trim();
  if (cleaned.length <= 6) return cleaned;
  return '${cleaned.substring(0, 6)}…';
}

/// Default catalogs used when [PlayerScreen] is instantiated without explicit
/// catalog injection (e.g., in standalone widget tests).
final AssetCatalog defaultAssetCatalog = const YamlAssetCatalogParser().parse('''
background:
  classroom_noon: assets/backgrounds/classroom_noon.svg
  classroom_dusk: assets/backgrounds/classroom_dusk.svg
  classroom_dusk_rain: assets/backgrounds/classroom_dusk_rain.svg
  rooftop_night: assets/backgrounds/rooftop_night.svg
  rooftop_night_rain: assets/backgrounds/rooftop_night_rain.svg
  hallway_night: assets/backgrounds/hallway_night.svg
  gate_night: assets/backgrounds/gate_night.svg
sprite:
  lin:
    neutral: assets/characters/lin_neutral.svg
    smile: assets/characters/lin_smile.svg
    away: assets/characters/lin_away.svg
    surprised: assets/characters/lin_surprised.svg
  zhou:
    neutral: assets/characters/zhou_neutral.svg
    laugh: assets/characters/zhou_laugh.svg
    serious: assets/characters/zhou_serious.svg
    surprised: assets/characters/zhou_surprised.svg
cg:
  after_rain: assets/cg/after_rain.svg
bgm:
  after_school: audio/bgm/after_school.ogg
  rain_light: audio/bgm/rain_light.ogg
  rain_loop: audio/bgm/rain_loop.ogg
  hallway_quiet: audio/bgm/hallway_quiet.ogg
voice:
  lin_001: audio/voice/lin_001.ogg
  lin_002: audio/voice/lin_002.ogg
  lin_003: audio/voice/lin_003.ogg
  lin_004: audio/voice/lin_004.ogg
  lin_005: audio/voice/lin_005.ogg
  zhou_001: audio/voice/zhou_001.ogg
  zhou_002: audio/voice/zhou_002.ogg
  zhou_003: audio/voice/zhou_003.ogg
  zhou_004: audio/voice/zhou_004.ogg
  zhou_005: audio/voice/zhou_005.ogg
''');

final CharacterCatalog defaultCharacterCatalog =
    const YamlCharacterCatalogParser().parse('''
characters:
  lin:
    name: 林
    color: "#7bb0ff"
    default_sprite: neutral
  zhou:
    name: 周
    color: "#ffb86c"
    default_sprite: neutral
''');
