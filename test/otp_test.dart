import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:zerotrust_authenticator/model/account.dart';
import 'package:zerotrust_authenticator/otp/base32.dart';
import 'package:zerotrust_authenticator/otp/otp.dart';

DateTime at(int seconds) =>
    DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);

void main() {
  test('HOTP: the RFC 4226 test values', () {
    final key = ascii.encode('12345678901234567890');
    const expected = [
      '755224',
      '287082',
      '359152',
      '969429',
      '338314',
      '254676',
      '287922',
      '162583',
      '399871',
      '520489',
    ];
    for (var i = 0; i < expected.length; i++) {
      expect(Otp.hotp(key, i), expected[i], reason: 'counter $i');
    }
  });

  test('TOTP: the RFC 6238 test values, SHA-1, SHA-256 and SHA-512', () {
    final keys = {
      OtpAlgorithm.sha1: ascii.encode('12345678901234567890'),
      OtpAlgorithm.sha256: ascii.encode('12345678901234567890123456789012'),
      OtpAlgorithm.sha512: ascii.encode(
        '1234567890123456789012345678901234567890123456789012345678901234',
      ),
    };
    const table = {
      59: ['94287082', '46119246', '90693936'],
      1111111109: ['07081804', '68084774', '25091201'],
      1111111111: ['14050471', '67062674', '99943326'],
      1234567890: ['89005924', '91819424', '93441116'],
      2000000000: ['69279037', '90698825', '38618901'],
      20000000000: ['65353130', '77737706', '47863826'],
    };
    table.forEach((seconds, codes) {
      for (final algorithm in OtpAlgorithm.values) {
        expect(
          Otp.totp(
            keys[algorithm]!,
            at(seconds),
            digits: 8,
            algorithm: algorithm,
          ),
          codes[algorithm.index],
          reason: '$seconds ${algorithm.label}',
        );
      }
    });
  });

  test('Steam Guard: five characters, checked against another program', () {
    final key = Base32.decode('JBSWY3DPEHPK3PXP');
    expect(Otp.steam(key, at(1700000000)), '2KM2P');
    expect(Otp.steam(key, at(59)), '2YXGV');
  });

  test('base32: the RFC 4648 values, spaces and lower case forgiven', () {
    const table = {
      'f': 'MY',
      'fo': 'MZXQ',
      'foo': 'MZXW6',
      'foob': 'MZXW6YQ',
      'fooba': 'MZXW6YTB',
      'foobar': 'MZXW6YTBOI',
    };
    table.forEach((plain, encoded) {
      expect(Base32.encode(ascii.encode(plain)), encoded);
      expect(ascii.decode(Base32.decode(encoded)), plain);
    });
    expect(Base32.normalize('jbsw y3dp-ehpk 3pxp=='), 'JBSWY3DPEHPK3PXP');
    expect(Base32.isValid('JBSWY3DPEHPK3PXP'), isTrue);
    expect(Base32.isValid('JBSW1'), isFalse);
    expect(Base32.isValid(''), isFalse);
  });

  test('an account: its code, when the code runs out, how much is left', () {
    const account = Account(id: 'a', secret: 'JBSWY3DPEHPK3PXP');
    expect(account.codeAt(at(1700000000)), '324550');
    expect(account.validUntil(at(1700000000)), at(1700000010).toLocal());
    expect(account.remaining(at(1700000000)), closeTo(1 / 3, 0.001));

    final counted = account.copyWith(type: OtpType.hotp, counter: 3);
    expect(counted.validUntil(at(1700000000)), isNull);
    expect(counted.codeAt(at(0)), counted.codeAt(at(1700000000)));
    expect(spacedCode('324550'), '324 550');
    expect(spacedCode('12345678'), '1234 5678');
    expect(spacedCode('2KM2P'), '2KM2P');
  });

  test('an account survives being saved and read back', () {
    final account = Account(
      id: 'a',
      issuer: 'GitHub',
      name: 'edo',
      secret: 'JBSWY3DPEHPK3PXP',
      type: OtpType.hotp,
      algorithm: OtpAlgorithm.sha256,
      digits: 8,
      period: 60,
      counter: 9,
      groupId: 'g',
      note: 'work',
      recoveryCodes: const ['abcd-efgh'],
      packages: const ['com.github.android'],
      domains: const ['github.com'],
      pinned: true,
      order: 4,
      createdAt: at(1700000000).toLocal(),
      trashedAt: at(1700000500).toLocal(),
    );
    final json = jsonDecode(jsonEncode(account.toJson())) as Map;
    final back = Account.fromJson('a', json.cast<String, Object?>());
    expect(back.toJson(), account.toJson());
    expect(back.trashed, isTrue);
    // Clearing a field writes null, so the other devices clear it too.
    final cleared = back.copyWith(groupId: () => null, trashedAt: () => null);
    expect(cleared.toJson()['groupId'], isNull);
    expect(cleared.trashed, isFalse);
  });
}
