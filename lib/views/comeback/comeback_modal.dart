import 'package:flutter/material.dart';

class ComebackModal extends StatefulWidget {
  final Map<String, dynamic> comeback;
  final Future<void> Function() onPrimary;

  const ComebackModal({
    super.key,
    required this.comeback,
    required this.onPrimary,
  });

  @override
  State<ComebackModal> createState() => _ComebackModalState();
}

class _ComebackModalState extends State<ComebackModal> {
  bool _isCompleting = false;

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
              if (suggestions.isNotEmpty) ...[
                const SizedBox(height: 18),
                Text(
                  'Easy restart',
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
              const SizedBox(height: 12),
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
    );
  }

  Future<void> _complete() async {
    setState(() => _isCompleting = true);
    try {
      await widget.onPrimary();
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _isCompleting = false);
    }
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
