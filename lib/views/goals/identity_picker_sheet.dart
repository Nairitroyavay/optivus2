import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:optivus2/core/liquid_ui/liquid_ui.dart';

import 'identity_editor_screen.dart';

/// A bottom sheet for selecting a starting identity or starting a custom one.
class IdentityPickerSheet extends StatelessWidget {
  const IdentityPickerSheet({super.key});

  static const _defaults = [
    {'title': 'Athlete', 'icon': Icons.directions_run_rounded, 'color': '#22C55E'},
    {'title': 'Reader', 'icon': Icons.menu_book_rounded, 'color': '#3B82F6'},
    {'title': 'Writer', 'icon': Icons.edit_rounded, 'color': '#A855F7'},
    {'title': 'Early Riser', 'icon': Icons.wb_sunny_rounded, 'color': '#EAB308'},
    {'title': 'Healthy Eater', 'icon': Icons.restaurant_rounded, 'color': '#14B8A6'},
    {'title': 'Mindful Soul', 'icon': Icons.self_improvement_rounded, 'color': '#06B6D4'},
    {'title': 'Lifelong Learner', 'icon': Icons.school_rounded, 'color': '#F97316'},
    {'title': 'Planner', 'icon': Icons.calendar_month_rounded, 'color': '#EC4899'},
  ];

  static void show(BuildContext context) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const IdentityPickerSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kBg,
        borderRadius: BorderRadius.circular(24),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: kSub.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                'Choose an Identity',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: kInk,
                ),
              ),
              const SizedBox(height: 20),
              
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _defaults.length + 1,
                  itemBuilder: (context, index) {
                    if (index == _defaults.length) {
                      return _IdentityOptionTile(
                        title: 'Custom',
                        iconData: Icons.add_rounded,
                        colorHex: '#64748B',
                        onTap: () {
                           HapticFeedback.lightImpact();
                           Navigator.pop(context);
                           Navigator.push(
                             context,
                             MaterialPageRoute(
                               builder: (_) => const IdentityEditorScreen(),
                             ),
                           );
                        },
                      );
                    }
                    
                    final item = _defaults[index];
                    return _IdentityOptionTile(
                      title: item['title'] as String,
                      iconData: item['icon'] as IconData,
                      colorHex: item['color'] as String,
                      onTap: () {
                         HapticFeedback.lightImpact();
                         Navigator.pop(context);
                         Navigator.push(
                           context,
                           MaterialPageRoute(
                             builder: (_) => IdentityEditorScreen(
                               initialTitle: item['title'] as String,
                               initialColorHex: item['color'] as String,
                             ),
                           ),
                         );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IdentityOptionTile extends StatelessWidget {
  final String title;
  final IconData iconData;
  final String colorHex;
  final VoidCallback onTap;

  const _IdentityOptionTile({
    required this.title,
    required this.iconData,
    required this.colorHex,
    required this.onTap,
  });

  Color _parseColor(String colorHex) {
    if (colorHex.length == 7) {
      try {
        return Color(int.parse(colorHex.substring(1, 7), radix: 16) + 0xFF000000);
      } catch (_) {}
    }
    return kMint;
  }

  @override
  Widget build(BuildContext context) {
    final color = _parseColor(colorHex);
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(iconData, size: 20, color: color),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
