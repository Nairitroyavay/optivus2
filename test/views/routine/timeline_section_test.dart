import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus2/core/liquid_ui/liquid_ui.dart';
import 'package:optivus2/models/task_model.dart';
import 'package:optivus2/providers/routine_provider.dart';
import 'package:optivus2/views/routine/timeline_section.dart';

void main() {
  group('timeline time formatting', () {
    test('formatTimelineTime returns 09:00 for 9:00', () {
      expect(
        formatTimelineTime(const TimeOfDay(hour: 9, minute: 0)),
        '09:00',
      );
    });

    test('formatTimelineTime returns 17:05 for 17:05', () {
      expect(
        formatTimelineTime(const TimeOfDay(hour: 17, minute: 5)),
        '17:05',
      );
    });
  });

  group('current time indicator', () {
    testWidgets('is shown when selected date is today', (tester) async {
      final now = DateTime.now();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 360,
              height: 120,
              child: TimelineCurrentTimeIndicator(
                selectedDate: DateTime(now.year, now.month, now.day),
                startMinute: 0,
                durationMinutes: 1440,
                color: kRose,
              ),
            ),
          ),
        ),
      );

      expect(find.byKey(kTimelineCurrentTimeIndicatorKey), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('is hidden when selected date is not today', (tester) async {
      final tomorrow = DateTime.now().add(const Duration(days: 1));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 360,
              height: 120,
              child: TimelineCurrentTimeIndicator(
                selectedDate: DateTime(
                  tomorrow.year,
                  tomorrow.month,
                  tomorrow.day,
                ),
                startMinute: 0,
                durationMinutes: 1440,
                color: kRose,
              ),
            ),
          ),
        ),
      );

      expect(find.byKey(kTimelineCurrentTimeIndicatorKey), findsNothing);
    });
  });

  group('timeline positioning', () {
    const block = DisplayBlock(
      time: '09:00',
      title: 'Sleep',
      subtitle: '09:00 - 10:00',
      accentColor: kPurple,
      emoji: 'Z',
      type: RoutineFilter.fixedSchedule,
      durationMinutes: 60,
    );

    test('one hour duration height equals one hour slot', () {
      expect(timelineHeightForDuration(60), kTimelineHourHeight);
    });

    test('card top and bottom align with rail minute positions', () {
      final start = parseTimelineMinute(block.time);
      final end = parseTimelineMinute('10:00');
      final top = timelineYForMinute(start);
      final height = timelineHeightForDuration(block.durationMinutes);

      expect(top, timelineYForMinute(parseTimelineMinute('09:00')));
      expect(top + height, timelineYForMinute(end));
    });

    testWidgets('09:00-10:00 card occupies the exact visual interval',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TimelineDaySchedule(
                selectedDate: DateTime(2024, 1, 1),
                blocks: [block],
              ),
            ),
          ),
        ),
      );

      final scheduleTop =
          tester.getTopLeft(find.byKey(kTimelineDayScheduleKey)).dy;
      final cardRect = tester.getRect(find.byKey(timelineCardKey(block)));

      expect(
        cardRect.top - scheduleTop,
        closeTo(timelineYForMinute(parseTimelineMinute('09:00')), 0.001),
      );
      expect(cardRect.height, closeTo(kTimelineHourHeight, 0.001));
      expect(
        cardRect.bottom - scheduleTop,
        closeTo(timelineYForMinute(parseTimelineMinute('10:00')), 0.001),
      );
    });

    testWidgets('HH:mm labels render on the day schedule', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 360,
              height: 1200,
              child: TimelineDaySchedule(
                selectedDate: DateTime(2024, 1, 1),
                blocks: [block],
              ),
            ),
          ),
        ),
      );

      expect(find.text('09:00'), findsOneWidget);
    });

    testWidgets('scheduled task card still exposes Start and Skip actions',
        (tester) async {
      const actionBlock = DisplayBlock(
        time: '00:00',
        title: 'Action task',
        subtitle: '00:00 - 01:00',
        accentColor: kPurple,
        emoji: 'A',
        type: RoutineFilter.fixedSchedule,
        taskId: 'task-1',
        taskState: TaskState.scheduled,
        durationMinutes: 60,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 420,
              height: 240,
              child: TimelineDaySchedule(
                selectedDate: DateTime(2024, 1, 1),
                blocks: const [actionBlock],
                onStart: (_) {},
                onSkip: (_) {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('Start'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
    });
  });

  testWidgets('time rail reserves enough width for HH:mm labels',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 120,
            child: TimelineRow(
              block: const DisplayBlock(
                time: '09:00',
                title: '',
                subtitle: '',
                accentColor: Colors.transparent,
                emoji: '',
                type: RoutineFilter.all,
                isEmptyPlaceholder: true,
              ),
              showHourLabel: true,
              isLast: false,
            ),
          ),
        ),
      ),
    );

    final rail = tester.widget<SizedBox>(find.byKey(kTimelineTimeRailKey));

    expect(rail.width, greaterThanOrEqualTo(56));
    expect(rail.width, lessThanOrEqualTo(64));
    expect(find.text('09:00'), findsOneWidget);
  });
}
