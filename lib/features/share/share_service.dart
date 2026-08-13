import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/score.dart';
import 'referral.dart';
import 'share_card.dart';

/// Turns a score into something sendable, and hands it to the system share
/// sheet.
///
/// The share sheet is the platform's own, deliberately: people already know
/// where their contacts are in it, and a custom sheet would add a step to the
/// exact moment the app is trying not to lose them.
class ShareService {
  ShareService({this.captureDelegate});

  /// Overridable for tests, which cannot rasterise a real layer tree.
  final Future<Uint8List?> Function(GlobalKey key)? captureDelegate;

  /// Shares a score card. [boundaryKey] must wrap a [ShareCard] that is
  /// currently mounted, since only a laid-out layer can be rasterised.
  Future<void> shareScore({
    required GlobalKey boundaryKey,
    required SecurityScore score,
    required String code,
  }) async {
    final link = Referral.scoreLink(code: code, score: score.value);
    await _share(
      boundaryKey: boundaryKey,
      text: _scoreMessage(score, link),
      subject: 'My phone scored ${score.value}',
      fileName: 'aegis-score-${score.value}.png',
    );
  }

  /// Shares a request asking someone else to check their own phone. This is the
  /// half of the loop that reaches people who would never look for a security
  /// app: they are not being sold anything, someone who cares about them asked.
  Future<void> shareCheckRequest({required String code}) async {
    final link = Referral.requestLink(code: code);
    await SharePlus.instance.share(
      ShareParams(
        text: 'I checked my phone and found things I had no idea were open. '
            'Takes a minute.\n\n$link',
        subject: 'Check your phone',
      ),
    );
  }

  String _scoreMessage(SecurityScore score, Uri link) {
    final headline = switch (score.band) {
      ScoreBand.solid when score.isPerfect => 'My phone scored 100. Nothing open.',
      ScoreBand.solid => 'My phone scored ${score.value} out of 100.',
      ScoreBand.exposed => 'My phone scored ${score.value} out of 100. '
          '${score.issueCount} things I did not know were open.',
      ScoreBand.atRisk => 'My phone scored ${score.value} out of 100. '
          'Something was wide open.',
    };
    return '$headline\n\nWhat does yours score?\n$link';
  }

  Future<void> _share({
    required GlobalKey boundaryKey,
    required String text,
    required String subject,
    required String fileName,
  }) async {
    final png = await _capture(boundaryKey);
    if (png == null) {
      // Rasterising can fail on a device under memory pressure. The link alone
      // still works, so the loop is never broken by a missing image.
      await SharePlus.instance.share(ShareParams(text: text, subject: subject));
      return;
    }

    final file = await _writeTemp(png, fileName);
    await SharePlus.instance.share(
      ShareParams(
        text: text,
        subject: subject,
        files: [XFile(file.path, mimeType: 'image/png')],
      ),
    );
  }

  Future<Uint8List?> _capture(GlobalKey key) async {
    if (captureDelegate != null) return captureDelegate!(key);
    final object = key.currentContext?.findRenderObject();
    if (object is! RenderRepaintBoundary) return null;

    // Rasterise at the card's full pixel size regardless of the device's own
    // density, so the image looks the same coming off a budget phone as a
    // flagship.
    final ratio = ShareCard.pixelSize.width / ShareCard.logicalWidth;
    final image = await object.toImage(pixelRatio: ratio);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data?.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }

  Future<File> _writeTemp(Uint8List bytes, String name) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}${Platform.pathSeparator}$name');
    return file.writeAsBytes(bytes, flush: true);
  }
}
