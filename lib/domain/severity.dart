/// How badly a failed check hurts.
enum Severity {
  /// The device is exposed right now and the fix is not optional.
  critical('Critical'),

  /// A real weakness, but one that needs another factor to be exploited.
  caution('Needs attention');

  const Severity(this.label);
  final String label;

  int get rank => switch (this) {
        Severity.critical => 0,
        Severity.caution => 1,
      };
}

/// The outcome of evaluating one check against the device.
enum CheckStatus {
  /// The device meets the bar.
  pass,

  /// The device does not meet the bar.
  fail,

  /// The platform will not disclose the signal, or the check does not apply to
  /// this device. Excluded from the score entirely rather than guessed.
  unavailable,

  /// A guided check the user has not answered yet.
  unanswered,
}
