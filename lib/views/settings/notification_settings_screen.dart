import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:optivus2/core/liquid_ui/liquid_ui.dart';
import 'package:optivus2/core/providers.dart';
import 'package:optivus2/core/utils/device_id.dart';

const _eventNotificationSettingsChanged = 'notification_settings_changed';

class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen> {
  _NotificationSettingsDraft _settings = _NotificationSettingsDraft.defaults();
  bool _loading = true;
  bool _saving = false;
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: kInk,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Notification Settings',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
      body: LiquidBg(
        colors: const [Color(0xFFEFFEEC), Color(0xFFFCF8EE)],
        child: SafeArea(
          top: false,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                  children: [
                    _budgetSection(),
                    const SizedBox(height: 16),
                    _categorySection(),
                    const SizedBox(height: 16),
                    _quietDaysSection(),
                    const SizedBox(height: 16),
                    _blackoutSection(),
                    const SizedBox(height: 16),
                    _customAlarmSection(),
                    const SizedBox(height: 16),
                    _soundAndVibrationSection(),
                    const SizedBox(height: 16),
                    _testSection(),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _budgetSection() {
    return _SettingsCard(
      title: 'Daily budget',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.speed_rounded, color: kInk),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${_settings.dailyBudget} notifications per day',
                  style: const TextStyle(
                    color: kInk,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          Slider(
            value: _settings.dailyBudget.toDouble(),
            min: 3,
            max: 15,
            divisions: 12,
            label: _settings.dailyBudget.toString(),
            onChanged: (value) => _update(
              _settings.copyWith(dailyBudget: value.round()),
              'daily_budget',
            ),
          ),
        ],
      ),
    );
  }

  Widget _categorySection() {
    return _SettingsCard(
      title: 'Category caps',
      child: Column(
        children: [
          for (final entry in _categoryLabels.entries)
            _CategoryRow(
              label: entry.value,
              value: _settings.categories[entry.key] ??
                  _CategoryPreference.defaults(entry.key),
              onChanged: (value) {
                final categories =
                    Map<String, _CategoryPreference>.from(_settings.categories);
                categories[entry.key] = value;
                _update(
                  _settings.copyWith(categories: categories),
                  'category_${entry.key}',
                  reconcile: true,
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _quietDaysSection() {
    final dates = List.generate(
      7,
      (index) => DateTime.now().add(Duration(days: index)),
    );

    return _SettingsCard(
      title: 'Quiet days',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Quiet mode today',
              style: TextStyle(fontWeight: FontWeight.w800, color: kInk),
            ),
            subtitle: const Text('Suppress non-critical notifications today.'),
            value: _settings.quietToday,
            onChanged: (value) => _update(
              _settings.copyWith(quietToday: value),
              'quiet_today',
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final date in dates)
                FilterChip(
                  label: Text(_quietDayLabel(date)),
                  selected: _settings.quietDays.contains(_dateKey(date)),
                  onSelected: (selected) {
                    final days = Set<String>.from(_settings.quietDays);
                    final key = _dateKey(date);
                    selected ? days.add(key) : days.remove(key);
                    _update(
                      _settings.copyWith(quietDays: days),
                      'quiet_days',
                    );
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _blackoutSection() {
    return _SettingsCard(
      title: 'Blackout windows',
      child: Column(
        children: [
          for (final window in _settings.blackouts)
            _BlackoutRow(
              window: window,
              onChanged: (next) {
                final windows = _settings.blackouts
                    .map((item) => item.id == next.id ? next : item)
                    .toList();
                _update(
                  _settings.copyWith(blackouts: windows),
                  'blackout_window',
                );
              },
              onDelete: () {
                final windows = _settings.blackouts
                    .where((item) => item.id != window.id)
                    .toList();
                _update(
                  _settings.copyWith(blackouts: windows),
                  'blackout_removed',
                );
              },
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                final id =
                    FirebaseFirestore.instance.collection('tmp').doc().id;
                _update(
                  _settings.copyWith(
                    blackouts: [
                      ..._settings.blackouts,
                      _BlackoutWindow(
                        id: id,
                        start: '22:00',
                        end: '07:00',
                        enabled: true,
                      ),
                    ],
                  ),
                  'blackout_added',
                );
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add window'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _customAlarmSection() {
    return _SettingsCard(
      title: 'Custom alarms',
      child: Column(
        children: [
          if (_settings.customAlarms.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'No custom alarms yet.',
                style: TextStyle(
                  color: kSub.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          for (final alarm in _settings.customAlarms)
            _CustomAlarmRow(
              alarm: alarm,
              onChanged: (next) {
                final alarms = _settings.customAlarms
                    .map((item) => item.id == next.id ? next : item)
                    .toList();
                _update(
                  _settings.copyWith(customAlarms: alarms),
                  'custom_alarm',
                );
              },
              onDelete: () {
                final alarms = _settings.customAlarms
                    .where((item) => item.id != alarm.id)
                    .toList();
                _update(
                  _settings.copyWith(customAlarms: alarms),
                  'custom_alarm_removed',
                );
              },
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                final id =
                    FirebaseFirestore.instance.collection('tmp').doc().id;
                _update(
                  _settings.copyWith(
                    customAlarms: [
                      ..._settings.customAlarms,
                      _CustomAlarm(
                        id: id,
                        label:
                            'Custom alarm ${_settings.customAlarms.length + 1}',
                        time: '09:00',
                        enabled: true,
                      ),
                    ],
                  ),
                  'custom_alarm_added',
                );
              },
              icon: const Icon(Icons.alarm_add_rounded),
              label: const Text('Add alarm'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _soundAndVibrationSection() {
    return _SettingsCard(
      title: 'Sound and vibration',
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            initialValue: _settings.sound,
            decoration: const InputDecoration(
              labelText: 'Sound',
              prefixIcon: Icon(Icons.volume_up_rounded),
            ),
            items: const [
              DropdownMenuItem(value: 'default', child: Text('Default')),
              DropdownMenuItem(value: 'calm', child: Text('Calm')),
              DropdownMenuItem(value: 'focus', child: Text('Focus')),
              DropdownMenuItem(value: 'none', child: Text('Silent')),
            ],
            onChanged: (value) {
              if (value == null) return;
              _update(_settings.copyWith(sound: value), 'sound');
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _settings.vibration,
            decoration: const InputDecoration(
              labelText: 'Vibration pattern',
              prefixIcon: Icon(Icons.vibration_rounded),
            ),
            items: const [
              DropdownMenuItem(value: 'standard', child: Text('Standard')),
              DropdownMenuItem(value: 'soft', child: Text('Soft')),
              DropdownMenuItem(value: 'urgent', child: Text('Urgent')),
              DropdownMenuItem(value: 'none', child: Text('Off')),
            ],
            onChanged: (value) {
              if (value == null) return;
              _update(_settings.copyWith(vibration: value), 'vibration');
            },
          ),
        ],
      ),
    );
  }

  Widget _testSection() {
    return _SettingsCard(
      title: 'Test',
      child: FilledButton.icon(
        onPressed: _testing ? null : _sendTestNotification,
        icon: _testing
            ? const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.notifications_active_outlined),
        label: const Text('Send test notification'),
      ),
    );
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    final doc = await _profileRef(uid).get();
    if (!mounted) return;
    setState(() {
      _settings = _NotificationSettingsDraft.fromProfile(
        doc.data() ?? const <String, dynamic>{},
      );
      _loading = false;
    });
  }

  Future<void> _update(
    _NotificationSettingsDraft settings,
    String changedField, {
    bool reconcile = false,
  }) async {
    setState(() {
      _settings = settings;
      _saving = true;
    });

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _saving = false);
      return;
    }

    try {
      await _profileRef(uid).set({
        'notificationSettings': settings.toFirestore(),
        'dailyNotificationBudget': settings.dailyBudget,
        'quietDayMode': settings.quietToday,
        'updatedAt': FieldValue.serverTimestamp(),
        'schemaVersion': 1,
      }, SetOptions(merge: true));

      await _emitSettingsChanged(uid, changedField, settings);
      if (reconcile) {
        await ref
            .read(notificationServiceProvider)
            .reconcilePendingNotificationsWithSettings(uid);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _sendTestNotification() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _testing = true);
    try {
      await ref.read(notificationServiceProvider).requestPermissions();
      final sent =
          await ref.read(notificationServiceProvider).sendTestNotification(uid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            sent
                ? 'Test notification sent.'
                : 'Test notifications are not supported here.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  DocumentReference<Map<String, dynamic>> _profileRef(String uid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('profile')
        .doc('main');
  }

  Future<void> _emitSettingsChanged(
    String uid,
    String changedField,
    _NotificationSettingsDraft settings,
  ) async {
    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
    final eventRef = userRef.collection('events').doc();
    final event = {
      'eventId': eventRef.id,
      'eventName': _eventNotificationSettingsChanged,
      'uid': uid,
      'timestamp': FieldValue.serverTimestamp(),
      'source': 'notification_settings_screen',
      'schemaVersion': 1,
      'payloadVersion': 1,
      'deviceId': await getDeviceId(),
      'appVersion': '1.0.0',
      'payload': {
        'changedField': changedField,
        'dailyBudget': settings.dailyBudget,
        'quietToday': settings.quietToday,
      },
    };
    final batch = FirebaseFirestore.instance.batch();
    batch.set(eventRef, event);
    batch.set(userRef.collection('events_recent').doc(eventRef.id), event);
    await batch.commit();
  }
}

class _SettingsCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SettingsCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return LiquidCard.solid(
      radius: 18,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      tint: Colors.white.withValues(alpha: 0.58),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              color: kSub.withValues(alpha: 0.88),
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final String label;
  final _CategoryPreference value;
  final ValueChanged<_CategoryPreference> onChanged;

  const _CategoryRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w800, color: kInk),
            ),
            subtitle: Text('Cap: ${value.cap} per day'),
            value: value.enabled,
            onChanged: (enabled) => onChanged(value.copyWith(enabled: enabled)),
          ),
          Slider(
            value: value.cap.toDouble(),
            min: 0,
            max: 15,
            divisions: 15,
            label: value.cap.toString(),
            onChanged: value.enabled
                ? (cap) => onChanged(value.copyWith(cap: cap.round()))
                : null,
          ),
        ],
      ),
    );
  }
}

class _BlackoutRow extends StatelessWidget {
  final _BlackoutWindow window;
  final ValueChanged<_BlackoutWindow> onChanged;
  final VoidCallback onDelete;

  const _BlackoutRow({
    required this.window,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Switch.adaptive(
            value: window.enabled,
            onChanged: (enabled) =>
                onChanged(window.copyWith(enabled: enabled)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _TimeDropdown(
                    value: window.start,
                    onChanged: (value) =>
                        onChanged(window.copyWith(start: value)),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('to'),
                ),
                Expanded(
                  child: _TimeDropdown(
                    value: window.end,
                    onChanged: (value) =>
                        onChanged(window.copyWith(end: value)),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Delete window',
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
    );
  }
}

class _CustomAlarmRow extends StatelessWidget {
  final _CustomAlarm alarm;
  final ValueChanged<_CustomAlarm> onChanged;
  final VoidCallback onDelete;

  const _CustomAlarmRow({
    required this.alarm,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Switch.adaptive(
            value: alarm.enabled,
            onChanged: (enabled) => onChanged(alarm.copyWith(enabled: enabled)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              alarm.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800, color: kInk),
            ),
          ),
          SizedBox(
            width: 112,
            child: _TimeDropdown(
              value: alarm.time,
              onChanged: (value) => onChanged(alarm.copyWith(time: value)),
            ),
          ),
          IconButton(
            tooltip: 'Delete alarm',
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
    );
  }
}

class _TimeDropdown extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _TimeDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: _timeOptions.contains(value) ? value : '09:00',
      isExpanded: true,
      decoration: const InputDecoration(
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      ),
      items: [
        for (final option in _timeOptions)
          DropdownMenuItem(value: option, child: Text(option)),
      ],
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    );
  }
}

class _NotificationSettingsDraft {
  final int dailyBudget;
  final Map<String, _CategoryPreference> categories;
  final bool quietToday;
  final Set<String> quietDays;
  final List<_BlackoutWindow> blackouts;
  final List<_CustomAlarm> customAlarms;
  final String sound;
  final String vibration;

  const _NotificationSettingsDraft({
    required this.dailyBudget,
    required this.categories,
    required this.quietToday,
    required this.quietDays,
    required this.blackouts,
    required this.customAlarms,
    required this.sound,
    required this.vibration,
  });

  factory _NotificationSettingsDraft.defaults() {
    return _NotificationSettingsDraft(
      dailyBudget: 3,
      categories: {
        for (final key in _categoryLabels.keys)
          key: _CategoryPreference.defaults(key),
      },
      quietToday: false,
      quietDays: const {},
      blackouts: const [
        _BlackoutWindow(
          id: 'sleep',
          start: '22:00',
          end: '07:00',
          enabled: false,
        ),
      ],
      customAlarms: const [],
      sound: 'default',
      vibration: 'standard',
    );
  }

  factory _NotificationSettingsDraft.fromProfile(Map<String, dynamic> data) {
    final settings =
        Map<String, dynamic>.from(data['notificationSettings'] as Map? ?? {});
    final rawCategories =
        Map<String, dynamic>.from(settings['categories'] as Map? ?? {});
    final defaults = _NotificationSettingsDraft.defaults();
    final categories = <String, _CategoryPreference>{};

    for (final key in _categoryLabels.keys) {
      categories[key] = _CategoryPreference.fromMap(
        Map<String, dynamic>.from(rawCategories[key] as Map? ?? {}),
        fallback: defaults.categories[key]!,
      );
    }

    return defaults.copyWith(
      dailyBudget: _intFrom(
        settings['dailyBudget'],
        fallback: _intFrom(data['dailyNotificationBudget'], fallback: 3),
      ).clamp(3, 15),
      categories: categories,
      quietToday: settings['quietToday'] as bool? ??
          data['quietDayMode'] as bool? ??
          false,
      quietDays: (settings['quietDays'] as List? ?? const [])
          .whereType<Object>()
          .map((value) => value.toString())
          .where((value) => value.isNotEmpty)
          .toSet(),
      blackouts: (settings['blackoutWindows'] as List? ?? const [])
          .whereType<Map>()
          .map((value) => _BlackoutWindow.fromMap(
                Map<String, dynamic>.from(value),
              ))
          .toList(),
      customAlarms: (settings['customAlarms'] as List? ?? const [])
          .whereType<Map>()
          .map(
              (value) => _CustomAlarm.fromMap(Map<String, dynamic>.from(value)))
          .toList(),
      sound: _stringFrom(settings['sound'], fallback: 'default'),
      vibration: _stringFrom(settings['vibration'], fallback: 'standard'),
    );
  }

  _NotificationSettingsDraft copyWith({
    int? dailyBudget,
    Map<String, _CategoryPreference>? categories,
    bool? quietToday,
    Set<String>? quietDays,
    List<_BlackoutWindow>? blackouts,
    List<_CustomAlarm>? customAlarms,
    String? sound,
    String? vibration,
  }) {
    return _NotificationSettingsDraft(
      dailyBudget: dailyBudget ?? this.dailyBudget,
      categories: categories ?? this.categories,
      quietToday: quietToday ?? this.quietToday,
      quietDays: quietDays ?? this.quietDays,
      blackouts: blackouts ?? this.blackouts,
      customAlarms: customAlarms ?? this.customAlarms,
      sound: sound ?? this.sound,
      vibration: vibration ?? this.vibration,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'dailyBudget': dailyBudget,
        'categories': categories.map(
          (key, value) => MapEntry(key, value.toFirestore()),
        ),
        'quietToday': quietToday,
        'quietDays': quietDays.toList()..sort(),
        'blackoutWindows':
            blackouts.map((window) => window.toFirestore()).toList(),
        'customAlarms':
            customAlarms.map((alarm) => alarm.toFirestore()).toList(),
        'sound': sound,
        'vibration': vibration,
      };
}

class _CategoryPreference {
  final bool enabled;
  final int cap;

  const _CategoryPreference({required this.enabled, required this.cap});

  factory _CategoryPreference.defaults(String key) {
    final cap = switch (key) {
      'tasks' => 8,
      'coach' => 4,
      'streaks' => 4,
      _ => 3,
    };
    return _CategoryPreference(enabled: true, cap: cap);
  }

  factory _CategoryPreference.fromMap(
    Map<String, dynamic> data, {
    required _CategoryPreference fallback,
  }) {
    return _CategoryPreference(
      enabled: data['enabled'] as bool? ?? fallback.enabled,
      cap: _intFrom(data['cap'], fallback: fallback.cap).clamp(0, 15),
    );
  }

  _CategoryPreference copyWith({bool? enabled, int? cap}) {
    return _CategoryPreference(
      enabled: enabled ?? this.enabled,
      cap: cap ?? this.cap,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'enabled': enabled,
        'cap': cap,
      };
}

class _BlackoutWindow {
  final String id;
  final String start;
  final String end;
  final bool enabled;

  const _BlackoutWindow({
    required this.id,
    required this.start,
    required this.end,
    required this.enabled,
  });

  factory _BlackoutWindow.fromMap(Map<String, dynamic> data) {
    return _BlackoutWindow(
      id: _stringFrom(data['id'], fallback: 'blackout'),
      start: _stringFrom(data['start'], fallback: '22:00'),
      end: _stringFrom(data['end'], fallback: '07:00'),
      enabled: data['enabled'] as bool? ?? true,
    );
  }

  _BlackoutWindow copyWith({
    String? start,
    String? end,
    bool? enabled,
  }) {
    return _BlackoutWindow(
      id: id,
      start: start ?? this.start,
      end: end ?? this.end,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'id': id,
        'start': start,
        'end': end,
        'enabled': enabled,
      };
}

class _CustomAlarm {
  final String id;
  final String label;
  final String time;
  final bool enabled;

  const _CustomAlarm({
    required this.id,
    required this.label,
    required this.time,
    required this.enabled,
  });

  factory _CustomAlarm.fromMap(Map<String, dynamic> data) {
    return _CustomAlarm(
      id: _stringFrom(data['id'], fallback: 'alarm'),
      label: _stringFrom(data['label'], fallback: 'Custom alarm'),
      time: _stringFrom(data['time'], fallback: '09:00'),
      enabled: data['enabled'] as bool? ?? true,
    );
  }

  _CustomAlarm copyWith({String? time, bool? enabled}) {
    return _CustomAlarm(
      id: id,
      label: label,
      time: time ?? this.time,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'id': id,
        'label': label,
        'time': time,
        'enabled': enabled,
      };
}

const _categoryLabels = {
  'tasks': 'Tasks',
  'coach': 'Coach',
  'streaks': 'Streaks',
  'custom': 'Custom alarms',
};

final _timeOptions = List.generate(
  24,
  (index) => '${index.toString().padLeft(2, '0')}:00',
);

String _dateKey(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

String _quietDayLabel(DateTime date) {
  final today = DateTime.now();
  if (_dateKey(date) == _dateKey(today)) return 'Today';
  if (_dateKey(date) == _dateKey(today.add(const Duration(days: 1)))) {
    return 'Tomorrow';
  }
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return weekdays[date.weekday - 1];
}

int _intFrom(Object? value, {required int fallback}) {
  if (value is int) return value;
  if (value is num) return value.round();
  return fallback;
}

String _stringFrom(Object? value, {required String fallback}) {
  if (value is String && value.trim().isNotEmpty) return value.trim();
  return fallback;
}
