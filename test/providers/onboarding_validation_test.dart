import 'package:flutter_test/flutter_test.dart';
import 'package:optivus2/providers/onboarding_provider.dart';
import 'package:optivus2/core/constants/onboarding_constants.dart';

void main() {
  group('Onboarding Validation Tests', () {
    test('validationErrorForPage returns correct messages for pages 2–10', () {
      final emptyState = OnboardingState();

      // Page 2: Categories
      expect(emptyState.validationErrorForPage(2),
          'Choose at least one focus area before continuing.');

      // Page 3: Bad Habits
      expect(emptyState.validationErrorForPage(3),
          'Choose at least one bad habit to work on.');

      // Page 4: Good Habits
      expect(emptyState.validationErrorForPage(4),
          'Choose at least one good habit to build.');

      // Page 5: Goals
      expect(emptyState.validationErrorForPage(5), 'Choose at least one goal.');

      // Page 6: About You
      expect(emptyState.validationErrorForPage(6),
          'Complete the required About You fields and accept the disclaimer.');

      // Page 7: Coach Style
      expect(emptyState.validationErrorForPage(7), 'Choose your coach style.');

      // Page 8: Coach Name
      expect(emptyState.validationErrorForPage(8),
          'Name your coach before continuing.');

      // Page 9: Accountability
      expect(emptyState.validationErrorForPage(9),
          'Choose your accountability level.');

      // Page 10: Fixed Schedule
      expect(emptyState.validationErrorForPage(10),
          'Add at least one fixed schedule block.');

      final stateWithInvalidSchedule = emptyState.copyWith(
        fixedSchedule: [
          {'title': '', 'startTime': '', 'endTime': ''}
        ],
      );
      expect(stateWithInvalidSchedule.validationErrorForPage(10),
          'Add at least one fixed schedule block with a title and valid times.');
    });

    test('New page count is 12 and final page index is 11', () {
      expect(kOnboardingPageCount, 12);
      expect(kOnboardingFinalPage, 11);
      expect(kOnboardingFirstPage, 0);
      expect(kOnboardingPatiencePage, 1);
    });

    test('Empty onboarding cannot complete', () {
      final emptyState = OnboardingState();
      final error =
          emptyState.validationErrorForPage(11); // final page validation
      expect(error, isNotNull);
      // Since it validates 2-10 in order, the first error is page 2
      expect(error, 'Choose at least one focus area before continuing.');
    });
  });
}
