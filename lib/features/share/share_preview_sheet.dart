import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/design/adaptive.dart';
import '../../core/design/semantic_colors.dart';
import '../../core/design/tokens.dart';
import 'referral.dart';
import 'share_card.dart';

/// Shows the exact image that is about to be sent, then sends it.
///
/// People will not forward something they have not seen. The card is the only
/// thing on the sheet, because anything else is a step between wanting to send
/// it and sending it.
class SharePreviewSheet extends StatefulWidget {
  const SharePreviewSheet({super.key, this.subtitle});

  /// Overrides the card's own line when a milestone has something more
  /// specific to say than the band.
  final String? subtitle;

  @override
  State<SharePreviewSheet> createState() => _SharePreviewSheetState();
}

class _SharePreviewSheetState extends State<SharePreviewSheet> {
  final GlobalKey _boundary = GlobalKey();
  bool _sending = false;

  Future<void> _send() async {
    if (_sending) return;
    setState(() => _sending = true);
    Feedback2.light();

    final scope = AppScope.read(context);
    final controller = scope.notifier!;
    final code = await controller.inviteCode();

    try {
      await scope.share.shareScore(
        boundaryKey: _boundary,
        score: controller.score,
        code: code,
      );
      await scope.store.recordInviteSent();
      await controller.consumeMilestone(shared: true);
    } finally {
      if (mounted) {
        setState(() => _sending = false);
        unawaited(Navigator.of(context).maybePop());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final score = context.scan.score;
    final colors = context.colors;
    final available = MediaQuery.sizeOf(context).width - Insets.xl * 2;
    final scale = (available / ShareCard.logicalWidth).clamp(0.4, 1.0);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Insets.xl, Insets.lg, Insets.xl, Insets.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: SizedBox(
                width: ShareCard.logicalWidth * scale,
                height: ShareCard.logicalHeight * scale,
                child: FittedBox(
                  fit: BoxFit.contain,
                  // Rasterising works off this layer, so what is on screen is
                  // byte for byte what gets sent.
                  child: RepaintBoundary(
                    key: _boundary,
                    child: ShareCard(
                      score: score,
                      subtitle: widget.subtitle,
                      linkLabel: Referral.host,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: Insets.lg),
            Text(
              'Only the card is shared. Nothing about what is open.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: colors.tertiaryLabel),
            ),
            const SizedBox(height: Insets.lg),
            AdaptiveFilledButton(
              label: _sending ? 'Opening' : 'Send it',
              icon: isApple ? CupertinoIcons.share : Icons.ios_share,
              expand: true,
              onPressed: _sending ? null : _send,
            ),
          ],
        ),
      ),
    );
  }
}
