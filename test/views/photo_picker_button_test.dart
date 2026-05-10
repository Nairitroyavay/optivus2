import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus2/core/config/app_config.dart';
import 'package:optivus2/core/providers.dart';
import 'package:optivus2/views/routine/widgets/photo_picker_button.dart';

void main() {
  testWidgets('disabled upload UI shows Coming Soon fallback', (tester) async {
    var changed = false;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appFeatureFlagsProvider.overrideWithValue(AppFeatureFlags.defaults()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: PhotoPickerButton(
              routineType: 'profile',
              onChanged: (_) => changed = true,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(OutlinedButton));
    await tester.pump();

    expect(find.text('Photo uploads are coming soon.'), findsOneWidget);
    expect(changed, isFalse);
  });
}
