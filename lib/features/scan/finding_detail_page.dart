import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_scope.dart';
import '../../core/design/adaptive.dart';
import '../../core/design/semantic_colors.dart';
import '../../core/design/tokens.dart';
import '../../domain/check.dart';
import '../../domain/finding.dart';
import '../../domain/fix_action.dart';
import '../../domain/score.dart';
import '../../domain/severity.dart';
import 'widgets/finding_row.dart';

/// One finding, explained and fixed.
///
/// The order is deliberate: what is true, why it matters, then the button. A
/// security warning nobody understands is a security warning nobody acts on,
/// and the reason has to come before the fix or the user is just obeying.
///
/// The page reads its finding live from the controller by id, so when the user
/// comes back from the settings app and the scan re-runs, this page updates
/// under them and shows the fix landing.
class FindingDetailPage extends StatelessWidget {
  const FindingDetailPage({super.key, required this.checkId});

  final String checkId;

  @override
  Widget build(BuildContext context) {
    final controller = context.scan;
    Finding? finding;
    for (final candidate in controller.findings) {
      if (candidate.check.id == checkId) {
        finding = candidate;
        break;
      }
    }

    if (finding == null) {
      return const AdaptivePage(
        title: 'Check',
        previousPageTitle: 'Aegiss',
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: Text('This check is no longer in the list.')),
          ),
        ],
      );
    }

    final check = finding.check;
    final points = SecurityScore.pointsFor(finding, controller.findings);

    return AdaptivePage(
      title: check.title,
      previousPageTitle: 'Aegiss',
      slivers: [
        SliverToBoxAdapter(child: _Verdict(finding: finding, points: points)),
        SliverToBoxAdapter(child: _Why(check: check)),
        if (finding.evidence.isNotEmpty)
          SliverToBoxAdapter(child: _Evidence(finding: finding)),
        if (finding.needsAnswer || check.source == CheckSource.attested)
          SliverToBoxAdapter(child: _Answer(finding: finding)),
        if (finding.isFail) SliverToBoxAdapter(child: _Fix(finding: finding)),
        SliverToBoxAdapter(child: _Provenance(finding: finding, points: points)),
        SliverToBoxAdapter(
          child: SizedBox(height: MediaQuery.paddingOf(context).bottom + Insets.xl),
        ),
      ],
    );
  }
}

/// The state of this one check, stated plainly and in full.
class _Verdict extends StatelessWidget {
  const _Verdict({required this.finding, required this.points});

  final Finding finding;
  final int points;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tint = severityColour(context, finding);

    final headline = switch (finding.status) {
      CheckStatus.pass => finding.check.passSummary,
      CheckStatus.fail => finding.check.failSummary,
      CheckStatus.unanswered => finding.check.attestationQuestion ??
          'This one needs your answer.',
      CheckStatus.unavailable => 'This phone will not report it.',
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.xl, Insets.sm, Insets.xl, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FindingIcon(finding: finding),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Text(
                  switch (finding.status) {
                    CheckStatus.pass => 'Holding',
                    CheckStatus.fail => finding.severity.label,
                    CheckStatus.unanswered => 'Unconfirmed',
                    CheckStatus.unavailable => 'Not readable',
                  },
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: tint,
                  ),
                ),
              ),
              if (finding.isFail && points > 0) ...[
                const SizedBox(width: Insets.sm),
                Text(
                  '+$points if fixed',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colors.secondaryLabel,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: Insets.md),
          Text(
            headline,
            style: TextStyle(
              fontSize: 22,
              height: 1.25,
              fontWeight: FontWeight.w600,
              letterSpacing: isApple ? -0.4 : 0,
              color: colors.label,
            ),
          ),
          if (finding.detail.isNotEmpty &&
              finding.detail != headline &&
              finding.status != CheckStatus.unanswered) ...[
            const SizedBox(height: Insets.sm),
            Text(
              finding.detail,
              style: TextStyle(
                fontSize: 16,
                height: 1.4,
                color: colors.secondaryLabel,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Why extends StatelessWidget {
  const _Why({required this.check});

  final Check check;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.xl, Insets.xl, Insets.xl, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'WHY THIS MATTERS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: colors.tertiaryLabel,
            ),
          ),
          const SizedBox(height: Insets.sm),
          Text(
            check.why,
            style: TextStyle(
              fontSize: 16,
              height: 1.5,
              color: colors.label,
            ),
          ),
        ],
      ),
    );
  }
}

/// The apps a finding actually points at, each one individually reviewable.
class _Evidence extends StatelessWidget {
  const _Evidence({required this.finding});

  final Finding finding;

  @override
  Widget build(BuildContext context) {
    final controller = context.scan;
    final signals = controller.signals;

    final services = switch (finding.check.id) {
      'accessibility_services' => signals?.accessibilityServices,
      'notification_access' => signals?.notificationListeners,
      'device_admins' => signals?.deviceAdmins,
      _ => null,
    };

    if (services == null || services.isEmpty) {
      return AdaptiveSection(
        header: 'What was found',
        children: [
          for (final line in finding.evidence) AdaptiveRow(title: line),
        ],
      );
    }

    return AdaptiveSection(
      header: 'Apps holding this',
      footer: 'Allow the ones you recognise. Remove the rest in Settings.',
      children: [
        for (final service in services)
          AdaptiveRow(
            title: service.label,
            subtitle: service.package,
            trailing: AdaptiveSwitch(
              value: controller.isTrusted(service.package),
              onChanged: (value) {
                Feedback2.selection();
                controller.setTrusted(service.package, value);
              },
            ),
          ),
      ],
    );
  }
}

/// The yes/no for a check the OS keeps to itself.
class _Answer extends StatelessWidget {
  const _Answer({required this.finding});

  final Finding finding;

  @override
  Widget build(BuildContext context) {
    final controller = context.scan;
    final check = finding.check;
    final answered = !finding.needsAnswer;

    return AdaptiveSection(
      header: 'Your answer',
      footer: answered
          ? 'Asked again in ${check.attestationValidFor.inDays} days.'
          : 'No app can read this one. It counts towards your score, so '
              'answer honestly.',
      children: [
        AdaptiveRow(
          title: check.attestationQuestion ?? check.title,
          subtitle: answered
              ? (finding.isPass ? 'You answered yes.' : 'You answered no.')
              : null,
        ),
        if (!answered)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Insets.lg,
              Insets.sm,
              Insets.lg,
              Insets.md,
            ),
            child: Row(
              children: [
                Expanded(
                  child: AdaptiveFilledButton(
                    label: 'Yes',
                    expand: true,
                    onPressed: () {
                      Feedback2.success();
                      controller.answer(check, true);
                    },
                  ),
                ),
                const SizedBox(width: Insets.md),
                Expanded(
                  child: _SecondaryButton(
                    label: 'No',
                    onPressed: () {
                      Feedback2.warning();
                      controller.answer(check, false);
                    },
                  ),
                ),
              ],
            ),
          )
        else
          AdaptiveRow(
            title: 'Change my answer',
            titleColor: context.colors.accent,
            onTap: () {
              Feedback2.selection();
              controller.clearAnswer(check);
            },
          ),
      ],
    );
  }
}

/// The button that closes the gap between knowing and fixing.
class _Fix extends StatefulWidget {
  const _Fix({required this.finding});

  final Finding finding;

  @override
  State<_Fix> createState() => _FixState();
}

class _FixState extends State<_Fix> {
  bool _deepLinkFailed = false;

  Future<void> _open(SettingsTarget target) async {
    Feedback2.light();
    final opened = await context.scan.openFix(target);
    if (!mounted) return;
    if (!opened) {
      setState(() => _deepLinkFailed = true);
      showTransientMessage(
        context,
        'This phone has no direct link to that screen. The steps are below.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final fix = widget.finding.check.fix;

    return switch (fix) {
      OpenSettings() => AdaptiveSection(
          header: 'Fix it',
          footer: _deepLinkFailed ? null : 'Come back and it re-checks itself.',
          children: [
            Padding(
              padding: const EdgeInsets.all(Insets.lg),
              child: AdaptiveFilledButton(
                label: fix.buttonLabel ?? 'Open settings',
                icon: isApple
                    ? CupertinoIcons.arrow_up_right_square
                    : Icons.open_in_new,
                expand: true,
                onPressed: () => _open(fix.target),
              ),
            ),
            _Steps(steps: fix.steps),
          ],
        ),
      GuidedSteps() => AdaptiveSection(
          header: 'How to fix it',
          footer: 'Come back and it re-checks itself.',
          children: [
            _Steps(steps: fix.steps),
            if (fix.learnMoreUrl != null)
              AdaptiveRow(
                title: 'Read more about this',
                titleColor: context.colors.accent,
                onTap: () => launchUrl(
                  Uri.parse(fix.learnMoreUrl!),
                  mode: LaunchMode.externalApplication,
                ),
              ),
          ],
        ),
      ReviewInApp() => AdaptiveSection(
          header: 'What to do',
          children: [AdaptiveRow(title: fix.prompt)],
        ),
    };
  }
}

/// The path through Settings, written out. Always shown, never only shown: a
/// deep link that lands on the wrong screen on one manufacturer's skin should
/// not leave the user stranded.
class _Steps extends StatelessWidget {
  const _Steps({required this.steps});

  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.lg, Insets.md, Insets.lg, Insets.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < steps.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i == steps.length - 1 ? 0 : 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 20,
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colors.tertiaryLabel,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      steps[i],
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.35,
                        color: colors.secondaryLabel,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Where the answer came from. Stated because a security app that will not say
/// how it knows something has not earned being believed.
class _Provenance extends StatelessWidget {
  const _Provenance({required this.finding, required this.points});

  final Finding finding;

  /// Already normalised to the 100-point scale, so this row and the "+N if
  /// fixed" line above it can never disagree.
  final int points;

  @override
  Widget build(BuildContext context) {
    final check = finding.check;
    final measured = check.source == CheckSource.measured;
    return AdaptiveSection(
      header: 'How this was checked',
      children: [
        AdaptiveRow(
          title: measured ? 'Read from the operating system' : 'Answered by you',
          subtitle: measured
              ? 'Never leaves this phone.'
              : 'No app can read it. Expires after '
                  '${check.attestationValidFor.inDays} days.',
          leading: Icon(
            measured
                ? (isApple ? CupertinoIcons.doc_text_search : Icons.fact_check)
                : (isApple ? CupertinoIcons.hand_raised : Icons.pan_tool_alt),
            color: context.colors.secondaryLabel,
            size: isApple ? 22 : 24,
          ),
        ),
        if (finding.inScope)
          AdaptiveRow(
            title: 'Worth',
            additionalInfo: '$points of your 100',
          ),
      ],
    );
  }
}

/// A secondary action with the same footprint as the primary one beside it.
class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (isApple) {
      return SizedBox(
        width: double.infinity,
        child: CupertinoButton(
          onPressed: onPressed,
          sizeStyle: CupertinoButtonSize.large,
          color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
          child: Text(
            label,
            style: TextStyle(color: context.colors.label),
          ),
        ),
      );
    }
    return SizedBox(
      width: double.infinity,
      child: FilledButton.tonal(onPressed: onPressed, child: Text(label)),
    );
  }
}
