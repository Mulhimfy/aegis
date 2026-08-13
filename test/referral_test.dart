import 'dart:math';

import 'package:aegis/features/share/referral.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('codes', () {
    test('are eight characters from an unambiguous alphabet', () {
      final code = Referral.mintCode(Random(7));
      expect(code.length, 8);
      expect(RegExp(r'^[0-9A-HJKMNP-TV-Z]{8}$').hasMatch(code), isTrue,
          reason: 'code $code contains a character that can be misread');
    });

    test('do not repeat in any reasonable number of installs', () {
      final codes = {for (var i = 0; i < 2000; i++) Referral.mintCode()};
      expect(codes.length, 2000);
    });
  });

  group('links', () {
    test('a score link round-trips through parsing', () {
      final link = Referral.scoreLink(code: 'ABCD2345', score: 92);
      final invite = Referral.parse(link);
      expect(invite, isNotNull);
      expect(invite!.kind, InviteKind.score);
      expect(invite.code, 'ABCD2345');
      expect(invite.senderScore, 92);
    });

    test('a check request round-trips through parsing', () {
      final invite =
          Referral.parse(Referral.requestLink(code: 'ABCD2345'));
      expect(invite!.kind, InviteKind.request);
      expect(invite.senderScore, isNull);
    });

    test('the custom scheme parses even when the path lands in the host', () {
      final invite = Referral.parse(Uri.parse('aegis://s/ABCD2345?v=70'));
      expect(invite, isNotNull);
      expect(invite!.code, 'ABCD2345');
      expect(invite.senderScore, 70);
    });

    test('a lowercase code is accepted and normalised', () {
      expect(
        Referral.parse(Uri.parse('https://aegis.app/s/abcd2345'))?.code,
        'ABCD2345',
      );
    });
  });

  group('hostile input', () {
    test('a link from another host is ignored', () {
      expect(Referral.parse(Uri.parse('https://evil.test/s/ABCD2345')), isNull);
    });

    test('an unknown path is ignored', () {
      expect(Referral.parse(Uri.parse('https://aegis.app/x/ABCD2345')), isNull);
    });

    test('a malformed code is rejected rather than half-accepted', () {
      for (final bad in const ['SHORT', 'ABCD234I', 'ABCD2345678', '']) {
        expect(
          Referral.parse(Uri.parse('https://aegis.app/s/$bad')),
          isNull,
          reason: 'accepted $bad',
        );
      }
    });

    test('a score outside 0 to 100 is clamped, never rendered raw', () {
      expect(
        Referral.parse(Uri.parse('https://aegis.app/s/ABCD2345?v=99999'))
            ?.senderScore,
        100,
      );
      expect(
        Referral.parse(Uri.parse('https://aegis.app/s/ABCD2345?v=-5'))
            ?.senderScore,
        0,
      );
      expect(
        Referral.parse(Uri.parse('https://aegis.app/s/ABCD2345?v=abc'))
            ?.senderScore,
        isNull,
      );
    });
  });
}
