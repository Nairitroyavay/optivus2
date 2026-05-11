import 'dart:async' show unawaited;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus2/core/liquid_ui/liquid_ui.dart';
import 'package:optivus2/core/providers.dart';
import 'package:optivus2/providers/routine_provider.dart';
import 'package:optivus2/views/routine/widgets/fixed_schedule_editor.dart';

class FixedScheduleSetupScreen extends ConsumerStatefulWidget {
  final VoidCallback onComplete;
  const FixedScheduleSetupScreen({super.key, required this.onComplete});

  @override
  ConsumerState<FixedScheduleSetupScreen> createState() =>
      _FixedScheduleSetupScreenState();
}

class _FixedScheduleSetupScreenState
    extends ConsumerState<FixedScheduleSetupScreen> {
  List<FixedScheduleTemplate> _currentTemplates = const [];
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _currentTemplates = ref.read(routineProvider).fixedScheduleTemplates;
        _isLoaded = true;
      });
    });
  }

  void _save() {
    final normalizedTemplates =
        canonicalizeFixedScheduleTemplates(_currentTemplates);

    // Update in-memory state and queue a debounced full save.
    ref
        .read(routineProvider.notifier)
        .setFixedScheduleTemplates(normalizedTemplates);

    // Also do an immediate targeted write to
    // /users/{uid}/routine/current.templates.fixed_schedule.
    unawaited(
      ref
          .read(routineRepositoryProvider)
          .saveFixedScheduleTemplates(normalizedTemplates),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LiquidBg(
        child: SafeArea(
          child: Column(
            children: [
              // App bar
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    LiquidIconBtn(
                      icon: Icons.arrow_back_ios_new_rounded,
                      size: 44,
                      onTap: () => Navigator.pop(context),
                    ),
                    const Text(
                      'FIXED SCHEDULE',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: kSub,
                        letterSpacing: 1.5,
                      ),
                    ),
                    LiquidIconBtn(
                      icon: Icons.check_rounded,
                      size: 44,
                      onTap: () {
                        _save();
                        widget.onComplete();
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              ),

              // Shared editor
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, bottomPadding + 16),
                  child: FixedScheduleEditor(
                    // Re-init once the routine state has been loaded.
                    key: ValueKey(_isLoaded),
                    initialTemplates: _currentTemplates,
                    onChanged: (templates) {
                      _currentTemplates = templates;
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
