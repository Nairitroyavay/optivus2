import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:optivus2/core/constants/event_names.dart';
import 'package:optivus2/core/liquid_ui/liquid_ui.dart';
import 'package:optivus2/core/providers.dart';

enum _NotificationFilter { all, unread, coach, tasks, streaks }

final _notificationCenterItemsProvider =
    StreamProvider.autoDispose<List<_NotificationItem>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value(const <_NotificationItem>[]);

  final controller = StreamController<List<_NotificationItem>>();
  final userRef = FirebaseFirestore.instance.collection('users').doc(uid);

  QuerySnapshot<Map<String, dynamic>>? logs;
  QuerySnapshot<Map<String, dynamic>>? scheduled;

  void emit() {
    if (controller.isClosed) return;
    controller.add(_mergeNotificationDocs(logs, scheduled));
  }

  final logSub = userRef
      .collection('notificationLog')
      .orderBy('timestamp', descending: true)
      .limit(150)
      .snapshots()
      .listen((snap) {
    logs = snap;
    emit();
  }, onError: controller.addError);

  final scheduledSub = userRef
      .collection('scheduled_notifications')
      .orderBy('scheduledFor', descending: true)
      .limit(150)
      .snapshots()
      .listen((snap) {
    scheduled = snap;
    emit();
  }, onError: controller.addError);

  ref.onDispose(() {
    unawaited(logSub.cancel());
    unawaited(scheduledSub.cancel());
    unawaited(controller.close());
  });

  return controller.stream;
});

class NotificationCenterScreen extends ConsumerStatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  ConsumerState<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState
    extends ConsumerState<NotificationCenterScreen> {
  _NotificationFilter _filter = _NotificationFilter.all;
  bool _markingRead = false;

  @override
  Widget build(BuildContext context) {
    final asyncItems = ref.watch(_notificationCenterItemsProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: kInk,
        title: const Text(
          'Notifications',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          asyncItems.maybeWhen(
            data: (items) {
              final hasUnread = items.any((item) => item.isUnread);
              return TextButton(
                onPressed: hasUnread && !_markingRead
                    ? () => _markAllRead(items)
                    : null,
                child: _markingRead
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Mark all read'),
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: LiquidBg(
        colors: const [Color(0xFFFBE5E4), Color(0xFFFCF8EE)],
        child: SafeArea(
          bottom: false,
          child: asyncItems.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => _ErrorState(
              message: 'Notifications are unavailable right now.',
              onRetry: () => ref.invalidate(_notificationCenterItemsProvider),
            ),
            data: (items) => _buildContent(items),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(List<_NotificationItem> items) {
    final filtered = items.where(_matchesFilter).toList();
    final grouped = _groupItems(filtered);

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
            child: _FilterBar(filter: _filter, onChanged: _setFilter)),
        if (filtered.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _EmptyState(filter: _filter),
          )
        else
          for (final entry in grouped.entries) ...[
            if (entry.value.isNotEmpty)
              SliverToBoxAdapter(child: _SectionHeader(title: entry.key)),
            SliverList.separated(
              itemCount: entry.value.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = entry.value[index];
                return Padding(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    index == 0 ? 8 : 0,
                    20,
                    index == entry.value.length - 1 ? 18 : 0,
                  ),
                  child: _NotificationRow(
                    item: item,
                    onTap: () => _openNotification(item),
                  ),
                );
              },
            ),
          ],
        const SliverToBoxAdapter(child: SizedBox(height: 28)),
      ],
    );
  }

  void _setFilter(_NotificationFilter filter) {
    if (_filter == filter) return;
    setState(() => _filter = filter);
  }

  bool _matchesFilter(_NotificationItem item) {
    return switch (_filter) {
      _NotificationFilter.all => true,
      _NotificationFilter.unread => item.isUnread,
      _NotificationFilter.coach => item.kind == _NotificationKind.coach,
      _NotificationFilter.tasks => item.kind == _NotificationKind.task,
      _NotificationFilter.streaks => item.kind == _NotificationKind.streak,
    };
  }

  Map<String, List<_NotificationItem>> _groupItems(
    List<_NotificationItem> items,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startOfWeek = today.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 7));

    final groups = <String, List<_NotificationItem>>{
      'Today': [],
      'This week': [],
      'Earlier': [],
    };

    for (final item in items) {
      final day = DateTime(
        item.occurredAt.year,
        item.occurredAt.month,
        item.occurredAt.day,
      );
      if (day == today) {
        groups['Today']!.add(item);
      } else if (!day.isBefore(startOfWeek) && day.isBefore(endOfWeek)) {
        groups['This week']!.add(item);
      } else {
        groups['Earlier']!.add(item);
      }
    }

    return groups;
  }

  Future<void> _markAllRead(List<_NotificationItem> items) async {
    final unread = items.where((item) => item.isUnread).toList();
    if (unread.isEmpty) return;

    setState(() => _markingRead = true);
    try {
      await _markRead(unread);
    } finally {
      if (mounted) setState(() => _markingRead = false);
    }
  }

  Future<void> _openNotification(_NotificationItem item) async {
    final link = item.deepLink;
    unawaited(_markRead([item]));
    unawaited(_emitTapped(item, link));

    try {
      if (link == '/home') {
        context.go(link);
      } else {
        context.push(link);
      }
    } catch (_) {
      if (mounted) context.go('/home');
    }
  }

  Future<void> _markRead(List<_NotificationItem> items) async {
    final batch = FirebaseFirestore.instance.batch();
    final seen = <String>{};
    var writes = 0;

    for (final item in items) {
      final refs = <DocumentReference<Map<String, dynamic>>>[
        if (item.scheduledRef != null) item.scheduledRef!,
        ...item.logRefs,
      ];

      for (final ref in refs) {
        if (!seen.add(ref.path)) continue;
        batch.set(
            ref,
            {
              'read': true,
              'readAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true));
        writes += 1;
      }
    }

    if (writes == 0) return;
    await batch.commit();
  }

  Future<void> _emitTapped(_NotificationItem item, String link) async {
    try {
      await ref.read(eventServiceProvider).emit(
        eventName: EventNames.notificationTapped,
        source: 'notification_center',
        payload: {
          'notifId': item.notifId,
          'category': item.category,
          'deepLink': link,
        },
      );
    } catch (error) {
      debugPrint('[NotificationCenter] notification_tapped skipped: $error');
    }
  }
}

class _FilterBar extends StatelessWidget {
  final _NotificationFilter filter;
  final ValueChanged<_NotificationFilter> onChanged;

  const _FilterBar({required this.filter, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const filters = [
      (_NotificationFilter.all, 'All'),
      (_NotificationFilter.unread, 'Unread'),
      (_NotificationFilter.coach, 'Coach'),
      (_NotificationFilter.tasks, 'Tasks'),
      (_NotificationFilter.streaks, 'Streaks'),
    ];

    return SizedBox(
      height: 58,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final (value, label) = filters[index];
          final selected = value == filter;
          return ChoiceChip(
            selected: selected,
            label: Text(label),
            onSelected: (_) => onChanged(value),
            showCheckmark: false,
            selectedColor: kInk,
            backgroundColor: Colors.white.withValues(alpha: 0.62),
            labelStyle: TextStyle(
              color: selected ? Colors.white : kInk,
              fontWeight: FontWeight.w800,
            ),
            side: BorderSide(
              color: selected ? kInk : Colors.white.withValues(alpha: 0.72),
            ),
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 2),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: kSub.withValues(alpha: 0.86),
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

class _NotificationRow extends StatelessWidget {
  final _NotificationItem item;
  final VoidCallback onTap;

  const _NotificationRow({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return LiquidCard.solid(
      radius: 18,
      padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
      tint: Colors.white.withValues(alpha: item.isUnread ? 0.66 : 0.48),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 54,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatTime(item.occurredAt),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: kInk,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (item.isUnread)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: kAmber,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: kInk,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              height: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _StatusBadge(status: item.status),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      item.snippet,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: kSub.withValues(alpha: 0.92),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(
                          _iconForKind(item.kind),
                          size: 15,
                          color: kInk.withValues(alpha: 0.72),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            _linkLabel(item),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: kInk.withValues(alpha: 0.76),
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Padding(
                padding: EdgeInsets.only(top: 28),
                child: Icon(Icons.chevron_right_rounded, color: kSub),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.26)),
      ),
      child: Text(
        _statusLabel(status),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final _NotificationFilter filter;

  const _EmptyState({required this.filter});

  @override
  Widget build(BuildContext context) {
    final text = filter == _NotificationFilter.all
        ? 'No notifications yet.'
        : 'No matching notifications.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: LiquidCard(
          radius: 22,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.72),
                  shape: BoxShape.circle,
                ),
                child:
                    const Icon(Icons.notifications_none_rounded, color: kInk),
              ),
              const SizedBox(height: 16),
              Text(
                text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: kInk,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'New reminders and coach nudges will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: kSub.withValues(alpha: 0.9),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: LiquidCard(
          radius: 22,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: kCoral, size: 34),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: kInk,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: onRetry,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

List<_NotificationItem> _mergeNotificationDocs(
  QuerySnapshot<Map<String, dynamic>>? logs,
  QuerySnapshot<Map<String, dynamic>>? scheduled,
) {
  final drafts = <String, _NotificationDraft>{};

  for (final doc in scheduled?.docs ?? const []) {
    final data = doc.data();
    final expanded = _expandedNotificationData(data);
    final notifId = _notifIdFrom(expanded, doc.id);
    final draft =
        drafts.putIfAbsent(notifId, () => _NotificationDraft(notifId));
    draft.scheduledRef = doc.reference;
    draft.scheduledData = data;
    draft.read = draft.read || data['read'] == true;
    draft.category ??= _asString(expanded['category']);
    draft.status ??= _asString(expanded['status']);
    draft.title ??= _asString(expanded['title']);
    draft.snippet ??=
        _asString(expanded['body']) ?? _asString(expanded['message']);
    draft.occurredAt ??= _asDateTime(expanded['scheduledFor']) ??
        _asDateTime(expanded['fireAt']) ??
        _asDateTime(expanded['createdAt']);
    draft.deepLink ??= _explicitLink(expanded);
  }

  for (final doc in logs?.docs ?? const []) {
    final data = doc.data();
    final expanded = _expandedNotificationData(data);
    final notifId = _notifIdFrom(expanded, doc.id);
    final draft =
        drafts.putIfAbsent(notifId, () => _NotificationDraft(notifId));
    draft.logRefs.add(doc.reference);
    draft.logData.add(data);
    draft.read = draft.read || data['read'] == true;

    final timestamp = _asDateTime(expanded['timestamp']) ??
        _asDateTime(expanded['createdAt']) ??
        _asDateTime(expanded['updatedAt']);
    if (timestamp != null &&
        (draft.latestLogAt == null || timestamp.isAfter(draft.latestLogAt!))) {
      draft.latestLogAt = timestamp;
      draft.status = _asString(expanded['status']) ??
          _asString(expanded['eventName']) ??
          draft.status;
      draft.category = _asString(expanded['category']) ?? draft.category;
      draft.title = _asString(expanded['title']) ?? draft.title;
      draft.snippet = _asString(expanded['body']) ??
          _asString(expanded['message']) ??
          _asString(expanded['reason']) ??
          draft.snippet;
      draft.deepLink = _explicitLink(expanded) ?? draft.deepLink;
    }
  }

  final items = drafts.values.map((draft) => draft.toItem()).toList()
    ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));

  return items;
}

class _NotificationDraft {
  final String notifId;
  DocumentReference<Map<String, dynamic>>? scheduledRef;
  final List<DocumentReference<Map<String, dynamic>>> logRefs = [];
  Map<String, dynamic>? scheduledData;
  final List<Map<String, dynamic>> logData = [];
  String? category;
  String? status;
  String? title;
  String? snippet;
  String? deepLink;
  DateTime? occurredAt;
  DateTime? latestLogAt;
  bool read = false;

  _NotificationDraft(this.notifId);

  _NotificationItem toItem() {
    final rawData = <String, dynamic>{
      if (scheduledData != null) ...scheduledData!,
      for (final log in logData) ...log,
    };
    final data = _expandedNotificationData(rawData);
    final resolvedCategory =
        category ?? _asString(data['category']) ?? 'general';
    final resolvedStatus = status ?? _asString(data['status']) ?? 'scheduled';
    final resolvedTitle = title ??
        _asString(data['title']) ??
        _titleForCategory(resolvedCategory);
    final resolvedSnippet = snippet ??
        _asString(data['body']) ??
        _asString(data['message']) ??
        _asString(data['intentDescription']) ??
        'Tap to open this notification.';
    final resolvedAt = latestLogAt ??
        occurredAt ??
        _asDateTime(data['scheduledFor']) ??
        _asDateTime(data['fireAt']) ??
        _asDateTime(data['timestamp']) ??
        _asDateTime(data['createdAt']) ??
        DateTime.now();
    final link = _resolveDeepLink(deepLink, resolvedCategory, data);

    return _NotificationItem(
      notifId: notifId,
      title: resolvedTitle,
      snippet: resolvedSnippet,
      status: resolvedStatus,
      category: resolvedCategory,
      occurredAt: resolvedAt.toLocal(),
      deepLink: link,
      read: read || _isReadStatus(resolvedStatus),
      scheduledRef: scheduledRef,
      logRefs: List.unmodifiable(logRefs),
      kind: _kindFor(resolvedCategory, data),
    );
  }
}

class _NotificationItem {
  final String notifId;
  final String title;
  final String snippet;
  final String status;
  final String category;
  final DateTime occurredAt;
  final String deepLink;
  final bool read;
  final DocumentReference<Map<String, dynamic>>? scheduledRef;
  final List<DocumentReference<Map<String, dynamic>>> logRefs;
  final _NotificationKind kind;

  const _NotificationItem({
    required this.notifId,
    required this.title,
    required this.snippet,
    required this.status,
    required this.category,
    required this.occurredAt,
    required this.deepLink,
    required this.read,
    required this.scheduledRef,
    required this.logRefs,
    required this.kind,
  });

  bool get isUnread => !read;
}

enum _NotificationKind { coach, task, streak, other }

_NotificationKind _kindFor(String category, Map<String, dynamic> data) {
  final expanded = _expandedNotificationData(data);
  final haystack = [
    category,
    _asString(expanded['source']),
    _asString(expanded['eventName']),
    _asString(expanded['type']),
    _asString(expanded['screen']),
    _explicitLink(expanded),
  ].whereType<String>().join(' ').toLowerCase();

  if (haystack.contains('coach')) return _NotificationKind.coach;
  if (haystack.contains('streak') || haystack.contains('slip')) {
    return _NotificationKind.streak;
  }
  if (haystack.contains('task') || haystack.contains('routine')) {
    return _NotificationKind.task;
  }
  return _NotificationKind.other;
}

String _notifIdFrom(Map<String, dynamic> data, String fallback) {
  return _asString(data['notifId']) ??
      _asString(data['notificationId']) ??
      _asString(data['notif_id']) ??
      _asString(data['notification_id']) ??
      fallback;
}

String? _explicitLink(Map<String, dynamic> data) {
  final link = _firstString(data, const [
    'deepLink',
    'deep_link',
    'deeplink',
    'link',
    'route',
    'path',
    'targetRoute',
    'targetPath',
    'target_route',
    'target_path',
    'screen',
  ]);
  return _normalizeRoute(link);
}

String _fallbackLink(String category, Map<String, dynamic> data) {
  final expanded = _expandedNotificationData(data);
  final habitId = _firstString(expanded, const [
    'habitId',
    'habit_id',
    'streakId',
    'streak_id',
  ]);
  final taskId = _firstString(expanded, const [
    'taskId',
    'task_id',
    'routineTaskId',
    'routine_task_id',
  ]);
  final goalId = _firstString(expanded, const [
    'goalId',
    'goal_id',
    'identityId',
    'identity_id',
  ]);
  final activityId = _firstString(expanded, const [
    'activityId',
    'activity_id',
    'fitnessActivityId',
    'fitness_activity_id',
  ]);
  final key = category.toLowerCase();

  if (activityId != null) {
    return '/fitness/activity/${_routeSegment(activityId)}';
  }
  if (goalId != null) return '/identities/${_routeSegment(goalId)}';
  if (habitId != null && (key.contains('streak') || key.contains('slip'))) {
    return '/streaks/${_routeSegment(habitId)}';
  }
  if (habitId != null) return '/habits/${_routeSegment(habitId)}';
  if (taskId != null || key.contains('task') || key.contains('routine')) {
    return '/home';
  }
  return '/home';
}

String _resolveDeepLink(
  String? explicitLink,
  String category,
  Map<String, dynamic> data,
) {
  return _normalizeRoute(explicitLink) ?? _fallbackLink(category, data);
}

String? _normalizeRoute(String? value) {
  if (value == null) return null;
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;

  final shortcut = switch (trimmed.toLowerCase()) {
    'home' => '/home',
    'task' || 'tasks' || 'routine' => '/home',
    'coach' => '/home',
    'fitness' => '/fitness',
    'tracker' || 'habits' => '/habits/new',
    'notifications' => '/notifications',
    _ => null,
  };
  if (shortcut != null) return shortcut;

  String? route;
  if (trimmed.startsWith('/') && !trimmed.startsWith('//')) {
    route = trimmed;
  } else {
    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.hasScheme) {
      if (uri.scheme == 'optivus' || uri.scheme == 'optivus2') {
        final hostPrefix = uri.host.isEmpty ? '' : '/${uri.host}';
        route = '$hostPrefix${uri.path}';
        if (uri.hasQuery) route = '$route?${uri.query}';
      } else if ((uri.scheme == 'https' || uri.scheme == 'http') &&
          _isKnownRoute(uri.path)) {
        route = uri.path;
        if (uri.hasQuery) route = '$route?${uri.query}';
      }
    }
  }

  if (route == null) return null;
  final parsed = Uri.tryParse(route);
  final path = parsed?.path ?? route;
  return _isKnownRoute(path) ? route : null;
}

bool _isKnownRoute(String path) {
  const exactRoutes = {
    '/',
    '/loading',
    '/login',
    '/signup',
    '/onboarding',
    '/home',
    '/home/routine',
    '/home/tracker',
    '/home/coach',
    '/home/goals',
    '/home/profile',
    '/notifications',
    '/habits/new',
    '/settings/routine',
    '/settings/archived-identities',
    '/settings/notifications',
    '/settings/subscription',
    '/settings/security',
    '/settings/fixed-schedule',
    '/settings/skin-care',
    '/settings/eating',
    '/settings/classes',
    '/settings/supplements',
    '/support/report-bug',
    '/support/help',
    '/legal/terms',
    '/legal/privacy',
    '/fitness',
    '/fitness/select',
    '/fitness/stats',
    '/fitness/goals',
    '/fitness/settings',
    '/fitness/pre-start',
    '/fitness/live',
    '/fitness/history',
  };
  if (exactRoutes.contains(path)) return true;
  return RegExp(r'^/habits/[^/]+$').hasMatch(path) ||
      RegExp(r'^/habits/[^/]+/edit$').hasMatch(path) ||
      RegExp(r'^/streaks/[^/]+$').hasMatch(path) ||
      RegExp(r'^/identities/[^/]+$').hasMatch(path) ||
      RegExp(r'^/fitness/activity/[^/]+$').hasMatch(path) ||
      RegExp(r'^/fitness/activity/[^/]+/summary$').hasMatch(path) ||
      RegExp(r'^/fitness/activity/[^/]+/route$').hasMatch(path);
}

Map<String, dynamic> _expandedNotificationData(Map<String, dynamic> data) {
  final expanded = Map<String, dynamic>.from(data);
  for (final key in const [
    'payload',
    'data',
    'metadata',
    'meta',
    'notification',
    'lastLifecycleMetadata',
  ]) {
    final nested = _asMap(data[key]);
    if (nested == null) continue;
    for (final entry in nested.entries) {
      expanded.putIfAbsent(entry.key, () => entry.value);
    }
  }
  return expanded;
}

Map<String, dynamic>? _asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  if (value is String) {
    try {
      final decoded = json.decode(value);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {
      return null;
    }
  }
  return null;
}

String? _firstString(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final value = _asString(data[key]);
    if (value != null && value.trim().isNotEmpty) return value.trim();
  }
  return null;
}

String _routeSegment(String value) => Uri.encodeComponent(value);

String? _asString(Object? value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

DateTime? _asDateTime(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  if (value is String) return DateTime.tryParse(value);
  return null;
}

bool _isReadStatus(String status) {
  final normalized = status.toLowerCase();
  return normalized == 'tapped' ||
      normalized == 'dismissed' ||
      normalized == 'read';
}

String _titleForCategory(String category) {
  final key = category.toLowerCase();
  if (key.contains('coach')) return 'Coach notification';
  if (key.contains('streak')) return 'Streak reminder';
  if (key.contains('task') || key.contains('routine')) return 'Task reminder';
  return 'Notification';
}

String _formatTime(DateTime date) {
  final hour = date.hour;
  final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
  final minute = date.minute.toString().padLeft(2, '0');
  final suffix = hour >= 12 ? 'PM' : 'AM';
  return '$displayHour:$minute $suffix';
}

String _statusLabel(String status) {
  final cleaned = status
      .replaceAll('notification_', '')
      .replaceAll('_', ' ')
      .trim()
      .toLowerCase();
  if (cleaned.isEmpty) return 'Scheduled';
  return cleaned[0].toUpperCase() + cleaned.substring(1);
}

Color _statusColor(String status) {
  final key = status.toLowerCase();
  if (key.contains('tap') || key.contains('deliver') || key.contains('sent')) {
    return const Color(0xFF287F55);
  }
  if (key.contains('miss') ||
      key.contains('dismiss') ||
      key.contains('cancel')) {
    return const Color(0xFF9A4D2B);
  }
  if (key.contains('suppress')) return const Color(0xFF7357A8);
  return const Color(0xFF3F6FAE);
}

IconData _iconForKind(_NotificationKind kind) {
  return switch (kind) {
    _NotificationKind.coach => Icons.psychology_alt_outlined,
    _NotificationKind.task => Icons.check_circle_outline_rounded,
    _NotificationKind.streak => Icons.local_fire_department_outlined,
    _NotificationKind.other => Icons.open_in_new_rounded,
  };
}

String _linkLabel(_NotificationItem item) {
  if (item.deepLink == '/home') return 'Open home';
  return switch (item.kind) {
    _NotificationKind.coach => 'Open coach',
    _NotificationKind.task => 'Open task',
    _NotificationKind.streak => 'Open streak',
    _NotificationKind.other => item.deepLink == '/home' ? 'Open home' : 'Open',
  };
}
