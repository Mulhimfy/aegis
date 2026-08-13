import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/attestation.dart';

/// The result of one scan. Only the most recent is kept, because it is all
/// anything reads: the change since last time, and whether a milestone fired.
@immutable
class ScanRecord {
  const ScanRecord({
    required this.at,
    required this.score,
    required this.criticalCount,
    required this.cautionCount,
  });

  final DateTime at;
  final int score;
  final int criticalCount;
  final int cautionCount;

  Map<String, Object?> toJson() => {
        'at': at.millisecondsSinceEpoch,
        'score': score,
        'critical': criticalCount,
        'caution': cautionCount,
      };

  static ScanRecord? fromJson(Object? json) {
    if (json is! Map) return null;
    final at = json['at'];
    final score = json['score'];
    if (at is! int || score is! int) return null;
    return ScanRecord(
      at: DateTime.fromMillisecondsSinceEpoch(at),
      score: score,
      criticalCount: (json['critical'] as int?) ?? 0,
      cautionCount: (json['caution'] as int?) ?? 0,
    );
  }
}

/// Everything the app remembers, and the only thing it writes anywhere.
///
/// All of it stays on the device. There is no account, no server and no
/// analytics: an app that reads your phone's security posture and then uploads
/// it would be the exact thing it warns you about.
class Store {
  Store(this._prefs);

  final SharedPreferences _prefs;

  static Future<Store> open() async => Store(await SharedPreferences.getInstance());

  static const _kAttestations = 'attestations.v1';
  static const _kTrusted = 'trusted_packages.v1';
  static const _kLastScan = 'last_scan.v1';
  static const _kOnboarded = 'onboarded.v1';
  static const _kInvitedBy = 'invited_by.v1';
  static const _kInviteCode = 'invite_code.v1';
  static const _kInvitesSent = 'invites_sent.v1';
  static const _kBestScore = 'best_score.v1';
  static const _kMilestones = 'milestones.v1';
  static const _kLastPrompt = 'last_share_prompt.v1';

  // -------------------------------- Answers --------------------------------

  Map<String, Attestation> attestations() {
    final raw = _prefs.getString(_kAttestations);
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, Object?>;
      final out = <String, Attestation>{};
      decoded.forEach((key, value) {
        final record = Attestation.fromJson(value);
        if (record != null) out[key] = record;
      });
      return out;
    } on FormatException {
      return {};
    }
  }

  Future<void> setAttestation(String checkId, bool answer, DateTime now) async {
    final all = attestations()
      ..[checkId] = Attestation(answer: answer, answeredAt: now);
    await _prefs.setString(
      _kAttestations,
      jsonEncode(all.map((k, v) => MapEntry(k, v.toJson()))),
    );
  }

  Future<void> clearAttestation(String checkId) async {
    final all = attestations()..remove(checkId);
    await _prefs.setString(
      _kAttestations,
      jsonEncode(all.map((k, v) => MapEntry(k, v.toJson()))),
    );
  }

  // --------------------------- Reviewed apps -------------------------------

  Set<String> trustedPackages() =>
      (_prefs.getStringList(_kTrusted) ?? const []).toSet();

  Future<void> setTrusted(String package, bool trusted) async {
    final all = trustedPackages();
    trusted ? all.add(package) : all.remove(package);
    await _prefs.setStringList(_kTrusted, all.toList()..sort());
  }

  // ------------------------------- Last scan -------------------------------

  ScanRecord? lastScan() {
    final raw = _prefs.getString(_kLastScan);
    if (raw == null) return null;
    try {
      return ScanRecord.fromJson(jsonDecode(raw));
    } on FormatException {
      return null;
    }
  }

  Future<void> recordScan(ScanRecord record) async {
    await _prefs.setString(_kLastScan, jsonEncode(record.toJson()));
    if (record.score > bestScore()) {
      await _prefs.setInt(_kBestScore, record.score);
    }
  }

  int bestScore() => _prefs.getInt(_kBestScore) ?? 0;

  // ------------------------------- Identity --------------------------------

  bool get onboarded => _prefs.getBool(_kOnboarded) ?? false;
  Future<void> completeOnboarding() => _prefs.setBool(_kOnboarded, true);

  // -------------------------------- Invites --------------------------------

  /// The code on the link this user arrived through, if any.
  String? invitedBy() => _prefs.getString(_kInvitedBy);
  Future<void> setInvitedBy(String code) => _prefs.setString(_kInvitedBy, code);

  /// This user's own code, minted once and stable forever after.
  String? inviteCode() => _prefs.getString(_kInviteCode);
  Future<void> setInviteCode(String code) => _prefs.setString(_kInviteCode, code);

  int invitesSent() => _prefs.getInt(_kInvitesSent) ?? 0;
  Future<void> recordInviteSent() =>
      _prefs.setInt(_kInvitesSent, invitesSent() + 1);

  // ------------------------------ Milestones -------------------------------

  Set<String> celebratedMilestones() =>
      (_prefs.getStringList(_kMilestones) ?? const []).toSet();

  Future<void> markCelebrated(String id) async {
    final all = celebratedMilestones()..add(id);
    await _prefs.setStringList(_kMilestones, all.toList()..sort());
  }

  DateTime? lastSharePrompt() {
    final ms = _prefs.getInt(_kLastPrompt);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> markSharePrompted(DateTime at) =>
      _prefs.setInt(_kLastPrompt, at.millisecondsSinceEpoch);

  // --------------------------------- Reset ---------------------------------

  Future<void> eraseEverything() async {
    for (final key in [
      _kAttestations,
      _kTrusted,
      _kLastScan,
      _kOnboarded,
      _kInvitedBy,
      _kInviteCode,
      _kInvitesSent,
      _kBestScore,
      _kMilestones,
      _kLastPrompt,
    ]) {
      await _prefs.remove(key);
    }
  }
}
