import 'dart:convert';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:optivus2/core/liquid_ui/liquid_ui.dart';
import 'package:optivus2/core/providers.dart';
import 'package:optivus2/models/habit_log_model.dart';
import 'package:optivus2/models/habit_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Specialized hydration tracker per UF §8.4.5.
/// Features: Auto-target (weight * 35), Quick-log, Custom containers,
/// Hourly chart, and Smart insights (Heat boost, Front-load).
/// Cloud sync: Containers stored in Firestore.
/// Weather hook: Auto-detects heat wave using IP-based weather API.
class HydrationTrackerView extends ConsumerStatefulWidget {
  final HabitModel habit;

  const HydrationTrackerView({super.key, required this.habit});

  @override
  ConsumerState<HydrationTrackerView> createState() => _HydrationTrackerViewState();
}

class _HydrationTrackerViewState extends ConsumerState<HydrationTrackerView> {
  bool _heatBoostEnabled = false;
  bool _isAutoWeather = false;
  double? _currentTemp;
  bool _isWeatherLoading = false;
  num? _targetOverride;
  bool _reminderScheduledToday = false;

  String get _targetKey => 'hydration_target_override_${widget.habit.id}';
  String get _weatherCacheKey => 'hydration_weather_cache';

  @override
  void initState() {
    super.initState();
    _loadPersistedTarget();
    _migrateAndFetchWeather();
  }

  Future<void> _loadPersistedTarget() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getInt(_targetKey);
      if (saved != null && mounted) {
        setState(() => _targetOverride = saved);
      }
    } catch (e) {
      debugPrint('Target load error: $e');
    }
  }

  Future<void> _persistTarget(num? value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (value == null) {
        await prefs.remove(_targetKey);
      } else {
        await prefs.setInt(_targetKey, value.round());
      }
    } catch (e) {
      debugPrint('Target persist error: $e');
    }
  }

  Future<void> _migrateAndFetchWeather() async {
    await _migrateLocalContainers();
    _fetchWeather();
  }

  /// Migrates containers from SharedPreferences to Firestore once.
  Future<void> _migrateLocalContainers() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'hydration_containers_${widget.habit.id}';
      final saved = prefs.getString(key);
      if (saved != null) {
        final List<dynamic> local = jsonDecode(saved);
        final batch = FirebaseFirestore.instance.batch();
        final collection = FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('hydration_containers');
        
        for (final item in local) {
          final docRef = collection.doc();
          batch.set(docRef, {
            'name': item['name'],
            'amount': item['amount'],
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
        await batch.commit();
        await prefs.remove(key); // Migration complete
      }
    } catch (e) {
      debugPrint('Migration error: $e');
    }
  }

  /// Automated weather hook: Uses IP-based location and Open-Meteo.
  /// Caches result in SharedPreferences for 30 minutes to reduce API calls.
  Future<void> _fetchWeather() async {
    if (_isWeatherLoading) return;

    // Check cache first
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_weatherCacheKey);
      if (cached != null) {
        final data = jsonDecode(cached) as Map<String, dynamic>;
        final cachedAt = DateTime.tryParse(data['cachedAt'] as String? ?? '');
        if (cachedAt != null &&
            DateTime.now().difference(cachedAt).inMinutes < 30) {
          final temp = (data['temp'] as num?)?.toDouble();
          if (temp != null && mounted) {
            setState(() {
              _currentTemp = temp;
              if (temp > 35) {
                _heatBoostEnabled = true;
                _isAutoWeather = true;
              }
            });
          }
          return; // cache hit — skip network
        }
      }
    } catch (_) {}

    setState(() => _isWeatherLoading = true);
    
    try {
      // 1. Get Lat/Lng from IP (No API key needed)
      final locRes = await http.get(Uri.parse('https://ipapi.co/json/'));
      if (locRes.statusCode == 200) {
        final locData = jsonDecode(locRes.body);
        final lat = locData['latitude'];
        final lon = locData['longitude'];

        // 2. Get Current Weather from Open-Meteo
        final weatherRes = await http.get(Uri.parse(
          'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current_weather=true'
        ));

        if (weatherRes.statusCode == 200) {
          final weatherData = jsonDecode(weatherRes.body);
          final temp = weatherData['current_weather']['temperature'] as double;

          // Cache result
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(_weatherCacheKey, jsonEncode({
              'temp': temp,
              'cachedAt': DateTime.now().toIso8601String(),
            }));
          } catch (_) {}

          if (mounted) {
            setState(() {
              _currentTemp = temp;
              if (temp > 35) {
                _heatBoostEnabled = true;
                _isAutoWeather = true;
              }
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Weather fetch error: $e');
    } finally {
      if (mounted) setState(() => _isWeatherLoading = false);
    }
  }

  /// Schedules a hydration catch-up reminder 1 hour from now when
  /// front-load detection fires. Only schedules once per session.
  Future<void> _scheduleHydrationReminder(num remaining) async {
    if (_reminderScheduledToday) return;
    _reminderScheduledToday = true;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final notifService = ref.read(notificationServiceProvider);
      final fireAt = DateTime.now().add(const Duration(hours: 1));
      await notifService.schedule(
        id: 'hydration_catchup_${widget.habit.id}'.hashCode & 0x7FFFFFFF,
        title: '💧 Hydration check-in',
        body: '${remaining.round()} ml to go — grab a glass!',
        at: fireAt,
      );
    } catch (e) {
      debugPrint('Hydration reminder error: $e');
    }
  }

  Future<void> _log(num amount, {String? source}) async {
    try {
      final service = ref.read(habitServiceProvider);
      await service.logGood(
        widget.habit.id,
        amount: amount,
        unit: 'ml',
        source: source ?? 'tracker_hydration',
      );
      HapticFeedback.mediumImpact();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to log: $e'), backgroundColor: kCoral),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Center(child: Text('Not authenticated.'));

    final logsAsync = ref.watch(todayHabitLogsProvider);
    
    // Watch profile for biometrics
    final profileStream = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('profile')
        .doc('main')
        .snapshots();

    // Stream containers from Firestore (Cloud Sync)
    final containersStream = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('hydration_containers')
        .orderBy('createdAt', descending: true)
        .snapshots();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: profileStream,
      builder: (context, profileSnap) {
        return logsAsync.when(
          loading: () => const _LoadingState(),
          error: (e, __) => _ErrorState(message: e.toString()),
          data: (allLogs) {
            final habitLogs = allLogs.where((l) => l.habitId == widget.habit.id).toList();
            final todayTotal = habitLogs.fold<num>(0, (total, l) => total + (l.quantity ?? 0));
            
            final biometrics = profileSnap.data?.data()?['biometrics'] as Map?;
            final weight = (biometrics?['weightKg'] as num?)?.toDouble() ?? 70.0;
            final autoTarget = (weight * 35).round();
            num target = _targetOverride ?? autoTarget;
            if (_heatBoostEnabled) target += 500;

            final progress = (todayTotal / target).clamp(0.0, 1.0);

            // Smart reminder: schedule catch-up notification when behind
            final now = DateTime.now();
            final hoursPassed = (now.hour - 7).clamp(0, 16);
            final expectedPct = hoursPassed / 16;
            final isBehind = todayTotal < (target * expectedPct * 0.8);
            if (isBehind && now.hour >= 9 && now.hour < 20) {
              final remaining = target - todayTotal;
              _scheduleHydrationReminder(remaining);
            }

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: containersStream,
              builder: (context, containersSnap) {
                final containers = containersSnap.data?.docs.map((d) => <String, dynamic>{
                  'id': d.id,
                  'name': d.data()['name'],
                  'amount': d.data()['amount'],
                }).toList() ?? <Map<String, dynamic>>[];

                return SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _HydrationHeader(
                        progress: progress,
                        current: todayTotal,
                        target: target,
                        accent: kBlue,
                        isOverride: _targetOverride != null,
                        onEditTarget: () => _showEditTargetDialog(autoTarget),
                      ),
                      const SizedBox(height: 24),
                      
                      _SectionLabel(label: 'Quick Log'),
                      const SizedBox(height: 12),
                      _QuickLogButtons(
                        onLog: _log,
                        onCustom: _showCustomLogDialog,
                      ),
                      
                      const SizedBox(height: 24),
                      _SectionLabel(
                        label: 'My Containers',
                        onAction: _showAddContainerDialog,
                        actionLabel: 'Add',
                      ),
                      const SizedBox(height: 12),
                      _CustomContainersList(
                        containers: containers,
                        onLog: _log,
                        onDelete: (id, name) => _confirmDeleteContainer(id, name),
                      ),

                      const SizedBox(height: 24),
                      _SectionLabel(label: 'Today\'s Hourly Intake'),
                      const SizedBox(height: 12),
                      _HourlyDistributionChart(logs: habitLogs),

                      const SizedBox(height: 24),
                      _SectionLabel(label: 'Smart Insights'),
                      const SizedBox(height: 12),
                      _HydrationInsights(
                        current: todayTotal,
                        target: target,
                        heatBoostEnabled: _heatBoostEnabled,
                        isAutoWeather: _isAutoWeather,
                        currentTemp: _currentTemp,
                        isWeatherLoading: _isWeatherLoading,
                        onToggleHeatBoost: (val) => setState(() {
                          _heatBoostEnabled = val;
                          if (!val) _isAutoWeather = false;
                        }),
                        onRefreshWeather: _fetchWeather,
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _deleteContainer(String id) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('hydration_containers')
        .doc(id)
        .delete();
  }

  void _confirmDeleteContainer(String id, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kBg,
        title: const Text('Delete Container', style: TextStyle(fontWeight: FontWeight.w900)),
        content: Text('Remove "$name" from your containers?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: kSub)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteContainer(id);
            },
            child: const Text('Delete', style: TextStyle(color: kCoral, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  void _showCustomLogDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kBg,
        title: const Text('Custom Amount', style: TextStyle(fontWeight: FontWeight.w900)),
        content: LiquidTextField(
          hint: 'Amount in ml',
          controller: ctrl,
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: kSub)),
          ),
          LiquidButton(
            label: 'Log',
            height: 40,
            color: kBlue,
            onTap: () {
              final amount = num.tryParse(ctrl.text.trim());
              if (amount != null && amount > 0) {
                Navigator.pop(ctx);
                _log(amount, source: 'tracker_hydration_custom');
              }
            },
          ),
        ],
      ),
    );
  }

  void _showEditTargetDialog(num autoTarget) {
    final ctrl = TextEditingController(
      text: (_targetOverride ?? autoTarget).round().toString(),
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kBg,
        title: const Text('Daily Target', style: TextStyle(fontWeight: FontWeight.w900)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Auto-calculated: ${autoTarget.round()} ml',
              style: TextStyle(color: kSub.withValues(alpha: 0.8), fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            LiquidTextField(
              hint: 'Target in ml',
              controller: ctrl,
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          if (_targetOverride != null)
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                setState(() => _targetOverride = null);
                _persistTarget(null);
              },
              child: const Text('Reset to auto', style: TextStyle(color: kAmber, fontWeight: FontWeight.w800)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: kSub)),
          ),
          LiquidButton(
            label: 'Set',
            height: 40,
            color: kBlue,
            onTap: () {
              final val = num.tryParse(ctrl.text.trim());
              if (val != null && val > 0) {
                Navigator.pop(ctx);
                setState(() => _targetOverride = val.round());
                _persistTarget(val.round());
              }
            },
          ),
        ],
      ),
    );
  }

  void _showAddContainerDialog() {
    final nameCtrl = TextEditingController();
    final amountCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kBg,
        title: const Text('New Container', style: TextStyle(fontWeight: FontWeight.w900)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LiquidTextField(hint: 'Label (e.g. Gym Bottle)', controller: nameCtrl),
            const SizedBox(height: 12),
            LiquidTextField(
              hint: 'Amount in ml (e.g. 750)',
              controller: amountCtrl,
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: kSub)),
          ),
          LiquidButton(
            label: 'Save',
            height: 40,
            onTap: () async {
              final name = nameCtrl.text.trim();
              final amount = num.tryParse(amountCtrl.text.trim());
              final uid = FirebaseAuth.instance.currentUser?.uid;
              if (name.isNotEmpty && amount != null && uid != null) {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .collection('hydration_containers')
                    .add({
                  'name': name,
                  'amount': amount,
                  'createdAt': FieldValue.serverTimestamp(),
                });
                if (!context.mounted) return;
                Navigator.pop(context);
              }
            },
          ),
        ],
      ),
    );
  }
}

class _HydrationHeader extends StatelessWidget {
  final double progress;
  final num current;
  final num target;
  final Color accent;
  final bool isOverride;
  final VoidCallback onEditTarget;

  const _HydrationHeader({
    required this.progress,
    required this.current,
    required this.target,
    required this.accent,
    this.isOverride = false,
    required this.onEditTarget,
  });

  @override
  Widget build(BuildContext context) {
    return LiquidCard(
      radius: 28,
      child: Row(
        children: [
          LiquidProgressRing(
            progress: progress,
            size: 100,
            stroke: 10,
            fillColor: accent,
            center: Icon(Icons.water_drop_rounded, color: accent, size: 32),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${current.round()} ml',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: accent,
                  ),
                ),
                GestureDetector(
                  onTap: onEditTarget,
                  child: Row(
                    children: [
                      Text(
                        'of ${target.round()} ml goal',
                        style: TextStyle(
                          color: kSub.withValues(alpha: 0.7),
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        isOverride ? Icons.edit_rounded : Icons.tune_rounded,
                        size: 14,
                        color: kSub.withValues(alpha: 0.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  progress >= 1.0 ? 'Goal achieved! 🎉' : '${((1 - progress) * target).round()} ml remaining',
                  style: TextStyle(
                    color: progress >= 1.0 ? kMint : kInk,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickLogButtons extends StatelessWidget {
  final Function(num) onLog;
  final VoidCallback onCustom;

  const _QuickLogButtons({required this.onLog, required this.onCustom});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            _LogBtn(label: '250ml', amount: 250, onLog: onLog),
            const SizedBox(width: 10),
            _LogBtn(label: '500ml', amount: 500, onLog: onLog),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _LogBtn(label: '1L', amount: 1000, onLog: onLog),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: onCustom,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: kAmber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: kAmber.withValues(alpha: 0.2)),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.edit_rounded, color: kAmber, size: 20),
                      SizedBox(height: 4),
                      Text('Custom', style: TextStyle(fontWeight: FontWeight.w900, color: kAmber)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _LogBtn extends StatelessWidget {
  final String label;
  final num amount;
  final Function(num) onLog;

  const _LogBtn({required this.label, required this.amount, required this.onLog});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: () => onLog(amount),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: kBlue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kBlue.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              const Icon(Icons.add_rounded, color: kBlue, size: 20),
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w900, color: kBlue)),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomContainersList extends StatelessWidget {
  final List<Map<String, dynamic>> containers;
  final Function(num) onLog;
  final Function(String, String) onDelete;

  const _CustomContainersList({
    required this.containers,
    required this.onLog,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (containers.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: kInk.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kInk.withValues(alpha: 0.05)),
        ),
        child: const Center(
          child: Text(
            'Save your favorite bottles or glasses here.',
            style: TextStyle(color: kSub, fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: containers.map((c) {
        final name = (c['name'] as String?) ?? '';
        return GestureDetector(
          onTap: () => onLog(c['amount'] as num),
          onLongPress: () => onDelete(c['id'] as String, name),
          child: _ContainerChip(name: name, amount: c['amount'] as num),
        );
      }).toList(),
    );
  }
}

class _ContainerChip extends StatelessWidget {
  final String name;
  final num amount;

  const _ContainerChip({required this.name, required this.amount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: kInk.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.local_drink_rounded, color: kBlue, size: 16),
          const SizedBox(width: 8),
          Text(
            name,
            style: const TextStyle(fontWeight: FontWeight.w800, color: kInk, fontSize: 14),
          ),
          const SizedBox(width: 6),
          Text(
            '${amount.round()}ml',
            style: TextStyle(fontWeight: FontWeight.w600, color: kSub.withValues(alpha: 0.7), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _HourlyDistributionChart extends StatelessWidget {
  final List<HabitLog> logs;

  const _HourlyDistributionChart({required this.logs});

  @override
  Widget build(BuildContext context) {
    final hourlyData = List.filled(24, 0.0);
    for (final log in logs) {
      hourlyData[log.occurredAt.hour] += (log.quantity ?? 0).toDouble();
    }

    final maxIntake = hourlyData.reduce(math.max);
    
    return LiquidCard(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: SizedBox(
        height: 100,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(24, (i) {
            final val = hourlyData[i];
            final h = maxIntake == 0 ? 0.0 : (val / maxIntake).clamp(0.05, 1.0);
            final isActiveHour = i >= 7 && i <= 22;

            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: FractionallySizedBox(
                          heightFactor: h,
                          child: Container(
                            decoration: BoxDecoration(
                              color: kBlue.withValues(alpha: isActiveHour ? 0.8 : 0.3),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (i % 6 == 0)
                      Text(
                        '${i}h',
                        style: TextStyle(fontSize: 8, color: kSub.withValues(alpha: 0.5), fontWeight: FontWeight.w700),
                      )
                    else
                      const SizedBox(height: 10),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _HydrationInsights extends StatelessWidget {
  final num current;
  final num target;
  final bool heatBoostEnabled;
  final bool isAutoWeather;
  final double? currentTemp;
  final bool isWeatherLoading;
  final ValueChanged<bool> onToggleHeatBoost;
  final VoidCallback onRefreshWeather;

  const _HydrationInsights({
    required this.current,
    required this.target,
    required this.heatBoostEnabled,
    required this.isAutoWeather,
    this.currentTemp,
    required this.isWeatherLoading,
    required this.onToggleHeatBoost,
    required this.onRefreshWeather,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final hoursPassed = (now.hour - 7).clamp(0, 16); 
    final expectedIntakePct = (hoursPassed / 16);
    final isBehind = current < (target * expectedIntakePct * 0.8);

    return Column(
      children: [
        if (isBehind && now.hour < 20)
          LiquidCard(
            tint: kRose.withValues(alpha: 0.08),
            child: Row(
              children: [
                const Icon(Icons.priority_high_rounded, color: kRose),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Front-load your intake',
                        style: TextStyle(fontWeight: FontWeight.w900, color: kInk),
                      ),
                      Text(
                        'You\'re a bit behind for this time of day. Try to catch up before evening.',
                        style: TextStyle(fontSize: 13, color: kSub.withValues(alpha: 0.8), height: 1.3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        if (isBehind && now.hour < 20) const SizedBox(height: 12),
        LiquidCard(
          child: Row(
            children: [
              GestureDetector(
                onTap: onRefreshWeather,
                child: isWeatherLoading 
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: kAmber))
                  : const Icon(Icons.wb_sunny_rounded, color: kAmber),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Heat Wave Boost',
                          style: TextStyle(fontWeight: FontWeight.w900, color: kInk),
                        ),
                        if (isAutoWeather) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: kMint.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
                            child: const Text('AUTO', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: kMint)),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      currentTemp != null 
                        ? 'Detected ${currentTemp!.toStringAsFixed(1)}°C. Boosting +500ml.'
                        : 'Increase target by 500ml for hot weather (>35°C).',
                      style: TextStyle(fontSize: 13, color: kSub.withValues(alpha: 0.8), height: 1.3),
                    ),
                  ],
                ),
              ),
              LiquidToggle(value: heatBoostEnabled, onChanged: onToggleHeatBoost),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _SectionLabel({required this.label, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: kInk),
        ),
        if (actionLabel != null)
          GestureDetector(
            onTap: onAction,
            child: Text(
              actionLabel!,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: kAmber),
            ),
          ),
      ],
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();
  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 200,
      child: Center(child: CircularProgressIndicator(color: kBlue)),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({required this.message});
  @override
  Widget build(BuildContext context) {
    return LiquidCard(
      child: Text('Error: $message', style: const TextStyle(color: kCoral)),
    );
  }
}
