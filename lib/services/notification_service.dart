// lib/services/notification_service.dart
//
// Placeholder — full implementation later.
// Exists now so EventOrchestrator can hold a typed reference.

import 'package:flutter/foundation.dart';

class NotificationService {
  /// Schedule a local notification.
  Future<void> schedule({
    required String title,
    required String body,
    required DateTime at,
  }) async {
    debugPrint('[NotificationService] schedule("$title") — not yet implemented');
  }
}
