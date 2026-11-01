import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_found_mobile/app.dart';
import 'package:lost_found_mobile/data/logic.dart';
import 'package:lost_found_mobile/data/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('sign in opens the campus feed', (tester) async {
    SharedPreferences.setMockInitialValues({'onboarding': true});
    final store = CampusStore();
    await store.init();
    await tester.pumpWidget(LostFoundApp(store: store));
    // The splash holds for 700ms without scheduling frames, so pumpAndSettle
    // returns before the login route opens.
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();

    expect(find.text('Sign in'), findsWidgets);
    await tester.enterText(
      find.byKey(const Key('email-field')),
      'amara@ravensbourne.example',
    );
    await tester.enterText(
      find.byKey(const Key('password-field')),
      demoPassword,
    );
    await tester.tap(find.byKey(const Key('sign-in-button')));
    await tester.pumpAndSettle();

    expect(find.text('Campus feed'), findsOneWidget);
    expect(find.text('Blue bottle, looking for its person'), findsOneWidget);
  });
}
