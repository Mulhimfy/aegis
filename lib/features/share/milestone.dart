import 'package:flutter/foundation.dart';

import '../../data/prefs/store.dart';
import '../../domain/score.dart';

/// A moment worth telling someone about.
///
/// The app never nags. It waits until something genuinely happened, says so
/// once, and offers a card that is worth sending because it is true. That is
/// the whole growth mechanic: a person who just watched their score jump has a
/// real reason to send it, and the person receiving it has a real reason to
/// check their own.
@immutable
class Milestone {
  const Milestone({
    required this.id,
    required this.headline,
    required this.body,
    required this.shareLabel,
    required this.repeatable,
  });

  /// Stable per occurrence, so a one-off milestone is celebrated exactly once.
  final String id;

  final String headline;
  final String body;
  final String shareLabel;

  /// Whether this milestone can fire again later at a different value.
  final bool repeatable;

  /// Picks the single most worthwhile thing to say after a scan, or null when
  /// nothing happened. Ordered by how much the user actually earned it.
  static Milestone? detect({
    required SecurityScore score,
    required ScanRecord? previous,
    required int bestEver,
    required Set<String> alreadyCelebrated,
  }) {
    final candidates = <Milestone>[];

    if (score.isPerfect) {
      candidates.add(const Milestone(
        id: 'perfect',
        headline: 'Nothing left open',
        body:
            'Every check this phone can answer, it answers correctly. Very few '
            'phones get here.',
        shareLabel: 'Share a perfect score',
        repeatable: false,
      ));
    }

    if (previous != null) {
      final gain = score.value - previous.score;
      if (gain >= 10) {
        candidates.add(Milestone(
          id: 'jump_${score.value}',
          headline: 'Up $gain points',
          body:
              'You went from ${previous.score} to ${score.value}. That is a real '
              'change in how hard this phone is to get into.',
          shareLabel: 'Share the jump',
          repeatable: true,
        ));
      }
      if (previous.criticalCount > 0 && score.criticalCount == 0) {
        candidates.add(const Milestone(
          id: 'criticals_cleared',
          headline: 'Nothing critical left',
          body:
              'Everything that was wide open is now closed. This is the part '
              'that actually matters.',
          shareLabel: 'Share it',
          repeatable: true,
        ));
      }
    }

    if (score.value >= 90 && bestEver < 90) {
      candidates.add(const Milestone(
        id: 'first_90',
        headline: 'Into the top band',
        body: 'Your phone is now better protected than most people\'s.',
        shareLabel: 'Share your score',
        repeatable: false,
      ));
    }

    for (final candidate in candidates) {
      if (candidate.repeatable || !alreadyCelebrated.contains(candidate.id)) {
        return candidate;
      }
    }
    return null;
  }
}

/// Decides when it is reasonable to ask someone to share.
///
/// Two rules, both about respect: never twice in the same week, and never
/// without a milestone behind it. An app that asks constantly gets muted, and a
/// muted app spreads to nobody.
abstract final class SharePrompt {
  static const Duration cooldown = Duration(days: 7);

  static bool shouldOffer({
    required Milestone? milestone,
    required DateTime? lastPrompted,
    required DateTime now,
  }) {
    if (milestone == null) return false;
    if (lastPrompted == null) return true;
    return now.difference(lastPrompted) >= cooldown;
  }
}
