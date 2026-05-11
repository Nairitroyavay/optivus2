import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:optivus2/core/liquid_ui/liquid_ui.dart';

class MvpInfoScreen extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color accentColor;
  final String statusLabel;
  final String body;
  final String? primaryActionLabel;
  final VoidCallback? onPrimaryAction;

  const MvpInfoScreen({
    super.key,
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.statusLabel,
    required this.body,
    this.primaryActionLabel,
    this.onPrimaryAction,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LiquidBg(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    LiquidIconBtn(
                      icon: Icons.arrow_back_ios_new_rounded,
                      size: 44,
                      onTap: () => context.pop(),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: kSub,
                          letterSpacing: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                LiquidCard(
                  frosted: true,
                  radius: 24,
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: accentColor.withValues(alpha: 0.16),
                        ),
                        child: Icon(icon, color: accentColor, size: 26),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        statusLabel,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: kInk,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        body,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: kSub.withValues(alpha: 0.9),
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (primaryActionLabel != null)
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: onPrimaryAction,
                    child: Text(
                      primaryActionLabel!,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
