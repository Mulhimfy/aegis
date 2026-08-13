import 'package:flutter/foundation.dart';

/// A user's answer to a check the OS refuses to disclose.
///
/// Answers expire. A phone that was configured correctly nine months ago is not
/// evidence about the phone today, and asking again is also what keeps the app
/// worth reopening.
@immutable
class Attestation {
  const Attestation({required this.answer, required this.answeredAt});

  final bool answer;
  final DateTime answeredAt;

  bool isFresh(DateTime now, Duration validFor) =>
      now.difference(answeredAt) < validFor;

  Map<String, Object?> toJson() => {
        'answer': answer,
        'at': answeredAt.millisecondsSinceEpoch,
      };

  static Attestation? fromJson(Object? json) {
    if (json is! Map) return null;
    final answer = json['answer'];
    final at = json['at'];
    if (answer is! bool || at is! int) return null;
    return Attestation(
      answer: answer,
      answeredAt: DateTime.fromMillisecondsSinceEpoch(at),
    );
  }
}
