import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus2/models/user_model.dart';
import 'package:optivus2/providers/onboarding_provider.dart';
import 'package:optivus2/views/screens/onboarding_screen.dart';

class OnboardingPage5 extends ConsumerStatefulWidget {
  const OnboardingPage5({super.key});

  @override
  ConsumerState<OnboardingPage5> createState() => _OnboardingPage5State();
}

class _OnboardingPage5State extends ConsumerState<OnboardingPage5> {
  final PageController _controller = PageController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  int _tab = 0;
  String? _validationMessage;

  static const _ageRanges = ['Under 18', '18-24', '25-34', '35-44', '45+'];
  static const _genders = ['Female', 'Male', 'Non-binary', 'Prefer not to say'];
  static const _schoolWorkTypes = [
    'School',
    'College',
    'Full-time work',
    'Part-time work',
    'Self-employed',
    'Not working',
  ];
  static const _exerciseLevels = [
    'Rarely',
    '1-2 days/week',
    '3-4 days/week',
    '5+ days/week',
  ];
  static const _waterIntakes = ['Low', 'Medium', 'High'];
  static const _dietPreferences = [
    'No preference',
    'Vegetarian',
    'Vegan',
    'High protein',
    'Hostel/mess food',
  ];
  static const _stressLevels = ['Low', 'Medium', 'High'];
  static const _sleepQualities = ['Poor', 'Okay', 'Good', 'Great'];
  static const _coachBoundaries = [
    'Gentle only',
    'Direct but kind',
    'Avoid body/food comments',
    'No sensitive topics',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final body = ref.read(onboardingProvider).aboutYou.bodyBasics;
      if (body.timezone == null || body.timezone!.trim().isEmpty) {
        _updateBody(body.copyWith(timezone: DateTime.now().timeZoneName));
      }
      _heightController.text = body.heightCm?.toString() ?? '';
      _weightController.text = body.weightKg?.toStringAsFixed(1) ?? '';
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  void _goToTab(int index) {
    setState(() => _tab = index);
    _controller.animateToPage(
      index,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  void _updateBody(BodyBasics body) {
    ref.read(onboardingProvider.notifier).updateBodyBasics(body);
    setState(() => _validationMessage = body.validate());
  }

  void _updateLifestyle(LifestyleProfile lifestyle) {
    ref.read(onboardingProvider.notifier).updateLifestyle(lifestyle);
  }

  void _updateSensitive(SensitiveContext sensitive) {
    ref.read(onboardingProvider.notifier).updateSensitiveContext(sensitive);
  }

  void _updateHeight(String value) {
    final parsed = int.tryParse(value.trim());
    _updateBody(ref.read(onboardingProvider).aboutYou.bodyBasics.copyWith(
          heightCm: parsed,
          clearHeight: value.trim().isEmpty,
        ));
  }

  void _updateWeight(String value) {
    final parsed = double.tryParse(value.trim());
    _updateBody(ref.read(onboardingProvider).aboutYou.bodyBasics.copyWith(
          weightKg: parsed,
          clearWeight: value.trim().isEmpty,
        ));
  }

  Future<void> _pickTime({
    required String label,
    required bool isWakeTime,
  }) async {
    final body = ref.read(onboardingProvider).aboutYou.bodyBasics;
    final current = _parseTime(isWakeTime ? body.wakeTime : body.sleepTime);
    final picked = await showTimePicker(
      context: context,
      initialTime: current ?? const TimeOfDay(hour: 7, minute: 0),
      helpText: label,
    );
    if (picked == null) return;
    final value = _formatTime(picked);
    _updateBody(
      body.copyWith(
        wakeTime: isWakeTime ? value : null,
        sleepTime: isWakeTime ? null : value,
      ),
    );
  }

  TimeOfDay? _parseTime(String? value) {
    if (value == null) return null;
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top + kIndicatorOverlayH;
    final bottom = MediaQuery.of(context).padding.bottom + kButtonOverlayH;
    final aboutYou = ref.watch(onboardingProvider).aboutYou;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, top + 14, 20, bottom + 12),
      child: Column(
        children: [
          RichText(
            textAlign: TextAlign.center,
            text: const TextSpan(
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F111A),
                height: 1.12,
              ),
              children: [
                TextSpan(text: 'Tell Optivus\n'),
                TextSpan(
                  text: 'about you',
                  style: TextStyle(color: Color(0xFF14B8A6)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _Tabs(selected: _tab, onSelected: _goToTab),
          if (_validationMessage != null) ...[
            const SizedBox(height: 10),
            _InlineError(message: _validationMessage!),
          ],
          const SizedBox(height: 14),
          Expanded(
            child: PageView(
              controller: _controller,
              onPageChanged: (index) => setState(() => _tab = index),
              children: [
                _BodyBasicsView(
                  body: aboutYou.bodyBasics,
                  heightController: _heightController,
                  weightController: _weightController,
                  onBodyChanged: _updateBody,
                  onHeightChanged: _updateHeight,
                  onWeightChanged: _updateWeight,
                  onPickWakeTime: () =>
                      _pickTime(label: 'Wake time', isWakeTime: true),
                  onPickSleepTime: () =>
                      _pickTime(label: 'Sleep time', isWakeTime: false),
                ),
                _LifestyleView(
                  lifestyle: aboutYou.lifestyle,
                  onChanged: _updateLifestyle,
                ),
                _SensitiveContextView(
                  sensitive: aboutYou.sensitiveContext,
                  onChanged: _updateSensitive,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onSelected;

  const _Tabs({
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    const labels = ['Body', 'Lifestyle', 'Sensitive'];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
      ),
      child: Row(
        children: List.generate(labels.length, (index) {
          final active = selected == index;
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelected(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: active ? const Color(0xFF0F111A) : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  labels[index],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: active ? Colors.white : const Color(0xFF374151),
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _BodyBasicsView extends StatelessWidget {
  final BodyBasics body;
  final TextEditingController heightController;
  final TextEditingController weightController;
  final ValueChanged<BodyBasics> onBodyChanged;
  final ValueChanged<String> onHeightChanged;
  final ValueChanged<String> onWeightChanged;
  final VoidCallback onPickWakeTime;
  final VoidCallback onPickSleepTime;

  const _BodyBasicsView({
    required this.body,
    required this.heightController,
    required this.weightController,
    required this.onBodyChanged,
    required this.onHeightChanged,
    required this.onWeightChanged,
    required this.onPickWakeTime,
    required this.onPickSleepTime,
  });

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _SectionTitle('Body basics'),
          _ChoiceGroup(
            label: 'Age range',
            value: body.ageRange,
            options: _OnboardingPage5State._ageRanges,
            onSelected: (value) => onBodyChanged(body.copyWith(
              ageRange: value,
            )),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _NumberField(
                  label: 'Height',
                  suffix: 'cm',
                  controller: heightController,
                  onChanged: onHeightChanged,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _NumberField(
                  label: 'Weight',
                  suffix: 'kg',
                  controller: weightController,
                  decimal: true,
                  onChanged: onWeightChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _ChoiceGroup(
            label: 'Gender',
            value: body.gender,
            options: _OnboardingPage5State._genders,
            onSelected: (value) => onBodyChanged(
              body.copyWith(
                gender: value == 'Prefer not to say' ? null : value,
                clearGender: value == 'Prefer not to say',
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _TimeButton(
                  label: 'Wake',
                  value: body.wakeTime,
                  onTap: onPickWakeTime,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _TimeButton(
                  label: 'Sleep',
                  value: body.sleepTime,
                  onTap: onPickSleepTime,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _ReadOnlyField(
            label: 'Timezone',
            value: body.timezone ?? DateTime.now().timeZoneName,
          ),
        ],
      ),
    );
  }
}

class _LifestyleView extends StatelessWidget {
  final LifestyleProfile lifestyle;
  final ValueChanged<LifestyleProfile> onChanged;

  const _LifestyleView({
    required this.lifestyle,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _SectionTitle('Lifestyle'),
          _ChoiceGroup(
            label: 'School/work type',
            value: lifestyle.schoolWorkType,
            options: _OnboardingPage5State._schoolWorkTypes,
            onSelected: (value) =>
                onChanged(lifestyle.copyWith(schoolWorkType: value)),
          ),
          _ChoiceGroup(
            label: 'Exercise level',
            value: lifestyle.exerciseLevel,
            options: _OnboardingPage5State._exerciseLevels,
            onSelected: (value) =>
                onChanged(lifestyle.copyWith(exerciseLevel: value)),
          ),
          _ChoiceGroup(
            label: 'Water intake',
            value: lifestyle.waterIntake,
            options: _OnboardingPage5State._waterIntakes,
            onSelected: (value) =>
                onChanged(lifestyle.copyWith(waterIntake: value)),
          ),
          _ChoiceGroup(
            label: 'Diet preference',
            value: lifestyle.dietPreference,
            options: _OnboardingPage5State._dietPreferences,
            onSelected: (value) =>
                onChanged(lifestyle.copyWith(dietPreference: value)),
          ),
          _ChoiceGroup(
            label: 'Stress level',
            value: lifestyle.stressLevel,
            options: _OnboardingPage5State._stressLevels,
            onSelected: (value) =>
                onChanged(lifestyle.copyWith(stressLevel: value)),
          ),
          _ChoiceGroup(
            label: 'Sleep quality',
            value: lifestyle.sleepQuality,
            options: _OnboardingPage5State._sleepQualities,
            onSelected: (value) =>
                onChanged(lifestyle.copyWith(sleepQuality: value)),
          ),
        ],
      ),
    );
  }
}

class _SensitiveContextView extends StatelessWidget {
  final SensitiveContext sensitive;
  final ValueChanged<SensitiveContext> onChanged;

  const _SensitiveContextView({
    required this.sensitive,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _SectionTitle('Sensitive context'),
          _TriStateGroup(
            label: 'Eating disorder history',
            value: sensitive.eatingDisorderFlag,
            onChanged: (value) => onChanged(
              sensitive.copyWith(
                eatingDisorderFlag: value,
                clearEatingDisorderFlag: value == null,
              ),
            ),
          ),
          _TriStateGroup(
            label: 'Crisis or self-harm risk',
            value: sensitive.crisisSelfHarmFlag,
            onChanged: (value) => onChanged(
              sensitive.copyWith(
                crisisSelfHarmFlag: value,
                clearCrisisSelfHarmFlag: value == null,
              ),
            ),
          ),
          const SizedBox(height: 10),
          _DisclaimerToggle(
            value: sensitive.medicalDisclaimerAcknowledged,
            onChanged: (value) => onChanged(
              sensitive.copyWith(medicalDisclaimerAcknowledged: value),
            ),
          ),
          const SizedBox(height: 14),
          _ChoiceGroup(
            label: 'Coach boundary',
            value: sensitive.coachBoundaryPreference,
            options: _OnboardingPage5State._coachBoundaries,
            onSelected: (value) => onChanged(
              sensitive.copyWith(coachBoundaryPreference: value),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => onChanged(
              sensitive.copyWith(clearCoachBoundaryPreference: true),
            ),
            child: const Text('Skip coach boundary preference'),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final Widget child;

  const _Panel({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.82)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF0F111A),
          fontSize: 22,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ChoiceGroup extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> options;
  final ValueChanged<String> onSelected;

  const _ChoiceGroup({
    required this.label,
    required this.value,
    required this.options,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FieldLabel(label),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.map((option) {
              final selected = value == option;
              return _ChipButton(
                label: option,
                selected: selected,
                onTap: () {
                  HapticFeedback.selectionClick();
                  onSelected(option);
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _TriStateGroup extends StatelessWidget {
  final String label;
  final bool? value;
  final ValueChanged<bool?> onChanged;

  const _TriStateGroup({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FieldLabel(label),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _ChipButton(
                label: 'Yes',
                selected: value == true,
                onTap: () => onChanged(true),
              ),
              _ChipButton(
                label: 'No',
                selected: value == false,
                onTap: () => onChanged(false),
              ),
              _ChipButton(
                label: 'Skip',
                selected: value == null,
                onTap: () => onChanged(null),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChipButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ChipButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF14B8A6) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? const Color(0xFF0F766E) : const Color(0xFFE5E7EB),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF374151),
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  final String label;
  final String suffix;
  final TextEditingController controller;
  final bool decimal;
  final ValueChanged<String> onChanged;

  const _NumberField({
    required this.label,
    required this.suffix,
    required this.controller,
    required this.onChanged,
    this.decimal = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: TextInputType.numberWithOptions(decimal: decimal),
          inputFormatters: [
            FilteringTextInputFormatter.allow(
              decimal ? RegExp(r'[0-9.]') : RegExp(r'[0-9]'),
            ),
          ],
          onChanged: onChanged,
          decoration: InputDecoration(
            suffixText: suffix,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}

class _TimeButton extends StatelessWidget {
  final String label;
  final String? value;
  final VoidCallback onTap;

  const _TimeButton({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: 54,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              value ?? 'Set time',
              style: const TextStyle(
                color: Color(0xFF0F111A),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  final String label;
  final String value;

  const _ReadOnlyField({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            value,
            style: const TextStyle(
              color: Color(0xFF374151),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _DisclaimerToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _DisclaimerToggle({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: value ? const Color(0xFF14B8A6) : const Color(0xFFE5E7EB),
          ),
        ),
        child: Row(
          children: [
            Icon(
              value ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: value ? const Color(0xFF14B8A6) : const Color(0xFF6B7280),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'I understand Optivus is not medical advice.',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF374151),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;

  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF6B7280),
        fontSize: 12,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  final String message;

  const _InlineError({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: Color(0xFFB91C1C),
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
