import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/design/adaptive.dart';
import '../../core/design/semantic_colors.dart';
import '../../core/design/tokens.dart';
import '../../core/util/formatters.dart';
import '../../domain/finding.dart';
import '../../domain/score.dart';
import '../settings/settings_page.dart';
import '../share/invite_sheet.dart';
import '../share/milestone_sheet.dart';
import '../share/share_preview_sheet.dart';
import 'finding_detail_page.dart';
import 'scan_controller.dart';
import 'widgets/finding_row.dart';
import 'widgets/score_dial.dart';

/// The whole app, on one screen.
///
/// A score, the things behind it, and a way to fix each one. Nothing else lives
/// at this level: no tab bar, no dashboard, no feed. If a security app is not
/// obvious in the first three seconds, people close it and never learn what it
/// was trying to tell them.
class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> with WidgetsBindingObserver {
  bool _showPassing = false;
  bool _milestoneShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _runIfIdle());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Coming back from a settings screen is the exact moment the user wants to
  /// know whether the fix worked, so the scan re-runs itself rather than
  /// waiting to be asked.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final controller = AppScope.read(context).notifier!;
    if (controller.hasResult && !controller.isRunning) {
      controller.run();
    }
  }

  void _runIfIdle() {
    final controller = AppScope.read(context).notifier!;
    if (controller.phase == ScanPhase.idle) controller.run();
  }

  Future<void> _rescan() async {
    Feedback2.light();
    await context.scan.run();
    if (mounted) _maybeCelebrate();
  }

  void _maybeCelebrate() {
    final controller = AppScope.read(context).notifier!;
    final milestone = controller.pendingMilestone;
    if (milestone == null || _milestoneShown) return;
    _milestoneShown = true;
    Feedback2.success();
    showAdaptiveSheet(
      context: context,
      builder: (context) => MilestoneSheet(milestone: milestone),
    ).whenComplete(() => _milestoneShown = false);
  }

  void _openFinding(Finding finding) {
    Feedback2.selection();
    Navigator.of(context).push(
      isApple
          ? CupertinoPageRoute<void>(
              builder: (_) => FindingDetailPage(checkId: finding.check.id),
              title: 'Aegis',
            )
          : MaterialPageRoute<void>(
              builder: (_) => FindingDetailPage(checkId: finding.check.id),
            ),
    );
  }

  void _push(Widget page) {
    Navigator.of(context).push(
      isApple
          ? CupertinoPageRoute<void>(builder: (_) => page, title: 'Aegis')
          : MaterialPageRoute<void>(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.scan;
    final colors = context.colors;

    // Celebrate only once a completed scan has settled into the tree.
    if (controller.hasResult && controller.pendingMilestone != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _maybeCelebrate();
      });
    }

    return AdaptivePage(
      title: 'Aegis',
      trailing: _SettingsButton(onTap: () => _push(const SettingsPage())),
      slivers: [
        SliverToBoxAdapter(child: _Header(onRescan: _rescan)),
        if (controller.phase == ScanPhase.failed)
          SliverToBoxAdapter(child: _ProbeError(message: controller.error)),
        ..._findingSections(controller, colors),
        if (controller.hasResult)
          SliverToBoxAdapter(
            child: _ShareFooter(
              onShareScore: _openShare,
              onInvite: _openInvite,
            ),
          ),
        SliverToBoxAdapter(
          child: SizedBox(height: MediaQuery.paddingOf(context).bottom + Insets.xl),
        ),
      ],
    );
  }

  void _openInvite() {
    Feedback2.selection();
    showAdaptiveSheet(context: context, builder: (_) => const InviteSheet());
  }

  void _openShare() {
    Feedback2.selection();
    showAdaptiveSheet(
      context: context,
      builder: (_) => const SharePreviewSheet(),
    );
  }

  List<Widget> _findingSections(ScanController controller, SemanticColors colors) {
    if (!controller.hasResult) return const [];

    final open = controller.openFindings;
    final unanswered = controller.unansweredFindings;
    final passing = controller.passedFindings;
    final skipped = controller.skippedFindings;

    return [
      if (open.isNotEmpty)
        SliverToBoxAdapter(
          child: AdaptiveSection(
            header: 'Open now',
            children: [
              for (final finding in open)
                FindingRow(finding: finding, onTap: () => _openFinding(finding)),
            ],
          ),
        ),
      if (unanswered.isNotEmpty)
        SliverToBoxAdapter(
          child: AdaptiveSection(
            header: 'Only you can answer these',
            children: [
              for (final finding in unanswered)
                FindingRow(finding: finding, onTap: () => _openFinding(finding)),
            ],
          ),
        ),
      if (passing.isNotEmpty)
        SliverToBoxAdapter(
          child: AdaptiveSection(
            header: 'Holding',
            children: [
              AdaptiveRow(
                title: '${Say.count(passing.length, 'check')} passing',
                leading: Icon(
                  isApple ? CupertinoIcons.checkmark_seal_fill : Icons.verified,
                  color: colors.secure,
                  size: isApple ? 22 : 24,
                ),
                trailing: AdaptiveTextButton(
                  label: _showPassing ? 'Hide' : 'Show',
                  onPressed: () {
                    Feedback2.selection();
                    setState(() => _showPassing = !_showPassing);
                  },
                ),
              ),
              if (_showPassing)
                for (final finding in passing)
                  FindingRow(
                    finding: finding,
                    onTap: () => _openFinding(finding),
                  ),
            ],
          ),
        ),
      if (skipped.isNotEmpty)
        SliverToBoxAdapter(
          child: AdaptiveSection(
            header: 'Not readable on this phone',
            footer: 'Left out of the score rather than guessed at.',
            children: [
              for (final finding in skipped)
                AdaptiveRow(
                  title: finding.check.title,
                  subtitle: finding.detail,
                  leading: FindingIcon(finding: finding),
                  onTap: () => _openFinding(finding),
                  showChevron: true,
                ),
            ],
          ),
        ),
    ];
  }
}

/// The dial, the state of play, and the one button.
class _Header extends StatelessWidget {
  const _Header({required this.onRescan});

  final Future<void> Function() onRescan;

  @override
  Widget build(BuildContext context) {
    final controller = context.scan;
    final colors = context.colors;
    final score = controller.score;
    final running = controller.isRunning;

    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.xl, Insets.sm, Insets.xl, 0),
      child: Column(
        children: [
          ScoreDial(
            score: score,
            scanning: running,
            caption: running ? 'Checking' : null,
          ),
          const SizedBox(height: Insets.lg),
          AnimatedSwitcher(
            duration: Motion.quick,
            child: Text(
              _statusLine(controller),
              key: ValueKey(_statusLine(controller)),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                height: 1.35,
                color: colors.secondaryLabel,
              ),
            ),
          ),
          if (controller.hasResult && controller.topPriority != null) ...[
            const SizedBox(height: Insets.lg),
            _TopPriority(finding: controller.topPriority!),
          ],
          const SizedBox(height: Insets.lg),
          AdaptiveFilledButton(
            label: running
                ? 'Checking'
                : (controller.hasResult ? 'Check again' : 'Check this phone'),
            onPressed: running ? null : onRescan,
            expand: true,
          ),
        ],
      ),
    );
  }

  String _statusLine(ScanController controller) {
    if (controller.isRunning) return 'Reading this phone’s settings';
    if (controller.phase == ScanPhase.failed) {
      return 'The check could not finish.';
    }
    if (!controller.hasResult) {
      return 'Nothing has been checked yet.';
    }

    final score = controller.score;
    final parts = <String>[score.band.headline];

    if (score.issueCount > 0) {
      parts.add('${Say.count(score.issueCount, "thing")} to fix, '
          'worth ${score.pointsAvailable} points.');
    } else if (score.unansweredCount > 0) {
      parts.add('${Say.count(score.unansweredCount, "question")} left to answer.');
    }

    final delta = controller.lastDelta;
    if (delta != null && delta != 0) {
      parts.add(delta > 0 ? 'Up $delta since last time.' : 'Down ${-delta} since last time.');
    }
    return parts.join(' ');
  }
}

/// The single most valuable thing to do next, stated as an action.
class _TopPriority extends StatelessWidget {
  const _TopPriority({required this.finding});

  final Finding finding;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tint = severityColour(context, finding);
    final points = SecurityScore.pointsFor(finding, context.scan.findings);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.lg,
        vertical: Insets.md,
      ),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(Corners.container),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Start here',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: tint,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  finding.detail,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.3,
                    color: colors.label,
                  ),
                ),
              ],
            ),
          ),
          if (points > 0) ...[
            const SizedBox(width: Insets.md),
            Text(
              '+$points',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: tint,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProbeError extends StatelessWidget {
  const _ProbeError({required this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return AdaptiveSection(
      header: 'Could not read this phone',
      children: [
        AdaptiveRow(
          title: message ?? 'The device did not respond.',
          leading: Icon(
            isApple ? CupertinoIcons.exclamationmark_triangle_fill : Icons.warning,
            color: context.colors.caution,
          ),
        ),
      ],
    );
  }
}

/// Both halves of the loop, side by side and below the findings.
///
/// Sharing a score is bragging, and asking someone to check theirs is caring;
/// different people reach for different ones, and an app that only offers the
/// first is an app most people never share at all. Neither is ever forced: they
/// sit under the results because an invite is only worth sending when the app
/// was worth using.
class _ShareFooter extends StatelessWidget {
  const _ShareFooter({required this.onShareScore, required this.onInvite});

  final VoidCallback onShareScore;
  final VoidCallback onInvite;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AdaptiveSection(
      header: 'Pass it on',
      children: [
        AdaptiveRow(
          title: 'Share my score',
          subtitle: 'Just the number',
          leading: Icon(
            isApple ? CupertinoIcons.share : Icons.ios_share,
            color: colors.accent,
            size: isApple ? 22 : 24,
          ),
          onTap: onShareScore,
          showChevron: true,
        ),
        AdaptiveRow(
          title: 'Check someone else’s phone',
          subtitle: 'They get their own score',
          leading: Icon(
            isApple ? CupertinoIcons.person_2_fill : Icons.group,
            color: colors.accent,
            size: isApple ? 22 : 24,
          ),
          onTap: onInvite,
          showChevron: true,
        ),
      ],
    );
  }
}

/// One destination, so it is a button rather than a menu.
class _SettingsButton extends StatelessWidget {
  const _SettingsButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (isApple) {
      return CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: const Size(44, 44),
        onPressed: onTap,
        child: const Icon(CupertinoIcons.gear),
      );
    }
    return IconButton(onPressed: onTap, icon: const Icon(Icons.settings_outlined));
  }
}
