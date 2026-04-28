import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:optivus2/models/habit_model.dart';
import 'package:optivus2/core/liquid_ui/liquid_ui.dart';
import 'package:optivus2/core/providers.dart';
import 'package:optivus2/core/constants/event_names.dart';

final habitsProvider = StreamProvider<List<HabitModel>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value([]);
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('habits')
      .snapshots()
      .map((snap) => snap.docs.map((doc) => HabitModel.fromMap(doc.data(), doc.id)).toList());
});

class LogHabitSheet extends ConsumerWidget {
  const LogHabitSheet({super.key});

  Future<void> _logHabit(BuildContext context, WidgetRef ref, HabitModel habit) async {
    final eventName = habit.kind == HabitKind.good
        ? EventNames.goodHabitLogged
        : EventNames.badHabitSlipLogged;

    await ref.read(eventServiceProvider).emit(
      eventName: eventName,
      payload: {
        'habitId': habit.id,
        'amount': 1,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
    
    if (context.mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habitsAsync = ref.watch(habitsProvider);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 5,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const Text(
              'Log Habit',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F111A), // _kInk
                letterSpacing: -0.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            habitsAsync.when(
              data: (habits) {
                if (habits.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Text(
                      'No habits found. Add some to get started!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  );
                }
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  itemCount: habits.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final habit = habits[index];
                    return LiquidCard.solid(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      radius: 20,
                      tint: Colors.grey[50], // subtle tint
                      child: Row(
                        children: [
                          if (habit.emoji != null && habit.emoji!.isNotEmpty)
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  )
                                ],
                              ),
                              child: Center(
                                child: Text(habit.emoji!, style: const TextStyle(fontSize: 22)),
                              ),
                            )
                          else
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  )
                                ],
                              ),
                              child: const Center(
                                child: Icon(Icons.star_rounded, color: Colors.amber, size: 24),
                              ),
                            ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  habit.name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F111A), // _kInk
                                  ),
                                ),
                                if (habit.trackerType.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    habit.trackerType,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF6B7280), // _kSubtext
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          LiquidIconBtn(
                            icon: Icons.add_rounded,
                            size: 40,
                            onTap: () => _logHabit(context, ref, habit),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.all(32.0),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, st) => Padding(
                padding: const EdgeInsets.all(32.0),
                child: Text('Error: $e', textAlign: TextAlign.center),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
