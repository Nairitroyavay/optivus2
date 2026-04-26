import 'package:flutter/material.dart';
import 'package:optivus2/core/liquid_ui/liquid_ui.dart';
import 'package:optivus2/providers/routine_provider.dart';
// ─────────────────────────────────────────────────────────────────────────────
// WEEK VIEW — 7 horizontal columns representing Mon-Sun
// ─────────────────────────────────────────────────────────────────────────────

class TimelineWeekView extends StatelessWidget {
  final RoutineState routineState;
  final RoutineFilter filter;
  final DateTime activeDate;

  const TimelineWeekView({
    super.key,
    required this.routineState,
    required this.filter,
    required this.activeDate,
  });

  @override
  Widget build(BuildContext context) {
    // Determine the start of the week (Monday)
    final int daysToSubtract = activeDate.weekday - 1;
    final DateTime startOfWeek = activeDate.subtract(Duration(days: daysToSubtract));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(7, (index) {
                final day = startOfWeek.add(Duration(days: index));
                final isToday = day.year == DateTime.now().year &&
                                day.month == DateTime.now().month &&
                                day.day == DateTime.now().day;
                
                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: isToday ? kPurple.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isToday ? kPurple.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                    child: Column(
                      children: [
                        const SizedBox(height: 12),
                        Text(
                          ['M', 'T', 'W', 'T', 'F', 'S', 'S'][index],
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: isToday ? kPurple : kSub.withValues(alpha: 0.8),
                          ),
                        ),
                        Text(
                          '${day.day}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isToday ? kInk : kSub,
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Mock blocks for demonstration of schedule density
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _mockPill(kMint, 0.4),
                              _mockPill(kRose, 0.6),
                              if (index % 2 == 0) _mockPill(kBlue, 0.3),
                              if (index == 3) _mockPill(kPurple, 0.5),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 40), // Safe area breathing room
        ],
      ),
    );
  }

  Widget _mockPill(Color c, double opacity) {
    return Container(
      width: 24,
      height: 60,
      decoration: BoxDecoration(
        color: c.withValues(alpha: opacity),
        borderRadius: BorderRadius.circular(12),
      ),
      margin: const EdgeInsets.symmetric(vertical: 4),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MONTH VIEW — Calendar Grid
// ─────────────────────────────────────────────────────────────────────────────

class TimelineMonthView extends StatelessWidget {
  final RoutineState routineState;
  final RoutineFilter filter;
  final DateTime activeDate;

  const TimelineMonthView({
    super.key,
    required this.routineState,
    required this.filter,
    required this.activeDate,
  });

  @override
  Widget build(BuildContext context) {
    final int daysInMonth = DateUtils.getDaysInMonth(activeDate.year, activeDate.month);
    final DateTime firstDay = DateTime(activeDate.year, activeDate.month, 1);
    final int offset = firstDay.weekday - 1; // 0 for Monday

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        children: [
          // Days of week header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'].map((d) => 
              SizedBox(
                width: 40,
                child: Text(d, textAlign: TextAlign.center, style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w800, color: kSub.withValues(alpha: 0.7)
                )),
              )
            ).toList(),
          ),
          const SizedBox(height: 16),
          // Grid
          Expanded(
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 12,
                crossAxisSpacing: 8,
                childAspectRatio: 0.85,
              ),
              itemCount: 42, // 6 weeks * 7 days
              itemBuilder: (context, index) {
                if (index < offset || index >= offset + daysInMonth) {
                  return const SizedBox();
                }
                
                final int day = index - offset + 1;
                final bool isToday = activeDate.year == DateTime.now().year &&
                                     activeDate.month == DateTime.now().month &&
                                     day == DateTime.now().day;

                return Container(
                  decoration: BoxDecoration(
                    color: isToday ? kRose.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isToday ? kRose.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$day',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: isToday ? FontWeight.w900 : FontWeight.w600,
                          color: isToday ? kRose : kInk,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Tiny dots representing tasks
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _dot(kMint),
                          if (day % 3 == 0) _dot(kBlue),
                          if (day % 5 == 0) _dot(kPurple),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _dot(Color c) {
    return Container(
      width: 4.5,
      height: 4.5,
      margin: const EdgeInsets.symmetric(horizontal: 1.5),
      decoration: BoxDecoration(color: c, shape: BoxShape.circle),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// YEAR VIEW — 12 Month Heatmap
// ─────────────────────────────────────────────────────────────────────────────

class TimelineYearView extends StatelessWidget {
  final RoutineState routineState;
  final RoutineFilter filter;
  final DateTime activeDate;

  const TimelineYearView({
    super.key,
    required this.routineState,
    required this.filter,
    required this.activeDate,
  });

  @override
  Widget build(BuildContext context) {
    const months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 0.8,
        ),
        itemCount: 12,
        itemBuilder: (context, index) {
          final isCurrentMonth = activeDate.year == DateTime.now().year && index + 1 == DateTime.now().month;

          return Container(
            decoration: BoxDecoration(
              color: isCurrentMonth ? kBlue.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isCurrentMonth ? kBlue.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.8),
              ),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  months[index],
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: isCurrentMonth ? kBlue : kSub,
                  ),
                ),
                const Spacer(),
                // Mock mini-heatmap representing schedule load
                Wrap(
                  spacing: 2,
                  runSpacing: 2,
                  children: List.generate(20, (i) {
                    final alpha = 0.1 + (i % 3) * 0.2;
                    return Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: (isCurrentMonth ? kBlue : kPurple).withValues(alpha: alpha),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    );
                  }),
                )
              ],
            ),
          );
        },
      ),
    );
  }
}
