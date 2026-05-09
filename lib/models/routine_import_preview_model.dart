import 'package:optivus2/models/routine_template_model.dart';

class RoutineImportPreviewModel {
  final String routineType;
  final String mode;
  final List<RoutineTemplateModel> templates;
  final List<String> suggestionIds;
  final List<String> warnings;
  final Map<String, dynamic> metadata;
  final Map<String, dynamic> extra;

  const RoutineImportPreviewModel({
    required this.routineType,
    this.mode = '',
    this.templates = const [],
    this.suggestionIds = const [],
    this.warnings = const [],
    this.metadata = const {},
    this.extra = const {},
  });

  factory RoutineImportPreviewModel.fromMap(
    Map<String, dynamic> map, {
    required String routineType,
    String mode = '',
  }) {
    final suggestionIds = _stringList(map['suggestionIds']);
    final rawTemplates = _templateList(map);
    final templates = <RoutineTemplateModel>[];

    for (var i = 0; i < rawTemplates.length; i++) {
      final item = Map<String, dynamic>.from(rawTemplates[i]);
      if (i < suggestionIds.length && suggestionIds[i].trim().isNotEmpty) {
        item['_suggestionId'] = suggestionIds[i].trim();
      }
      templates.add(
        RoutineTemplateModel.fromMap(
          item,
          fallbackRoutineType: routineType,
        ),
      );
    }

    return RoutineImportPreviewModel(
      routineType: routineType,
      mode: _cleanString(map['mode']).isNotEmpty
          ? _cleanString(map['mode'])
          : mode,
      templates: templates,
      suggestionIds: suggestionIds,
      warnings: _stringList(map['warnings']),
      metadata: _stringKeyMap(map['metadata']),
      extra: _extra(map, _knownKeys),
    );
  }

  List<Map<String, dynamic>> get templateMaps =>
      templates.map((template) => template.toMap()).toList(growable: false);

  Map<String, dynamic> toMap() {
    return {
      ...extra,
      'routineType': routineType,
      if (mode.isNotEmpty) 'mode': mode,
      'templates': templateMaps,
      'suggestionIds': suggestionIds,
      'warnings': warnings,
      'metadata': metadata,
    };
  }

  RoutineImportPreviewModel copyWith({
    String? routineType,
    String? mode,
    List<RoutineTemplateModel>? templates,
    List<String>? suggestionIds,
    List<String>? warnings,
    Map<String, dynamic>? metadata,
    Map<String, dynamic>? extra,
  }) {
    return RoutineImportPreviewModel(
      routineType: routineType ?? this.routineType,
      mode: mode ?? this.mode,
      templates: templates ?? this.templates,
      suggestionIds: suggestionIds ?? this.suggestionIds,
      warnings: warnings ?? this.warnings,
      metadata: metadata ?? this.metadata,
      extra: extra ?? this.extra,
    );
  }
}

const _knownKeys = {
  'routineType',
  'mode',
  'templates',
  'items',
  'blocks',
  'suggestionIds',
  'warnings',
  'metadata',
};

List<Map<String, dynamic>> _templateList(Map<String, dynamic> map) {
  final raw = map['templates'] ?? map['items'] ?? map['blocks'];
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map(
        (item) => {
          for (final entry in item.entries) entry.key.toString(): entry.value,
        },
      )
      .toList(growable: false);
}

String _cleanString(Object? value) => value?.toString().trim() ?? '';

List<String> _stringList(Object? value) {
  if (value is! List) return const [];
  return value
      .map((item) => item.toString().trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

Map<String, dynamic> _stringKeyMap(Object? value) {
  if (value is! Map) return const {};
  return {
    for (final entry in value.entries) entry.key.toString(): entry.value,
  };
}

Map<String, dynamic> _extra(Map<String, dynamic> map, Set<String> knownKeys) {
  return {
    for (final entry in map.entries)
      if (!knownKeys.contains(entry.key)) entry.key: entry.value,
  };
}
