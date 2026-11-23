import 'package:coastguard360_mobile/widgets/sos_form_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pumpForm(
  WidgetTester tester, {
  required void Function(SosFormData) onSubmit,
  bool isSubmitting = false,
  String? errorMessage,
}) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: SosFormWidget(
          onSubmit: onSubmit,
          isSubmitting: isSubmitting,
          errorMessage: errorMessage,
        ),
      ),
    ),
  ));
}

void main() {
  testWidgets('submits FIRE with defaults and blank note', (tester) async {
    SosFormData? data;
    await pumpForm(tester, onSubmit: (d) => data = d);

    await tester.tap(find.text('Fire'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('sos_submit_button')));
    await tester.pump();

    expect(data!.type, 'FIRE');
    expect(data!.peopleCount, 1);
    expect(data!.note, '');
  });

  testWidgets('submits DROWNING with count and trimmed note', (tester) async {
    SosFormData? data;
    await pumpForm(tester, onSubmit: (d) => data = d);

    await tester.tap(find.text('Drowning'));
    await tester.tap(find.byKey(const Key('people_increment')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('note_field')), '  rocks  ');
    await tester.tap(find.byKey(const Key('sos_submit_button')));
    await tester.pump();

    expect(data!.type, 'DROWNING');
    expect(data!.peopleCount, 2);
    expect(data!.note, 'rocks');
  });

  testWidgets('requires an incident type', (tester) async {
    var called = false;
    await pumpForm(tester, onSubmit: (_) => called = true);

    await tester.tap(find.byKey(const Key('sos_submit_button')));
    await tester.pump();

    expect(find.text('Select the type of emergency'), findsOneWidget);
    expect(called, isFalse);
  });

  testWidgets('people count stays within 1..100', (tester) async {
    await pumpForm(tester, onSubmit: (_) {});

    IconButton button(String key) =>
        tester.widget<IconButton>(find.byKey(Key(key)));
    String value() =>
        tester.widget<Text>(find.byKey(const Key('people_count_value'))).data!;

    expect(value(), '1');
    expect(button('people_decrement').onPressed, isNull);

    for (var i = 0; i < 99; i++) {
      await tester.tap(find.byKey(const Key('people_increment')));
      await tester.pump();
    }
    expect(value(), '100');
    expect(button('people_increment').onPressed, isNull);
  });

  testWidgets('submitting state disables the button; error is visible',
      (tester) async {
    var called = false;
    await pumpForm(
      tester,
      onSubmit: (_) => called = true,
      isSubmitting: true,
      errorMessage: 'Something failed',
    );

    final button = tester
        .widget<FilledButton>(find.byKey(const Key('sos_submit_button')));
    expect(button.onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Something failed'), findsOneWidget);
    expect(called, isFalse);
  });

  testWidgets('note is capped at 500 characters', (tester) async {
    SosFormData? data;
    await pumpForm(tester, onSubmit: (d) => data = d);

    await tester.tap(find.text('Fire'));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('note_field')), 'a' * 600);
    await tester.pump();
    expect(find.text('500/500'), findsOneWidget); // counter

    await tester.tap(find.byKey(const Key('sos_submit_button')));
    await tester.pump();

    expect(data!.note.length, 500);
  });

  group('N1 optional parameters', () {
    Future<void> pumpWith(
      WidgetTester tester, {
      String? type,
      int count = 1,
      required void Function(SosFormData) onSubmit,
    }) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SosFormWidget(
              onSubmit: onSubmit,
              initialEmergencyType: type,
              initialPeopleCount: count,
            ),
          ),
        ),
      ));
    }

    String shownCount(WidgetTester tester) => tester
        .widget<Text>(find.byKey(const Key('people_count_value')))
        .data!;

    testWidgets('initialEmergencyType preselects and can be submitted',
        (tester) async {
      SosFormData? data;
      await pumpWith(tester, type: 'DROWNING', onSubmit: (d) => data = d);

      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      await tester.tap(find.byKey(const Key('sos_submit_button')));
      await tester.pump();

      expect(data!.type, 'DROWNING');
    });

    testWidgets('initialPeopleCount is shown and clamped to 1..100',
        (tester) async {
      for (final entry in {5: '5', 0: '1', -3: '1', 500: '100'}.entries) {
        await pumpWith(tester, count: entry.key, onSubmit: (_) {});
        expect(shownCount(tester), entry.value, reason: '${entry.key}');
      }
    });

    testWidgets('unknown initial types select nothing', (tester) async {
      var called = false;
      for (final type in ['MEDICAL', 'fire', '', null]) {
        await pumpWith(tester, type: type, onSubmit: (_) => called = true);
        expect(find.byIcon(Icons.check_circle), findsNothing, reason: '$type');
      }
      await tester.tap(find.byKey(const Key('sos_submit_button')));
      await tester.pump();
      expect(find.text('Select the type of emergency'), findsOneWidget);
      expect(called, isFalse);
    });
  });
}
