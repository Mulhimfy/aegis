import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/design/adaptive.dart';
import '../../core/design/semantic_colors.dart';
import '../../core/design/tokens.dart';
import '../share/referral.dart';

/// First run.
///
/// A promise, one line about what the app will not do, and a button. If someone
/// arrived through an invite, the score they were sent goes at the top: it is
/// the most persuasive thing on the screen and it is also true.
class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key, required this.invite, required this.onBegin});

  final Invite? invite;
  final VoidCallback onBegin;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final bottom = MediaQuery.paddingOf(context).bottom;

    final content = SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(Insets.xl, Insets.xl, Insets.xl, bottom + Insets.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Spacer(),
            if (invite != null) _Referred(invite: invite!),
            Text(
              'What is actually\nopen on your phone',
              style: TextStyle(
                fontSize: 34,
                height: 1.15,
                fontWeight: FontWeight.w700,
                letterSpacing: isApple ? -1.0 : -0.5,
                color: colors.label,
              ),
            ),
            const SizedBox(height: Insets.lg),
            Text(
              'Aegiss reads your phone’s security settings, scores them, and '
              'tells you which one to change first.',
              style: TextStyle(
                fontSize: 17,
                height: 1.45,
                color: colors.secondaryLabel,
              ),
            ),
            const Spacer(),
            AdaptiveFilledButton(
              label: 'Check this phone',
              expand: true,
              onPressed: onBegin,
            ),
            const SizedBox(height: Insets.md),
            Text(
              'No account. Nothing is sent anywhere. It cannot change a thing.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: colors.tertiaryLabel,
              ),
            ),
          ],
        ),
      ),
    );

    if (isApple) {
      return CupertinoPageScaffold(
        backgroundColor: colors.background,
        child: content,
      );
    }
    return Scaffold(backgroundColor: colors.background, body: content);
  }
}

/// The reason this person opened the app at all.
class _Referred extends StatelessWidget {
  const _Referred({required this.invite});

  final Invite invite;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final score = invite.senderScore;

    final line = switch (invite.kind) {
      InviteKind.score when score != null => 'They scored $score out of 100.',
      InviteKind.score => 'Someone sent you their score.',
      InviteKind.request => 'Someone asked you to check your phone.',
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.xl),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Insets.lg,
          vertical: Insets.md,
        ),
        decoration: BoxDecoration(
          color: colors.accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(Corners.container),
        ),
        child: Text(
          line,
          style: TextStyle(
            fontSize: 15,
            height: 1.3,
            fontWeight: FontWeight.w600,
            color: colors.accent,
          ),
        ),
      ),
    );
  }
}
