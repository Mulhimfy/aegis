import 'package:aegis/app.dart';
import 'package:aegis/core/app_scope.dart';
import 'package:aegis/data/prefs/store.dart';
import 'package:aegis/data/probe/probe_channel.dart';
import 'package:aegis/domain/fix_action.dart';
import 'package:aegis/features/scan/widgets/score_dial.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fixtures.dart';

Future<Store> freshStore({bool onboarded = true}) async {
  SharedPreferences.setMockInitialValues(
    onboarded ? {'onboarded.v1': true} : {},
  );
  return Store.open();
}

/// Gives the test a tall viewport so every sliver is laid out at once.
///
/// Slivers below the fold are never built, so on the default 800x600 surface
/// most of the findings list would simply not exist and the tests would be
/// asserting about a screen no user sees.
void useTallPhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 6000);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> pumpApp(
  WidgetTester tester, {
  required DeviceProbe probe,
  required Store store,
  bool dismissMilestone = true,
}) async {
  useTallPhone(tester);
  await tester.pumpWidget(
    AegissApp(
      store: store,
      probe: probe,
    ),
  );
  // The scan holds its sweep briefly so a result never appears before the eye
  // registers it; settle past that floor.
  await tester.pump(const Duration(seconds: 2));
  await tester.pumpAndSettle();

  // A first scan that goes well raises a milestone sheet over the list. Tests
  // about the list itself need it out of the way; the sheet has its own test.
  if (dismissMilestone && find.text('Not now').evaluate().isNotEmpty) {
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
  }
}

void main() {
  testWidgets('a healthy phone shows a score and no open findings',
      (tester) async {
    await pumpApp(
      tester,
      probe: FakeProbe(Fixtures.androidHealthy()),
      store: await freshStore(),
    );

    expect(find.text('Aegiss'), findsWidgets);
    expect(find.text('Open now'), findsNothing);
    expect(find.text('Only you can answer these'), findsOneWidget);
    expect(find.textContaining('passing'), findsOneWidget);
  });

  testWidgets('an exposed phone names the exact problem on the home screen',
      (tester) async {
    await pumpApp(
      tester,
      probe: FakeProbe(Fixtures.androidHealthy(usbDebuggingEnabled: true)),
      store: await freshStore(),
    );

    expect(find.text('Open now'), findsOneWidget);
    expect(find.text('USB debugging'), findsOneWidget);
    expect(find.text('Start here'), findsOneWidget);
    expect(find.text('Critical'), findsWidgets);
  });

  testWidgets('a finding opens, explains itself, and offers the fix',
      (tester) async {
    final probe = FakeProbe(Fixtures.androidHealthy(usbDebuggingEnabled: true));
    await pumpApp(tester, probe: probe, store: await freshStore());

    await tester.tap(find.text('USB debugging'));
    await tester.pumpAndSettle();

    expect(find.text('WHY THIS MATTERS'), findsOneWidget);
    expect(find.textContaining('public charging port'), findsOneWidget);

    await tester.tap(find.text('Turn off USB debugging'));
    await tester.pumpAndSettle();

    expect(probe.opened, [SettingsTarget.developerOptions]);
  });

  testWidgets('answering a question changes the score immediately',
      (tester) async {
    await pumpApp(
      tester,
      probe: FakeProbe(Fixtures.androidHealthy()),
      store: await freshStore(),
    );

    await tester.tap(find.text('SIM lock'));
    await tester.pumpAndSettle();

    expect(find.text('Is a SIM PIN set on your phone number?'), findsWidgets);
    await tester.tap(find.text('No'));
    await tester.pumpAndSettle();

    expect(find.text('You answered no.'), findsOneWidget);
    // No app can open the SIM lock screen, so the fix is written steps.
    expect(find.text('How to fix it'), findsOneWidget);
    expect(find.text('Lock SIM card'), findsOneWidget);
  });

  testWidgets('a probe failure is reported rather than shown as a bad score',
      (tester) async {
    await pumpApp(
      tester,
      probe: _FailingProbe(),
      store: await freshStore(),
    );

    expect(find.text('Could not read this phone'), findsOneWidget);
    expect(find.text('Open now'), findsNothing);
  });

  testWidgets('first run shows the welcome screen and who invited you',
      (tester) async {
    final store = await freshStore(onboarded: false);
    useTallPhone(tester);
    await tester.pumpWidget(
      AegissApp(
        store: store,
        probe: FakeProbe(Fixtures.androidHealthy()),
        ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('What is actually'), findsOneWidget);
    expect(find.text('Check this phone'), findsOneWidget);
    expect(find.textContaining('Nothing is sent anywhere'), findsOneWidget);

    await tester.tap(find.text('Check this phone'));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(find.text('Check again'), findsOneWidget);
  });

  testWidgets('a phone with nothing open is celebrated once, with a share offer',
      (tester) async {
    await pumpApp(
      tester,
      probe: FakeProbe(Fixtures.androidHealthy()),
      store: await freshStore(),
      dismissMilestone: false,
    );

    expect(find.text('Nothing left open'), findsOneWidget);
    expect(find.text('Share a perfect score'), findsOneWidget);

    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(find.text('Share a perfect score'), findsNothing);
  });

  testWidgets('a phone with real problems is never congratulated',
      (tester) async {
    await pumpApp(
      tester,
      probe: FakeProbe(Fixtures.androidHealthy(usbDebuggingEnabled: true)),
      store: await freshStore(),
      dismissMilestone: false,
    );

    expect(find.text('Not now'), findsNothing);
  });

  testWidgets('the invite sheet opens from the home screen', (tester) async {
    await pumpApp(
      tester,
      probe: FakeProbe(Fixtures.androidHealthy()),
      store: await freshStore(),
    );

    await tester.tap(find.text('Check someone else’s phone'));
    await tester.pumpAndSettle();

    expect(find.textContaining('A parent'), findsOneWidget);
    expect(find.text('Send the check'), findsOneWidget);
  });

  testWidgets('the dial settles on the real score once the scan finishes',
      (tester) async {
    await pumpApp(
      tester,
      probe: FakeProbe(Fixtures.androidHealthy(usbDebuggingEnabled: true)),
      store: await freshStore(),
    );

    final score = AppScope.read(
      tester.element(find.byType(ScoreDial)),
    ).notifier!.score;

    expect(score.value, greaterThan(0), reason: 'the fixture should score');
    expect(
      find.descendant(
        of: find.byType(ScoreDial),
        matching: find.text('${score.value}'),
      ),
      findsOneWidget,
      reason: 'the dial must show the score it was given, not its start value',
    );
  });

  testWidgets('a score can be shared without waiting for a milestone',
      (tester) async {
    // The milestone prompt fires at most once a week, so the loop would stall
    // entirely if it were the only way to reach the card.
    await pumpApp(
      tester,
      probe: FakeProbe(Fixtures.androidHealthy(usbDebuggingEnabled: true)),
      store: await freshStore(),
    );

    expect(find.text('Not now'), findsNothing, reason: 'no milestone here');

    await tester.scrollUntilVisible(find.text('Share my score'), 400);
    await tester.tap(find.text('Share my score'));
    await tester.pumpAndSettle();

    expect(find.text('Send it'), findsOneWidget);
    expect(find.text('What does your phone score?'), findsOneWidget);
  });
}

class _FailingProbe implements DeviceProbe {
  @override
  Future<Never> read() async => throw const ProbeFailure('No response.');
  @override
  Future<bool> openSettings(SettingsTarget target) async => false;
}
