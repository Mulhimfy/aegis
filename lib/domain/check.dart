import 'package:flutter/foundation.dart';

import 'fix_action.dart';
import 'severity.dart';

/// Which surface of the device a check belongs to. Only used to group the
/// findings list; it carries no weight.
enum CheckArea {
  lock('Lock & unlock'),
  software('Software'),
  integrity('Device integrity'),
  apps('App reach'),
  network('Network'),
  recovery('Recovery');

  const CheckArea(this.label);
  final String label;
}

/// How a check gets its answer.
enum CheckSource {
  /// Read straight from the OS. No user input, cannot be wrong.
  measured,

  /// The OS will not disclose it, so the user confirms it once and the answer
  /// is remembered until it expires.
  attested,
}

/// A single security property the app knows how to judge.
@immutable
class Check {
  const Check({
    required this.id,
    required this.title,
    required this.area,
    required this.severity,
    required this.weight,
    required this.source,
    required this.why,
    required this.passSummary,
    required this.failSummary,
    required this.fix,
    this.attestationQuestion,
    this.attestationValidFor = const Duration(days: 90),
  });

  /// Stable identifier. Persisted with the user's answers, so it must never
  /// change once shipped.
  final String id;

  final String title;
  final CheckArea area;
  final Severity severity;

  /// Points at stake, before normalisation. Relative to the other checks that
  /// apply to the same device.
  final int weight;

  final CheckSource source;

  /// Plain-language reason this matters. Shown in the detail view, written to
  /// be understood by someone who is not technical.
  final String why;

  final String passSummary;
  final String failSummary;

  final FixAction fix;

  /// The yes/no question posed for an [CheckSource.attested] check.
  final String? attestationQuestion;

  /// How long an attestation stays trusted before the user is asked again.
  final Duration attestationValidFor;

  bool get countsTowardScore => weight > 0;
}
