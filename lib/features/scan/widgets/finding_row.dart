import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/design/adaptive.dart';
import '../../../core/design/semantic_colors.dart';
import '../../../core/design/tokens.dart';
import '../../../domain/check.dart';
import '../../../domain/finding.dart';
import '../../../domain/severity.dart';

/// The glyph for a check's area.
///
/// iOS gets SF Symbols through CupertinoIcons, Android gets Material Symbols.
/// Same meaning, each platform's own drawing.
IconData iconForArea(CheckArea area) {
  if (isApple) {
    return switch (area) {
      CheckArea.lock => CupertinoIcons.lock_fill,
      CheckArea.software => CupertinoIcons.arrow_down_circle_fill,
      CheckArea.integrity => CupertinoIcons.checkmark_shield_fill,
      CheckArea.apps => CupertinoIcons.square_grid_2x2_fill,
      CheckArea.network => CupertinoIcons.wifi,
      CheckArea.recovery => CupertinoIcons.arrow_counterclockwise_circle_fill,
    };
  }
  return switch (area) {
    CheckArea.lock => Icons.lock,
    CheckArea.software => Icons.system_update,
    CheckArea.integrity => Icons.verified_user,
    CheckArea.apps => Icons.apps,
    CheckArea.network => Icons.wifi,
    CheckArea.recovery => Icons.settings_backup_restore,
  };
}

Color severityColour(BuildContext context, Finding finding) {
  final colors = context.colors;
  return switch (finding.status) {
    CheckStatus.pass => colors.secure,
    CheckStatus.unanswered => colors.accent,
    CheckStatus.unavailable => colors.tertiaryLabel,
    CheckStatus.fail => switch (finding.severity) {
        Severity.critical => colors.critical,
        Severity.caution => colors.caution,
      },
  };
}

/// A tinted rounded square holding a white glyph, on iOS, and a plain tinted
/// glyph on Android. Both are what the platform's own settings screens do.
class FindingIcon extends StatelessWidget {
  const FindingIcon({super.key, required this.finding});

  final Finding finding;

  @override
  Widget build(BuildContext context) {
    final tint = severityColour(context, finding);
    final icon = iconForArea(finding.check.area);

    if (!isApple) {
      return Icon(icon, color: tint);
    }

    return Container(
      width: 29,
      height: 29,
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Icon(icon, size: 17, color: CupertinoColors.white),
    );
  }
}

/// One finding in the list.
class FindingRow extends StatelessWidget {
  const FindingRow({super.key, required this.finding, required this.onTap});

  final Finding finding;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tint = severityColour(context, finding);

    final trailing = switch (finding.status) {
      CheckStatus.fail when finding.severity == Severity.critical => _Tag(
          label: 'Critical',
          color: colors.critical,
        ),
      CheckStatus.unanswered => _Tag(label: 'Confirm', color: colors.accent),
      CheckStatus.pass => Icon(
          isApple ? CupertinoIcons.checkmark_alt : Icons.check,
          size: 18,
          color: colors.secure,
        ),
      _ => null,
    };

    return AdaptiveRow(
      title: finding.check.title,
      subtitle: finding.detail,
      leading: FindingIcon(finding: finding),
      titleColor: finding.isFail ? tint : null,
      onTap: onTap,
      trailing: trailing == null
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                trailing,
                const SizedBox(width: Insets.sm),
                _Chevron(color: colors.tertiaryLabel),
              ],
            ),
      showChevron: trailing == null,
    );
  }
}

class _Chevron extends StatelessWidget {
  const _Chevron({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => isApple
      ? const CupertinoListTileChevron()
      : Icon(Icons.chevron_right, color: color);
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        color: color,
        fontSize: isApple ? 13 : 12,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
