import 'dart:io';
import 'dart:ui' as ui;

import 'package:aegis/domain/score.dart';
import 'package:aegis/features/share/share_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

SecurityScore band(ScoreBand band, int value, {int critical = 0, int caution = 0}) =>
    SecurityScore(
      value: value,
      band: band,
      criticalCount: critical,
      cautionCount: caution,
      passedCount: 12,
      scoredCount: 18,
      unansweredCount: 0,
      pointsAvailable: 100 - value,
    );

/// Set `AEGIS_DUMP_CARDS=<dir>` to write the rendered cards out as PNGs. The
/// card is the app's only piece of outbound design, so being able to look at
/// the real pixels without a device is worth the twenty lines.
Future<void> maybeDump(WidgetTester tester, GlobalKey key, String name) async {
  final dir = Platform.environment['AEGIS_DUMP_CARDS'];
  if (dir == null) return;
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final ratio = ShareCard.pixelSize.width / ShareCard.logicalWidth;
    final image = await boundary.toImage(pixelRatio: ratio);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (data == null) return;
    await File('$dir/$name.png').writeAsBytes(data.buffer.asUint8List());
  });
}

Future<void> pumpCard(
  WidgetTester tester,
  GlobalKey key,
  SecurityScore score, {
  String? subtitle,
}) async {
  tester.view.physicalSize = const Size(1200, 2000);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: RepaintBoundary(
          key: key,
          child: ShareCard(
            score: score,
            subtitle: subtitle,
            linkLabel: 'aegis.app',
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the card lays out for every band without overflowing',
      (tester) async {
    final cases = <(String, SecurityScore)>[
      ('perfect', band(ScoreBand.solid, 100)),
      ('solid', band(ScoreBand.solid, 93, caution: 1)),
      ('exposed', band(ScoreBand.exposed, 68, caution: 4)),
      ('at_risk', band(ScoreBand.atRisk, 31, critical: 2, caution: 3)),
    ];

    for (final (name, score) in cases) {
      final key = GlobalKey();
      await pumpCard(tester, key, score);
      expect(tester.takeException(), isNull, reason: 'card $name overflowed');
      expect(find.text('${score.value}'), findsOneWidget);
      expect(find.text('AEGIS'), findsOneWidget);
      await maybeDump(tester, key, name);
    }
  });

  testWidgets('a milestone headline replaces the default line', (tester) async {
    final key = GlobalKey();
    await pumpCard(
      tester,
      key,
      band(ScoreBand.solid, 91),
      subtitle: 'Up 18 points',
    );
    expect(find.text('Up 18 points'), findsOneWidget);
    expect(find.text('Locked down'), findsNothing);
    await maybeDump(tester, key, 'milestone');
  });
}
