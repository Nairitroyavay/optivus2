import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus2/core/config/app_config.dart';
import 'package:optivus2/core/providers.dart';
import 'package:optivus2/providers/onboarding_provider.dart';
import 'package:optivus2/repositories/routine_repository.dart';
import 'package:optivus2/views/routine/eating_setup_screen.dart';

class MockRoutineRepository implements RoutineRepository {
  bool sensitiveContextCalled = false;
  String modeCalled = '';
  int callCount = 0;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #previewRoutineImport) {
      callCount++;
      modeCalled = invocation.namedArguments[#mode] as String? ?? '';
      sensitiveContextCalled = invocation.namedArguments[#sensitiveContext] as bool? ?? false;
      return Future.value(<Map<String, dynamic>>[]);
    }
    return super.noSuchMethod(invocation);
  }
}

void main() {
  late MockRoutineRepository mockRepo;

  setUp(() {
    mockRepo = MockRoutineRepository();
  });

  Widget createTestWidget({
    bool routineImportWorkerReady = true,
    bool sensitiveContext = false,
  }) {
    return ProviderScope(
      overrides: [
        appFeatureFlagsProvider.overrideWithValue(
          AppFeatureFlags.defaults().copyWith(
            routineImportWorkerReady: routineImportWorkerReady,
          ),
        ),
        eatingDisorderFlagProvider.overrideWith((ref) => Stream.value(sensitiveContext)),
        routineRepositoryProvider.overrideWithValue(mockRepo),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: EatingSetupScreen(onComplete: () {}),
        ),
      ),
    );
  }

  testWidgets('AI import disabled shows Coming Soon snackbar', (tester) async {
    await tester.pumpWidget(createTestWidget(routineImportWorkerReady: false));
    await tester.pumpAndSettle();

    final fab = find.byType(FloatingActionButton);
    expect(fab, findsOneWidget);

    await tester.tap(fab);
    await tester.pump();

    expect(find.text('AI import is coming soon. Please add meals manually.'), findsOneWidget);
  });

  testWidgets('AI import enabled shows bottom sheet and passes sensitiveContext', (tester) async {
    await tester.pumpWidget(createTestWidget(routineImportWorkerReady: true, sensitiveContext: true));
    await tester.pumpAndSettle();

    final fab = find.byType(FloatingActionButton);
    await tester.tap(fab);
    await tester.pumpAndSettle();

    // Verify bottom sheet is shown
    expect(find.text('Paste Mess Menu Text'), findsOneWidget);
    expect(find.text('Generate Adaptive Meal Plan (Coming Soon)'), findsOneWidget);

    // Tap text import
    await tester.tap(find.text('Paste Mess Menu Text'));
    await tester.pumpAndSettle();

    // Fill dialog and submit
    await tester.enterText(find.byType(TextField), 'Some mess menu');
    await tester.tap(find.text('Import'));
    await tester.pump();

    // Verify repo was called with sensitiveContext = true
    expect(mockRepo.callCount, 1);
    expect(mockRepo.modeCalled, 'eating_mess_text');
    expect(mockRepo.sensitiveContextCalled, isTrue);
  });
}
