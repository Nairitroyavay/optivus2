import 'package:cloud_firestore/cloud_firestore.dart';

enum AccountLifecycleRequestType {
  dataExport,
  deletion,
}

class AccountLifecycleRequestModel {
  static const validStatuses = {
    'requested',
    'pending',
    'processing',
    'completed',
    'failed',
    'cancelled',
    'canceled',
  };

  final String requestId;
  final String uid;
  final AccountLifecycleRequestType type;
  final String status;
  final DateTime? requestedAt;
  final DateTime? updatedAt;
  final DateTime? completedAt;
  final String reason;
  final String format;
  final Map<String, dynamic> metadata;
  final int schemaVersion;
  final Map<String, dynamic> extra;

  const AccountLifecycleRequestModel({
    required this.requestId,
    required this.uid,
    required this.type,
    this.status = 'requested',
    this.requestedAt,
    this.updatedAt,
    this.completedAt,
    this.reason = '',
    this.format = '',
    this.metadata = const {},
    this.schemaVersion = 1,
    this.extra = const {},
  });

  factory AccountLifecycleRequestModel.fromMap(
    Map<String, dynamic> map, {
    required AccountLifecycleRequestType type,
    String fallbackId = '',
  }) {
    return AccountLifecycleRequestModel(
      requestId: _cleanString(
        map['requestId'] ?? map['exportId'] ?? map['id'] ?? fallbackId,
      ),
      uid: _cleanString(map['uid']),
      type: type,
      status: _normalizeStatus(map['status']),
      requestedAt: _asDateTime(map['requestedAt'] ?? map['createdAt']),
      updatedAt: _asDateTime(map['updatedAt']),
      completedAt: _asDateTime(map['completedAt']),
      reason: _cleanString(map['reason']),
      format: _cleanString(map['format']),
      metadata: _stringKeyMap(map['metadata']),
      schemaVersion: _asInt(map['schemaVersion'], fallback: 1),
      extra: _extra(map, _knownKeys),
    );
  }

  factory AccountLifecycleRequestModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    required AccountLifecycleRequestType type,
  }) {
    return AccountLifecycleRequestModel.fromMap(
      doc.data() ?? const <String, dynamic>{},
      type: type,
      fallbackId: doc.id,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      ...extra,
      (type == AccountLifecycleRequestType.dataExport
          ? 'exportId'
          : 'requestId'): requestId,
      'uid': uid,
      'status': status,
      if (requestedAt != null) 'requestedAt': Timestamp.fromDate(requestedAt!),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
      if (completedAt != null) 'completedAt': Timestamp.fromDate(completedAt!),
      if (reason.isNotEmpty) 'reason': reason,
      if (format.isNotEmpty) 'format': format,
      if (metadata.isNotEmpty) 'metadata': metadata,
      'schemaVersion': schemaVersion,
    };
  }

  Map<String, dynamic> toClientCreateMap({Object? requestedAtOverride}) {
    final requestedAtValue = requestedAtOverride ??
        (requestedAt != null
            ? Timestamp.fromDate(requestedAt!)
            : FieldValue.serverTimestamp());
    final createStatus = _clientCreateStatus(status);
    switch (type) {
      case AccountLifecycleRequestType.dataExport:
        return {
          'exportId': requestId,
          'uid': uid,
          'requestedAt': requestedAtValue,
          'status': createStatus,
          if (format.isNotEmpty) 'format': format,
          'schemaVersion': 1,
        };
      case AccountLifecycleRequestType.deletion:
        return {
          'requestId': requestId,
          'uid': uid,
          'requestedAt': requestedAtValue,
          'status': createStatus,
          if (reason.isNotEmpty) 'reason': reason,
          'schemaVersion': 1,
        };
    }
  }

  AccountLifecycleRequestModel copyWith({
    String? requestId,
    String? uid,
    AccountLifecycleRequestType? type,
    String? status,
    DateTime? requestedAt,
    DateTime? updatedAt,
    DateTime? completedAt,
    String? reason,
    String? format,
    Map<String, dynamic>? metadata,
    int? schemaVersion,
    Map<String, dynamic>? extra,
  }) {
    return AccountLifecycleRequestModel(
      requestId: requestId ?? this.requestId,
      uid: uid ?? this.uid,
      type: type ?? this.type,
      status: status == null ? this.status : _normalizeStatus(status),
      requestedAt: requestedAt ?? this.requestedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: completedAt ?? this.completedAt,
      reason: reason ?? this.reason,
      format: format ?? this.format,
      metadata: metadata ?? this.metadata,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      extra: extra ?? this.extra,
    );
  }
}

const _knownKeys = {
  'requestId',
  'exportId',
  'id',
  'uid',
  'status',
  'requestedAt',
  'createdAt',
  'updatedAt',
  'completedAt',
  'reason',
  'format',
  'metadata',
  'schemaVersion',
};

String _cleanString(Object? value) => value?.toString().trim() ?? '';

String _normalizeStatus(Object? value) {
  final status = _cleanString(value).toLowerCase();
  if (status.isEmpty) return 'requested';
  return AccountLifecycleRequestModel.validStatuses.contains(status)
      ? status
      : 'requested';
}

String _clientCreateStatus(String value) {
  final status = _cleanString(value).toLowerCase();
  return status == 'pending' ? 'pending' : 'requested';
}

int _asInt(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

Map<String, dynamic> _stringKeyMap(Object? value) {
  if (value is! Map) return const {};
  return {
    for (final entry in value.entries) entry.key.toString(): entry.value,
  };
}

DateTime? _asDateTime(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

Map<String, dynamic> _extra(Map<String, dynamic> map, Set<String> knownKeys) {
  return {
    for (final entry in map.entries)
      if (!knownKeys.contains(entry.key)) entry.key: entry.value,
  };
}
