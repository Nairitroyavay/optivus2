// lib/Routine Screen/ai_panel.dart
// AI panel stub — UI only, no API calls yet.
import 'package:flutter/material.dart';
import 'liquid_kit.dart';
import 'add_task_sheet.dart';
import 'routine_provider.dart';

class AiPanel extends StatelessWidget {
  final void Function(CustomTask) onAddTask;
  final VoidCallback onClose;
  const AiPanel({super.key, required this.onAddTask, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xF0FFFFFF),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top:   BorderSide(color: Color(0xCCFFFFFF), width: 1.5),
          left:  BorderSide(color: Color(0xCCFFFFFF), width: 1),
          right: BorderSide(color: Color(0xCCFFFFFF), width: 1),
        ),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 16),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const LiquidSheetHandle(),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [kPurple, Color(0xFF78FDFF)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(child: Text('✦',
                  style: TextStyle(fontSize: 18, color: Colors.white,
                      fontWeight: FontWeight.w900))),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('AI Coach',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900,
                        color: kInk)),
                Text('Ready to optimise your day',
                    style: TextStyle(fontSize: 12, color: kSub)),
              ],
            )),
            LiquidIconBtn(icon: Icons.close_rounded, size: 34, onTap: onClose),
          ]),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kPurple.withOpacity(0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kPurple.withOpacity(0.15)),
            ),
            child: Row(children: [
              const Text('⚡', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('AI suggestions coming soon',
                      style: TextStyle(fontSize: 14,
                          fontWeight: FontWeight.w800, color: kInk)),
                  const SizedBox(height: 3),
                  Text('Wire to the Anthropic API to enable smart scheduling.',
                      style: TextStyle(fontSize: 12, color: kSub)),
                ],
              )),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(children: [
            Expanded(child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F0F8),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('Ask AI… e.g. "add yoga at 7am"',
                  style: TextStyle(fontSize: 14, color: kSub.withOpacity(0.5))),
            )),
            const SizedBox(width: 10),
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [kPurple, Color(0xFF78FDFF)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
            ),
          ]),
        ),
      ]),
    );
  }
}

class PremiumPaywallSheet extends StatelessWidget {
  final VoidCallback onUnlock;
  const PremiumPaywallSheet({super.key, required this.onUnlock});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + 16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const LiquidSheetHandle(),
          const SizedBox(height: 20),
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [kPurple, Color(0xFF78FDFF)],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Center(child: Text('✦',
                style: TextStyle(fontSize: 28, color: Colors.white))),
          ),
          const SizedBox(height: 16),
          const Text('Unlock AI Coach',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: kInk)),
          const SizedBox(height: 6),
          Text('Smart task suggestions that optimise\nevery hour of your day.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: kSub, height: 1.55)),
          const SizedBox(height: 24),
          ...['✦ Smart task suggestions from AI',
              '🗓️ Auto-schedule free gaps',
              '💬 Natural language "add yoga at 7am"',
              '📊 Weekly performance insights'].map((f) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(children: [
              Text(f.substring(0, 2), style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 12),
              Text(f.substring(2), style: const TextStyle(
                  fontSize: 14, color: kInk, fontWeight: FontWeight.w500)),
            ]),
          )),
          const SizedBox(height: 20),
          LiquidButton(label: 'Unlock Premium',
              color: kPurple, onTap: onUnlock),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Maybe later',
                style: TextStyle(fontSize: 13, color: kSub)),
          ),
        ]),
      ),
    );
  }
}
