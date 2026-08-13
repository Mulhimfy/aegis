import 'dart:math';

import 'package:flutter/foundation.dart';

/// What an incoming link is asking for.
enum InviteKind {
  /// Someone shared their score. The recipient is being challenged to beat it.
  score,

  /// Someone asked the recipient to check their own phone, usually a parent,
  /// a partner or a friend the sender is worried about.
  request,
}

/// A parsed invite link.
@immutable
class Invite {
  const Invite({required this.kind, required this.code, this.senderScore});

  final InviteKind kind;

  /// The sender's referral code, stored on first launch.
  final String code;

  final int? senderScore;
}

/// Builds and reads the links that carry the app from one phone to the next.
///
/// The link is the whole distribution mechanism, so it has to survive being
/// pasted into any messaging app: short, all upper case, no punctuation that
/// autocorrect will mangle, and readable aloud over a phone call.
abstract final class Referral {
  static const String host = 'aegis.app';
  static const String scheme = 'aegis';

  /// Crockford base32 without I, L, O and U, so a code cannot be misread and
  /// cannot accidentally spell anything.
  static const String _alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

  static String mintCode([Random? random]) {
    final rng = random ?? Random.secure();
    return String.fromCharCodes(
      List.generate(8, (_) => _alphabet.codeUnitAt(rng.nextInt(_alphabet.length))),
    );
  }

  static Uri scoreLink({required String code, required int score}) =>
      Uri.https(host, '/s/$code', {'v': '$score'});

  static Uri requestLink({required String code}) =>
      Uri.https(host, '/c/$code');

  /// Reads an inbound link. Returns null for anything that is not ours, so a
  /// malformed or hostile link is simply ignored rather than acted on.
  static Invite? parse(Uri uri) {
    final isOurs = (uri.scheme == 'https' && uri.host == host) ||
        uri.scheme == scheme;
    if (!isOurs) return null;

    // aegis://s/CODE puts the path segment in `host` on some platforms.
    final segments = [
      if (uri.scheme == scheme && uri.host.isNotEmpty) uri.host,
      ...uri.pathSegments,
    ].where((s) => s.isNotEmpty).toList(growable: false);

    if (segments.length < 2) return null;

    final kind = switch (segments[0]) {
      's' => InviteKind.score,
      'c' => InviteKind.request,
      _ => null,
    };
    if (kind == null) return null;

    final code = _sanitiseCode(segments[1]);
    if (code == null) return null;

    return Invite(
      kind: kind,
      code: code,
      senderScore: _sanitiseScore(uri.queryParameters['v']),
    );
  }

  static String? _sanitiseCode(String raw) {
    final upper = raw.toUpperCase();
    if (upper.length != 8) return null;
    if (!upper.split('').every(_alphabet.contains)) return null;
    return upper;
  }

  static int? _sanitiseScore(String? raw) {
    final parsed = int.tryParse(raw ?? '');
    if (parsed == null) return null;
    return parsed.clamp(0, 100);
  }
}
