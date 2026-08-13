import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/design/adaptive.dart';
import '../../core/design/semantic_colors.dart';
import '../../core/design/tokens.dart';
import 'milestone.dart';
import 'share_preview_sheet.dart';

/// Shown once, after something worth mentioning actually happened.
///
/// This is the only moment the app ever asks for anything, and it asks after
/// giving rather than before. A person who has just watched their phone get
/// measurably harder to break into is the only person whose recommendation
/// carries weight, which is exactly why the ask waits for that moment instead
/// of arriving on launch.
class MilestoneSheet extends StatelessWidget {
  const MilestoneSheet({super.key, required this.milestone});

  final Milestone milestone;

  Future<void> _share(BuildContext context) async {
    final navigator = Navigator.of(context);
    Feedback2.light();
    await navigator.maybePop();
    if (!context.mounted) return;
    await showAdaptiveSheet(
      context: context,
      builder: (_) => SharePreviewSheet(subtitle: milestone.headline),
    );
  }

  Future<void> _dismiss(BuildContext context) async {
    final controller = AppScope.read(context).notifier!;
    await Navigator.of(context).maybePop();
    await controller.consumeMilestone(shared: false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final score = context.scan.score;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Insets.xl, Insets.xl, Insets.xl, Insets.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  '${score.value}',
                  style: TextStyle(
                    fontSize: 44,
                    height: 1,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -1.5,
                    color: colors.secure,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: Insets.lg),
                Expanded(
                  child: Text(
                    milestone.headline,
                    style: TextStyle(
                      fontSize: 22,
                      height: 1.2,
                      fontWeight: FontWeight.w600,
                      letterSpacing: isApple ? -0.4 : 0,
                      color: colors.label,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Insets.lg),
            Text(
              milestone.body,
              style: TextStyle(
                fontSize: 16,
                height: 1.45,
                color: colors.secondaryLabel,
              ),
            ),
            const SizedBox(height: Insets.xl),
            AdaptiveFilledButton(
              label: milestone.shareLabel,
              icon: isApple ? CupertinoIcons.share : Icons.ios_share,
              expand: true,
              onPressed: () => _share(context),
            ),
            const SizedBox(height: Insets.xs),
            Center(
              child: AdaptiveTextButton(
                label: 'Not now',
                onPressed: () => _dismiss(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
