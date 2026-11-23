import 'package:coastguard360_mobile/app.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';

import 'helpers/fakes.dart';

void main() {
  testWidgets('Home screen shows app name and tagline', (tester) async {
    // Signed-in placeholder state: a stored token is present at startup.
    final session = makeSession(
      MockClient((_) async => loginOk()),
      FakeTokenStorage(token: 'existing-token'),
    );
    await tester.pumpWidget(CoastGuardApp(sessionController: session));
    await tester.pumpAndSettle();

    expect(find.text('Artonad'), findsOneWidget);
    expect(find.text('Coastal Emergency Response'), findsOneWidget);
    // The Task 01 "being initialized" placeholder is gone.
    expect(find.textContaining('being initialized'), findsNothing);
  });
}
