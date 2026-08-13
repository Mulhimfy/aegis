import 'package:flutter/foundation.dart';

import 'check.dart';
import 'severity.dart';

/// One check, evaluated against one device, at one moment.
@immutable
class Finding {
  const Finding({
    required this.check,
    required this.status,
    required this.detail,
    this.evidence = const [],
    this.unavailableReason,
    this.severityOverride,
  });

  final Check check;
  final CheckStatus status;

  /// The specific, device-true sentence shown in the list. Not the generic
  /// summary: `Patch level is 7 months old`, not `Keep your phone updated`.
  final String detail;

  /// Named things the finding points at, such as the apps holding a
  /// permission. Rendered as a list in the detail view.
  final List<String> evidence;

  final String? unavailableReason;

  /// Raised severity for a check whose seriousness depends on the reading, such
  /// as a security patch that is a year old rather than a month.
  final Severity? severityOverride;

  bool get isPass => status == CheckStatus.pass;
  bool get isFail => status == CheckStatus.fail;
  bool get needsAnswer => status == CheckStatus.unanswered;

  /// Only failures of scoring checks cost points.
  bool get costsPoints => isFail && check.countsTowardScore;

  /// Unanswered attestations are held out of the score rather than assumed
  /// bad, so a fresh install never shows a falsely terrible number.
  bool get inScope =>
      check.countsTowardScore &&
      (status == CheckStatus.pass || status == CheckStatus.fail);

  Severity get severity => severityOverride ?? check.severity;

  Finding copyWith({CheckStatus? status, String? detail, List<String>? evidence}) =>
      Finding(
        check: check,
        status: status ?? this.status,
        detail: detail ?? this.detail,
        evidence: evidence ?? this.evidence,
        unavailableReason: unavailableReason,
        severityOverride: severityOverride,
      );
}
