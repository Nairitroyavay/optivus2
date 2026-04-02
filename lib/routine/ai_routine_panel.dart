import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../providers/routine_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PALETTE
// ─────────────────────────────────────────────────────────────────────────────

const _kInk    = Color(0xFF0F111A);
const _kSub    = Color(0xFF6B7280);
const _kCard   = Colors.white;
const _kPurple = Color(0xFF9B8FFF);
const _kShad   = Color(0x12000000);

// ─────────────────────────────────────────────────────────────────────────────
// AI SUGGESTION MODEL
// ─────────────────────────────────────────────────────────────────────────────

enum SuggestionAction { add, remove, reschedule }

class AiSuggestion {
  final String id;
  final String title;       // "Add 30-min Deep Work at 3:00 PM"
  final String reason;      // "You have a free 30-min gap at 3 PM"
  final String emoji;
  final SuggestionAction action;
  final CustomTask? taskToAdd; // if action == add

  const AiSuggestion({
    required this.id,
    required this.title,
    required this.reason,
    required this.emoji,
    required this.action,
    this.taskToAdd,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// PROVIDER  — premium status + custom tasks + AI panel state
// ─────────────────────────────────────────────────────────────────────────────

// (Providers moved to routine_provider.dart)

// AI panel open/closed
final aiPanelOpenProvider = StateProvider<bool>((_) => false);

// ─────────────────────────────────────────────────────────────────────────────
// AI ROUTINE PANEL  (slides up over the timeline)
// ─────────────────────────────────────────────────────────────────────────────

class AiRoutinePanel extends ConsumerStatefulWidget {
  final RoutineState routineState;
  final List<CustomTask> todayTasks;
  final void Function(CustomTask) onAddTask;
  final void Function(String taskId) onRemoveTask;

  const AiRoutinePanel({
    super.key,
    required this.routineState,
    required this.todayTasks,
    required this.onAddTask,
    required this.onRemoveTask,
  });

  @override
  ConsumerState<AiRoutinePanel> createState() => _AiRoutinePanelState();
}

class _AiRoutinePanelState extends ConsumerState<AiRoutinePanel>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _slide;

  final _inputCtrl = TextEditingController();
  bool _loading = false;
  List<AiSuggestion> _suggestions = [];
  final _dismissed = <String>{};

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _slide = CurvedAnimation(
        parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.forward();
    // Auto-fetch suggestions on open
    Future.delayed(const Duration(milliseconds: 400), _fetchSuggestions);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _inputCtrl.dispose();
    super.dispose();
  }

  // ── AI call ───────────────────────────────────────────────────────────────

  Future<void> _fetchSuggestions() async {
    setState(() {
      _loading    = true;
      _suggestions = [];
    });

    // Build context string for the AI
    final todayLabel = _buildTodayContext();

    try {
      final response = await _callClaude(
        systemPrompt: '''You are an elite personal productivity coach inside the Optivus app.
You analyse the user's daily timeline and suggest smart additions or removals.
Respond ONLY with valid JSON — no markdown, no backticks.
Format: {"suggestions":[{"id":"1","title":"short action title","reason":"why this helps","emoji":"one emoji","action":"add|remove","time":"HH:MM","taskTitle":"title if add"}]}
Give 3-5 suggestions. Be specific about times. Keep titles under 8 words.''',
        userMessage: todayLabel,
      );

      final parsed = jsonDecode(response) as Map<String, dynamic>;
      final list   = (parsed['suggestions'] as List?) ?? [];

      setState(() {
        _suggestions = list.map((s) {
          final action = s['action'] == 'remove'
              ? SuggestionAction.remove
              : SuggestionAction.add;
          CustomTask? task;
          if (action == SuggestionAction.add) {
            task = CustomTask(
              id:    s['id'] ?? '${DateTime.now().millisecondsSinceEpoch}',
              title: s['taskTitle'] ?? s['title'],
              emoji: s['emoji'] ?? '📌',
              time:  s['time'] ?? '09:00',
              date:  DateTime.now(),
              color: _kPurple,
            );
          }
          return AiSuggestion(
            id:         s['id'] ?? '${DateTime.now().millisecondsSinceEpoch}',
            title:      s['title'] ?? '',
            reason:     s['reason'] ?? '',
            emoji:      s['emoji'] ?? '✨',
            action:     action,
            taskToAdd:  task,
          );
        }).toList();
        _loading = false;
      });
    } catch (e) {
      // Fallback demo suggestions if API fails
      setState(() {
        _suggestions = _demoSuggestions();
        _loading = false;
      });
    }
  }

  Future<void> _sendUserMessage(String message) async {
    if (message.trim().isEmpty) return;
    _inputCtrl.clear();
    setState(() {
      _loading    = true;
    });

    try {
      final response = await _callClaude(
        systemPrompt: '''You are an AI routine assistant in Optivus.
The user wants to modify their timeline via natural language.
Parse their intent and respond with JSON only.
Format: {"suggestions":[{"id":"1","title":"short action title","reason":"based on your request","emoji":"one emoji","action":"add","time":"HH:MM","taskTitle":"task name"}]}
If they say "add yoga at 7am", create an add suggestion for 07:00 with title "Yoga".
Be literal — do exactly what they ask.''',
        userMessage: 'User request: "$message"\n\n${_buildTodayContext()}',
      );

      final parsed = jsonDecode(response) as Map<String, dynamic>;
      final list   = (parsed['suggestions'] as List?) ?? [];

      setState(() {
        _suggestions = [
          ..._suggestions,
          ...list.map((s) => AiSuggestion(
            id:    s['id'] ?? '${DateTime.now().millisecondsSinceEpoch}',
            title: s['title'] ?? '',
            reason: s['reason'] ?? '',
            emoji: s['emoji'] ?? '📌',
            action: SuggestionAction.add,
            taskToAdd: CustomTask(
              id:    '${DateTime.now().millisecondsSinceEpoch}',
              title: s['taskTitle'] ?? s['title'],
              emoji: s['emoji'] ?? '📌',
              time:  s['time'] ?? '09:00',
              date:  DateTime.now(),
              color: _kPurple,
            ),
          )),
        ];
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
      });
    }
  }

  String _buildTodayContext() {
    final s   = widget.routineState;
    final day = (DateTime.now().weekday - 1).clamp(0, 6);
    final buf = StringBuffer();
    buf.writeln('Today is ${DateTime.now().toString().split(' ')[0]}');
    buf.writeln('Fixed blocks: ${s.fixedBlocks.map((b) => '${b.title} ${b.startLabel}-${b.endLabel}').join(', ')}');
    final skin = s.skinPlanForDay(day);
    if (!skin.isEmpty) {
      buf.writeln('Skin care: ${[...skin.morning,...skin.afternoon,...skin.night].map((x)=>x.name).join(', ')}');
    }
    final meals = s.mealPlanForDay(day).all;
    if (meals.isNotEmpty) {
      buf.writeln('Meals: ${meals.map((m)=>'${m.name} at ${m.time}').join(', ')}');
    }
    if (widget.todayTasks.isNotEmpty) {
      buf.writeln('Custom tasks: ${widget.todayTasks.map((t)=>'${t.title} at ${t.time}').join(', ')}');
    }
    return buf.toString();
  }

  // ── Claude API call ───────────────────────────────────────────────────────

  Future<String> _callClaude({
    required String systemPrompt,
    required String userMessage,
  }) async {
    // Backend URL is set at build time via: --dart-define=AI_BACKEND_URL=https://...
    const backendUrl = String.fromEnvironment('AI_BACKEND_URL', defaultValue: '');
    if (backendUrl.isEmpty) {
      throw Exception('AI backend not configured. Using demo suggestions.');
    }
    final uri = Uri.parse(backendUrl);

    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'systemPrompt': systemPrompt,
          'userMessage': userMessage,
        }),
      );
      
      if (response.statusCode == 200) {
        return response.body;
      } else {
        throw Exception('Failed fetching AI suggestions: ${response.statusCode}');
      }
    } catch (e) {
      // In a real app we'd show an error state
      rethrow;
    }
  }

  // ── Demo suggestions fallback ─────────────────────────────────────────────

  List<AiSuggestion> _demoSuggestions() => [
    AiSuggestion(
      id: '1',
      title: 'Add 20-min Walk at 3:00 PM',
      reason: 'You have a free gap between 3–4 PM. A walk boosts afternoon focus.',
      emoji: '🚶',
      action: SuggestionAction.add,
      taskToAdd: CustomTask(
        id: 'd1', title: 'Afternoon Walk', emoji: '🚶',
        time: '15:00', date: DateTime.now(),
        color: const Color(0xFF60D4A0),
      ),
    ),
    AiSuggestion(
      id: '2',
      title: 'Add 30-min Deep Work at 5:00 PM',
      reason: 'Based on your goal of completing the project, a focused session helps.',
      emoji: '🧠',
      action: SuggestionAction.add,
      taskToAdd: CustomTask(
        id: 'd2', title: 'Deep Work Block', emoji: '🧠',
        time: '17:00', date: DateTime.now(),
        color: _kPurple,
      ),
    ),
    AiSuggestion(
      id: '3',
      title: 'Add Journaling at 10:00 PM',
      reason: 'Closing your day with reflection improves sleep quality.',
      emoji: '📓',
      action: SuggestionAction.add,
      taskToAdd: CustomTask(
        id: 'd3', title: 'Evening Journaling', emoji: '📓',
        time: '22:00', date: DateTime.now(),
        color: const Color(0xFF60B8FF),
      ),
    ),
    AiSuggestion(
      id: '4',
      title: 'Add 15-min Stretching at 7:00 AM',
      reason: 'Starting with light movement before your morning ritual improves energy.',
      emoji: '🤸',
      action: SuggestionAction.add,
      taskToAdd: CustomTask(
        id: 'd4', title: 'Morning Stretching', emoji: '🤸',
        time: '07:00', date: DateTime.now(),
        color: const Color(0xFFFFB830),
      ),
    ),
  ];

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final visible = _suggestions
        .where((s) => !_dismissed.contains(s.id))
        .toList();

    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).animate(_slide),
      child: Container(
        decoration: const BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(color: _kShad, blurRadius: 30,
                offset: Offset(0, -8)),
          ],
        ),
        child: Column(
          children: [
            // ── Handle + header ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      width: 36, height: 4,
                      decoration: BoxDecoration(
                        color: _kInk.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      // AI avatar
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF9B8FFF),
                                Color(0xFF78FDFF)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Text('✦',
                              style: TextStyle(
                                fontSize: 18, color: Colors.white,
                                fontWeight: FontWeight.w900,
                              )),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('AI Coach',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: _kInk,
                                )),
                            Text(
                              _loading
                                  ? 'Analysing your day…'
                                  : '${visible.length} suggestion${visible.length != 1 ? 's' : ''} for today',
                              style: const TextStyle(
                                  fontSize: 12, color: _kSub),
                            ),
                          ],
                        ),
                      ),
                      // Refresh
                      GestureDetector(
                        onTap: _fetchSuggestions,
                        child: Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: _kPurple.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.refresh_rounded,
                              color: _kPurple, size: 18),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Loading shimmer ────────────────────────────────────────
            if (_loading) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _shimmerCard(),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _shimmerCard(),
              ),
            ],

            // ── Suggestion cards ───────────────────────────────────────
            if (!_loading && visible.isNotEmpty)
              SizedBox(
                height: 200,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  physics: const BouncingScrollPhysics(),
                  itemCount: visible.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(width: 12),
                  itemBuilder: (_, i) =>
                      _SuggestionCard(
                    suggestion: visible[i],
                    onAccept: () {
                      if (visible[i].taskToAdd != null) {
                        widget.onAddTask(visible[i].taskToAdd!);
                      }
                      setState(() =>
                          _dismissed.add(visible[i].id));
                    },
                    onDismiss: () => setState(() =>
                        _dismissed.add(visible[i].id)),
                  ),
                ),
              ),

            if (!_loading && visible.isEmpty)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: Column(
                    children: [
                      const Text('✦',
                          style: TextStyle(fontSize: 32,
                              color: _kPurple)),
                      const SizedBox(height: 8),
                      const Text('Your day looks optimised!',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: _kInk,
                          )),
                      const SizedBox(height: 4),
                      Text('Ask me anything below',
                          style: TextStyle(
                              fontSize: 13,
                              color: _kSub.withValues(alpha: 0.7))),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 8),

            // ── Ask AI text input ──────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(
                20, 0, 20,
                MediaQuery.of(context).viewInsets.bottom +
                    MediaQuery.of(context).padding.bottom + 12,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputCtrl,
                      style: const TextStyle(
                          fontSize: 14, color: _kInk),
                      decoration: InputDecoration(
                        hintText:
                            'Ask AI… e.g. "add yoga at 7am"',
                        hintStyle: TextStyle(
                            color: _kSub.withValues(alpha: 0.5),
                            fontSize: 14),
                        filled: true,
                        fillColor: const Color(0xFFF2F0F8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                        suffixIcon: _loading
                            ? const Padding(
                                padding:
                                    EdgeInsets.all(10),
                                child:
                                    SizedBox(
                                  width: 18, height: 18,
                                  child:
                                      CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: _kPurple,
                                  ),
                                ))
                            : null,
                      ),
                      onSubmitted: _sendUserMessage,
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () =>
                        _sendUserMessage(_inputCtrl.text),
                    child: Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF9B8FFF),
                              Color(0xFF78FDFF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                          Icons.send_rounded,
                          color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _shimmerCard() {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: _kPurple.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(children: [
        const SizedBox(width: 16),
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: _kPurple.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        const SizedBox(width: 12),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(width: 160, height: 12,
                decoration: BoxDecoration(
                  color: _kPurple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                )),
            const SizedBox(height: 8),
            Container(width: 100, height: 10,
                decoration: BoxDecoration(
                  color: _kPurple.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(6),
                )),
          ],
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SUGGESTION CARD
// ─────────────────────────────────────────────────────────────────────────────

class _SuggestionCard extends StatelessWidget {
  final AiSuggestion suggestion;
  final VoidCallback onAccept;
  final VoidCallback onDismiss;

  const _SuggestionCard({
    required this.suggestion,
    required this.onAccept,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kPurple.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: _kPurple.withValues(alpha: 0.15), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon + action chip
          Row(
            children: [
              Text(suggestion.emoji,
                  style: const TextStyle(fontSize: 24)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: suggestion.action == SuggestionAction.add
                      ? const Color(0xFF60D4A0).withValues(alpha: 0.2)
                      : Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  suggestion.action == SuggestionAction.add
                      ? '+ Add'
                      : '− Remove',
                  style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w700,
                    color: suggestion.action == SuggestionAction.add
                        ? const Color(0xFF1A8A5A)
                        : Colors.red,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Title
          Text(suggestion.title,
              maxLines: 2,
              style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w800,
                color: _kInk, height: 1.3,
              )),
          const SizedBox(height: 4),

          // Reason
          Expanded(
            child: Text(suggestion.reason,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: _kSub.withValues(alpha: 0.85),
                  height: 1.45,
                )),
          ),
          const SizedBox(height: 10),

          // Accept / Dismiss
          Row(children: [
            Expanded(
              child: GestureDetector(
                onTap: onAccept,
                child: Container(
                  height: 34,
                  decoration: BoxDecoration(
                    color: _kPurple,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: Text('Accept',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        )),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onDismiss,
              child: Container(
                height: 34, width: 34,
                decoration: BoxDecoration(
                  color: _kSub.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.close_rounded,
                    size: 16,
                    color: _kSub.withValues(alpha: 0.7)),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PREMIUM PAYWALL SHEET
// ─────────────────────────────────────────────────────────────────────────────

class PremiumPaywallSheet extends StatelessWidget {
  final VoidCallback onUnlock;
  const PremiumPaywallSheet({super.key, required this.onUnlock});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: const BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: _kInk.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Icon
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF9B8FFF), Color(0xFF78FDFF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Center(
                child: Text('✦',
                    style: TextStyle(
                        fontSize: 28, color: Colors.white)),
              ),
            ),
            const SizedBox(height: 16),

            const Text('Unlock AI Coach',
                style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w900,
                  color: _kInk,
                )),
            const SizedBox(height: 6),
            const Text(
              'Your personal AI that analyses your timeline\nand optimises every hour of your day.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14, color: _kSub, height: 1.55),
            ),
            const SizedBox(height: 24),

            // Feature list
            ...[
              ('✦', 'Smart task suggestions based on your goals'),
              ('🗓️', 'Auto-schedule free gaps in your day'),
              ('💬', 'Ask AI to add/remove tasks naturally'),
              ('📊', 'Weekly performance insights'),
              ('🔒', 'Priority support & early features'),
            ].map((f) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(children: [
                Text(f.$1,
                    style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 12),
                Text(f.$2,
                    style: const TextStyle(
                      fontSize: 14, color: _kInk,
                      fontWeight: FontWeight.w500,
                    )),
              ]),
            )),

            const SizedBox(height: 20),

            // Unlock button
            GestureDetector(
              onTap: onUnlock,
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF9B8FFF), Color(0xFF78FDFF)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: _kPurple.withValues(alpha: 0.35),
                      blurRadius: 16, offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text('Unlock Premium',
                      style: TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w900,
                        color: Colors.white,
                      )),
                ),
              ),
            ),
            const SizedBox(height: 12),

            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Maybe later',
                  style: TextStyle(
                      fontSize: 13, color: _kSub)),
            ),
          ],
        ),
      ),
    );
  }
}
