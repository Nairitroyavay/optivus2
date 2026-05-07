import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus2/core/constants/event_names.dart';
import 'package:optivus2/core/providers.dart';

class ComebackModal extends ConsumerStatefulWidget {
  final Map<String, dynamic> comeback;
  final Future<void> Function() onPrimary;

  const ComebackModal({
    super.key,
    required this.comeback,
    required this.onPrimary,
  });

  @override
  ConsumerState<ComebackModal> createState() => _ComebackModalState();
}

class _ComebackModalState extends ConsumerState<ComebackModal> {
  bool _isCompleting = false;
  String _selectedPath = 'easy';

  @override
  Widget build(BuildContext context) {
    final gapDays = (widget.comeback['gapDays'] as num?)?.toInt() ?? 3;
    final protectedCount =
        (widget.comeback['protectedStreakCount'] as num?)?.toInt() ?? 0;
    final suggestions = (widget.comeback['suggestions'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .take(3)
        .toList();

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF1D6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.restart_alt_rounded,
                        color: Color(0xFF9A5A00),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Welcome back',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'You were away for $gapDays days. No catching up required. Your streaks were protected while you were gone.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        height: 1.35,
                        color: const Color(0xFF303036),
                      ),
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF7EF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.shield_outlined,
                        size: 20,
                        color: Color(0xFF237A45),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '$protectedCount streak${protectedCount == 1 ? '' : 's'} protected',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1F5C36),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Choose your restart path',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                ),
                const SizedBox(height: 10),
                _PathOption(
                  id: 'easy',
                  title: 'Easy Day',
                  subtitle: 'Start small. One win is enough.',
                  icon: Icons.spa_outlined,
                  isSelected: _selectedPath == 'easy',
                  onTap: () => setState(() => _selectedPath = 'easy'),
                ),
                const SizedBox(height: 8),
                _PathOption(
                  id: 'half',
                  title: 'Half Day',
                  subtitle: 'Pick up the most important habits.',
                  icon: Icons.adjust_rounded,
                  isSelected: _selectedPath == 'half',
                  onTap: () => setState(() => _selectedPath = 'half'),
                ),
                const SizedBox(height: 8),
                _PathOption(
                  id: 'full',
                  title: 'Full Day',
                  subtitle: 'Right back into your routine.',
                  icon: Icons.flash_on_rounded,
                  isSelected: _selectedPath == 'full',
                  onTap: () => setState(() => _selectedPath = 'full'),
                ),
                if (suggestions.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  Text(
                    'Suggestions',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0,
                        ),
                  ),
                  const SizedBox(height: 8),
                  for (final suggestion in suggestions)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _SuggestionRow(suggestion: suggestion),
                    ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isCompleting ? null : _complete,
                    icon: _isCompleting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.play_arrow_rounded),
                    label: const Text('Start again today'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _complete() async {
    setState(() => _isCompleting = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      final gapDays = (widget.comeback['gapDays'] as num?)?.toInt() ?? 3;

      if (uid != null) {
        // 1. Emit the path chosen event
        await ref.read(eventServiceProvider).emit(
          eventName: EventNames.comebackPathChosen,
          payload: {
            'path': _selectedPath,
            'gapDays': gapDays,
          },
        );

        // 2. Set the 48h supportive tone lock
        final now = DateTime.now();
        final toneLockUntil = now.add(const Duration(hours: 48));
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('profile')
            .doc('main')
            .set(
          {
            'toneLockUntil': Timestamp.fromDate(toneLockUntil),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      // 3. Complete the original comeback logic
      await widget.onPrimary();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      debugPrint('[ComebackModal] Error completing comeback: $e');
    } finally {
      if (mounted) setState(() => _isCompleting = false);
    }
  }
}

class _PathOption extends StatelessWidget {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _PathOption({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? const Color(0xFF237A45) : const Color(0xFFE3E4E8),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          color: isSelected ? const Color(0xFFEAF7EF) : Colors.transparent,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? const Color(0xFF237A45) : const Color(0xFF555B64),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: isSelected ? const Color(0xFF1F5C36) : null,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isSelected
                              ? const Color(0xFF237A45).withValues(alpha: 0.8)
                              : const Color(0xFF555B64),
                        ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                size: 20,
                color: Color(0xFF237A45),
              ),
          ],
        ),
      ),
    );
  }
}

class _SuggestionRow extends StatelessWidget {
  final Map<String, dynamic> suggestion;

  const _SuggestionRow({required this.suggestion});

  @override
  Widget build(BuildContext context) {
    final title = (suggestion['title'] ?? '').toString();
    final body = (suggestion['body'] ?? suggestion['reason'] ?? '').toString();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE3E4E8)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                if (body.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    body,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          height: 1.3,
                          color: const Color(0xFF555B64),
                        ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
