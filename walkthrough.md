# Walkthrough: Fixing Onboarding Validation Logic

I have successfully fixed the onboarding validation and completion flow bugs, preventing users from skipping required pages and ensuring that empty data does not trigger automatic starter tasks. 

## Changes Made

1. **New Patience Test Screen**
   - Created `OnboardingPatienceTestPage` at `lib/views/onboarding/onboarding_patience_test_page.dart`.
   - Updated `OnboardingScreen` to insert this test page at index 1 of the flow, bringing the total page count to 12.

2. **Strict Per-Page Validation**
   - Added `validationErrorForPage(int pageIndex)` to `OnboardingState`.
   - Updated `OnboardingScreen._onNext` to block forward navigation and display validation errors via SnackBar if a page's requirements are unmet.
   - Enforced validation guards inside `completeOnboarding` to prevent backend state from advancing if the user data is incomplete.

3. **Disabled Skip Navigation**
   - Disabled forward swiping by switching to `NeverScrollableScrollPhysics` in the `PageView`.
   - Disabled dragging on the top `_LiquidGlassIndicator` pill, and configured the tap logic to strictly allow backward navigation (`i <= _currentPage`), enforcing the validation rules on forward progress.

4. **Save Button State Fix**
   - Restructured the `_OnboardingSaveButton` widget to use `didUpdateWidget` and listen to `pageIndex` updates instead of passing a `GlobalKey` incorrectly. This ensures the Save button resets its loading/success states correctly when moving between pages.

5. **Removed Hardcoded Starter Tasks**
   - Updated `UserRepository._materializeOnboardingSelections` to completely remove hardcoded default start tasks.
   - Added a `StateError` guard to throw and prevent onboarding completion if the data object payload is somehow empty or completely invalid.

## Verification

- **Testing**: Updated the tests in `test/providers/onboarding_completion_test.dart` to cover the new constraints and constants. We confirmed that the tests pass and no default tasks are generated when inputs are completely blank.
- **Spark Architecture Guardrails**: Successfully executed `scripts/spark_guardrail_scan.py` to confirm no new forbidden services were accidentally utilized.
- **Analyzer**: Eliminated unused onboarding variables from the screen view file.

> [!TIP]
> Manual verification through the 'Fresh Install' app flow is still required as per the standard procedure for onboarding to ensure absolute UI fidelity.

Let me know if there's anything else you'd like to adjust!
