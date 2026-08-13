import 'package:flutter/foundation.dart';

import '../../data/prefs/store.dart';
import '../../data/probe/device_signals.dart';
import '../../data/probe/probe_channel.dart';
import '../../domain/catalog.dart';
import '../../domain/check.dart';
import '../../domain/finding.dart';
import '../../domain/fix_action.dart';
import '../../domain/score.dart';
import '../../domain/severity.dart';
import '../share/milestone.dart';
import '../share/referral.dart';

enum ScanPhase { idle, running, complete, failed }

/// The app's single source of truth.
///
/// One controller, because the app does one thing. It runs the scan, holds the
/// findings, and records what the user tells it. Everything else in the app
/// reads from here.
class ScanController extends ChangeNotifier {
  ScanController({
    required DeviceProbe probe,
    required Store store,
    DateTime Function()? clock,
  })  : _probe = probe,
        _store = store,
        _clock = clock ?? DateTime.now;

  final DeviceProbe _probe;
  final Store _store;
  final DateTime Function() _clock;

  ScanPhase _phase = ScanPhase.idle;
  DeviceSignals? _signals;
  List<Finding> _findings = const [];
  SecurityScore _score = SecurityScore.empty;
  String? _error;
  DateTime? _lastRun;
  Milestone? _pendingMilestone;
  int? _lastDelta;

  ScanPhase get phase => _phase;
  bool get isRunning => _phase == ScanPhase.running;
  bool get hasResult => _phase == ScanPhase.complete;
  DeviceSignals? get signals => _signals;
  List<Finding> get findings => _findings;
  SecurityScore get score => _score;
  String? get error => _error;
  DateTime? get lastRun => _lastRun;
  Store get store => _store;

  /// The milestone worth offering to share, or null. Cleared once acted on so
  /// the prompt never reappears for the same event.
  Milestone? get pendingMilestone => _pendingMilestone;

  /// Change in score since the previous scan, or null on the first one.
  int? get lastDelta => _lastDelta;

  List<Finding> get openFindings =>
      _findings.where((f) => f.isFail).toList(growable: false);

  List<Finding> get unansweredFindings =>
      _findings.where((f) => f.needsAnswer).toList(growable: false);

  List<Finding> get passedFindings =>
      _findings.where((f) => f.isPass).toList(growable: false);

  List<Finding> get skippedFindings => _findings
      .where((f) => f.status == CheckStatus.unavailable)
      .toList(growable: false);

  /// The single highest-value thing the user could do next.
  Finding? get topPriority {
    for (final finding in _findings) {
      if (finding.isFail && finding.check.countsTowardScore) return finding;
    }
    return null;
  }

  /// This device's own invite code, minted on first use and stable after.
  Future<String> inviteCode() async {
    final existing = _store.inviteCode();
    if (existing != null) return existing;
    final minted = Referral.mintCode();
    await _store.setInviteCode(minted);
    return minted;
  }

  // ---------------------------------------------------------------------

  Future<void> run({bool record = true}) async {
    if (_phase == ScanPhase.running) return;
    _phase = ScanPhase.running;
    _error = null;
    notifyListeners();

    final started = DateTime.now();
    try {
      final signals = await _probe.read();
      _signals = signals;
      _recompute(signals);

      // The scan itself takes a few hundred milliseconds at most. Holding the
      // sweep for a beat is not theatre: reading a score that appeared before
      // the eye registered the ring is what makes a result feel unearned and
      // therefore untrue.
      final elapsed = DateTime.now().difference(started);
      const floor = Duration(milliseconds: 900);
      if (elapsed < floor) await Future<void>.delayed(floor - elapsed);

      if (record) await _record();

      _phase = ScanPhase.complete;
      _lastRun = _clock();
    } on ProbeFailure catch (failure) {
      _error = failure.message;
      _phase = ScanPhase.failed;
    } on Object catch (error) {
      _error = 'Something went wrong reading this device. $error';
      _phase = ScanPhase.failed;
    }
    notifyListeners();
  }

  void _recompute(DeviceSignals signals) {
    _findings = Catalog.evaluate(
      EvalContext(
        signals: signals,
        now: _clock(),
        attestations: _store.attestations(),
        trustedPackages: _store.trustedPackages(),
      ),
    );
    _score = SecurityScore.from(_findings);
  }

  Future<void> _record() async {
    final now = _clock();
    final previous = _store.lastScan();
    _lastDelta = previous == null ? null : _score.value - previous.score;

    final milestone = Milestone.detect(
      score: _score,
      previous: previous,
      bestEver: _store.bestScore(),
      alreadyCelebrated: _store.celebratedMilestones(),
    );
    _pendingMilestone = SharePrompt.shouldOffer(
      milestone: milestone,
      lastPrompted: _store.lastSharePrompt(),
      now: now,
    )
        ? milestone
        : null;

    await _store.recordScan(ScanRecord(
      at: now,
      score: _score.value,
      criticalCount: _score.criticalCount,
      cautionCount: _score.cautionCount,
    ));
  }

  /// Called once the milestone has been offered, whether or not it was shared,
  /// so the same moment is never celebrated twice.
  Future<void> consumeMilestone({required bool shared}) async {
    final milestone = _pendingMilestone;
    _pendingMilestone = null;
    notifyListeners();
    if (milestone == null) return;
    await _store.markCelebrated(milestone.id);
    if (shared) await _store.markSharePrompted(_clock());
  }

  // ---------------------------------------------------------------------

  /// Records the user's answer to a check the OS will not disclose, and
  /// re-scores immediately so the effect of answering is visible at once.
  Future<void> answer(Check check, bool value) async {
    await _store.setAttestation(check.id, value, _clock());
    _refreshFromStore();
  }

  Future<void> clearAnswer(Check check) async {
    await _store.clearAttestation(check.id);
    _refreshFromStore();
  }

  /// Marks an app as reviewed and deliberately allowed to keep an elevated
  /// permission. This is what stops the app crying wolf about a password
  /// manager for the rest of its life.
  Future<void> setTrusted(String package, bool trusted) async {
    await _store.setTrusted(package, trusted);
    _refreshFromStore();
  }

  bool isTrusted(String package) => _store.trustedPackages().contains(package);

  void _refreshFromStore() {
    final signals = _signals;
    if (signals == null) return;
    _recompute(signals);
    notifyListeners();
  }

  /// Opens the settings screen that fixes a finding. Returns false when the
  /// device has no matching screen, so the caller can show the written steps
  /// instead.
  Future<bool> openFix(SettingsTarget target) => _probe.openSettings(target);
}
