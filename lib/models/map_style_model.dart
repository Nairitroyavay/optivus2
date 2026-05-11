import 'package:flutter/material.dart';

enum MapboxStyleId {
  coral,
  monoLight,
  satellite,
  energy;

  String get storageId => switch (this) {
        MapboxStyleId.coral => 'coral',
        MapboxStyleId.monoLight => 'monoLight',
        MapboxStyleId.satellite => 'satellite',
        MapboxStyleId.energy => 'energy',
      };

  static MapboxStyleId fromStorageId(String? value) {
    final normalized = value?.trim();
    return MapboxStyleId.values.firstWhere(
      (styleId) => styleId.storageId == normalized,
      orElse: () => MapboxStyleId.coral,
    );
  }
}

class MapboxStyle {
  final MapboxStyleId id;
  final String displayName;
  final String styleUri;
  final String description;
  final IconData icon;
  final Color accentColor;

  const MapboxStyle({
    required this.id,
    required this.displayName,
    required this.styleUri,
    required this.description,
    required this.icon,
    required this.accentColor,
  });

  String get storageId => id.storageId;

  Map<String, dynamic> toPreferenceMap({Object? updatedAt}) {
    return {
      'selectedStyleId': storageId,
      'selectedStyleUri': styleUri,
      if (updatedAt != null) 'updatedAt': updatedAt,
    };
  }
}

class MapboxStyles {
  const MapboxStyles._();

  static const coral = MapboxStyle(
    id: MapboxStyleId.coral,
    displayName: 'Coral',
    styleUri: 'mapbox://styles/nairitroy/cmozyqm88000c01r14o8h7bn0',
    description: 'Warm route-first streets',
    icon: Icons.map_rounded,
    accentColor: Color(0xFFFF7A66),
  );

  static const monoLight = MapboxStyle(
    id: MapboxStyleId.monoLight,
    displayName: 'Mono Light',
    styleUri: 'mapbox://styles/nairitroy/cmp006knu000e01r17cgd61pj',
    description: 'Clean high-contrast light map',
    icon: Icons.contrast_rounded,
    accentColor: Color(0xFFCBD5E1),
  );

  static const satellite = MapboxStyle(
    id: MapboxStyleId.satellite,
    displayName: 'Satellite',
    styleUri: 'mapbox://styles/nairitroy/cmp00db5a000r01pe3pea1r0k',
    description: 'Aerial terrain and city detail',
    icon: Icons.satellite_alt_rounded,
    accentColor: Color(0xFF4ADE80),
  );

  static const energy = MapboxStyle(
    id: MapboxStyleId.energy,
    displayName: 'Energy',
    styleUri: 'mapbox://styles/nairitroy/cmp00nzd2005101s3foyldiil',
    description: 'Bold contrast for active tracking',
    icon: Icons.bolt_rounded,
    accentColor: Color(0xFFFACC15),
  );

  static const values = [
    coral,
    monoLight,
    satellite,
    energy,
  ];

  static const defaultStyle = coral;

  static MapboxStyle byId(MapboxStyleId id) {
    return values.firstWhere(
      (style) => style.id == id,
      orElse: () => defaultStyle,
    );
  }

  static MapboxStyle byStorageId(String? id) {
    return byId(MapboxStyleId.fromStorageId(id));
  }
}
