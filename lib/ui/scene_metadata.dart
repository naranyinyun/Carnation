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
    'stranger_ceiling.awakening' => '陌生的天花板',
    'stranger_ceiling.confinement' => '关于囚禁',
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
  manor_bedroom_day: assets/backgrounds/manor_bedroom_day.svg
  manor_bedroom_night: assets/backgrounds/manor_bedroom_night.svg
sprite:
  protagonist:
    neutral: assets/characters/protagonist_neutral.svg
  keeper:
    neutral: assets/characters/keeper_neutral.svg
    unreadable: assets/characters/keeper_unreadable.svg
cg: {}
bgm: {}
voice: {}
''');

final CharacterCatalog defaultCharacterCatalog =
    const YamlCharacterCatalogParser().parse('''
characters:
  protagonist:
    name: 我
    color: "#D6CBB8"
    default_sprite: neutral
  keeper:
    name: 她
    color: "#B99AD5"
    default_sprite: neutral
''');
