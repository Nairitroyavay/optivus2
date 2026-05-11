import 'package:flutter/material.dart';

import 'package:optivus2/core/liquid_ui/liquid_ui.dart';
import 'package:optivus2/models/map_style_model.dart';

class MapStyleSelectorSheet extends StatelessWidget {
  final MapboxStyle selectedStyle;

  const MapStyleSelectorSheet({
    super.key,
    required this.selectedStyle,
  });

  static Future<MapboxStyle?> show(
    BuildContext context, {
    required MapboxStyle selectedStyle,
  }) {
    return showModalBottomSheet<MapboxStyle>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => MapStyleSelectorSheet(selectedStyle: selectedStyle),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: LiquidCard(
        frosted: true,
        padding: const EdgeInsets.all(18),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Map style',
                style: TextStyle(
                  color: kInk,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              for (final style in MapboxStyles.values) ...[
                _MapStyleOption(
                  style: style,
                  selected: style.id == selectedStyle.id,
                  onTap: () => Navigator.of(context).pop(style),
                ),
                if (style != MapboxStyles.values.last)
                  const SizedBox(height: 10),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MapStyleOption extends StatelessWidget {
  final MapboxStyle style;
  final bool selected;
  final VoidCallback onTap;

  const _MapStyleOption({
    required this.style,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? style.accentColor.withValues(alpha: 0.20)
          : kWhite.withValues(alpha: 0.62),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: style.accentColor.withValues(alpha: 0.22),
                  shape: BoxShape.circle,
                ),
                child: Icon(style.icon, color: kInk, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      style.displayName,
                      style: const TextStyle(
                        color: kInk,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      style.description,
                      style: TextStyle(
                        color: kSub.withValues(alpha: 0.76),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected ? style.accentColor : kSub,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
