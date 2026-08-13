import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_scope.dart';
import '../../core/design/adaptive.dart';
import '../../core/design/semantic_colors.dart';
import '../../core/design/tokens.dart';
import 'referral.dart';

/// The other half of the loop: ask someone else to check their phone.
///
/// This reaches people who would never install a security app, because it is
/// not an advertisement. Someone who knows them asked.
class InviteSheet extends StatefulWidget {
  const InviteSheet({super.key});

  @override
  State<InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends State<InviteSheet> {
  String? _code;
  bool _sending = false;
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    AppScope.read(context).notifier!.inviteCode().then((code) {
      if (mounted) setState(() => _code = code);
    });
  }

  Future<void> _send() async {
    if (_sending) return;
    setState(() => _sending = true);
    Feedback2.light();

    final scope = AppScope.read(context);
    final code = await scope.notifier!.inviteCode();
    try {
      await scope.share.shareCheckRequest(code: code);
      await scope.store.recordInviteSent();
    } finally {
      if (mounted) {
        setState(() => _sending = false);
        unawaited(Navigator.of(context).maybePop());
      }
    }
  }

  Future<void> _copyLink() async {
    final code = _code;
    if (code == null) return;
    await Clipboard.setData(
      ClipboardData(text: Referral.requestLink(code: code).toString()),
    );
    if (!mounted) return;
    Feedback2.selection();

    // Confirmation goes in the button. A snackbar is drawn by the scaffold
    // underneath this sheet, so nobody would see it.
    setState(() => _copied = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Insets.xl, Insets.lg, Insets.xl, Insets.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Check someone else’s phone',
              style: TextStyle(
                fontSize: 22,
                height: 1.2,
                fontWeight: FontWeight.w600,
                letterSpacing: isApple ? -0.5 : 0,
                color: colors.label,
              ),
            ),
            const SizedBox(height: Insets.sm),
            Text(
              'A parent, whoever shares your accounts, a teenager. They get '
              'their own score. Nothing comes back to you.',
              style: TextStyle(
                fontSize: 15,
                height: 1.4,
                color: colors.secondaryLabel,
              ),
            ),
            const SizedBox(height: Insets.xl),
            AdaptiveFilledButton(
              label: _sending ? 'Opening' : 'Send the check',
              icon: isApple ? CupertinoIcons.share : Icons.ios_share,
              expand: true,
              onPressed: _sending ? null : _send,
            ),
            const SizedBox(height: Insets.xs),
            Center(
              child: AdaptiveTextButton(
                label: _copied ? 'Copied' : 'Copy the link',
                onPressed: _code == null || _copied ? null : _copyLink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
