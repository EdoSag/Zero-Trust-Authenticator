import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_authenticator/model/account.dart';
import 'package:zerotrust_authenticator/otp/otp.dart';
import 'package:zerotrust_authenticator/transfer/backup_file.dart';
import 'package:zerotrust_authenticator/transfer/importer.dart';

const secret = 'JBSWY3DPEHPK3PXP';

/// Files encrypted by another program (Python: scrypt, PBKDF2, AES-GCM),
/// in the layout Aegis and 2FAS write.
Map<String, Object?> encrypted() =>
    (jsonDecode(File('test/fixtures/encrypted.json').readAsStringSync()) as Map)
        .cast<String, Object?>();

void main() {
  test('Aegis, not encrypted', () async {
    final got = await Importer.read(
      jsonEncode({
        'version': 1,
        'header': {'slots': null, 'params': null},
        'db': {
          'version': 2,
          'entries': [
            {
              'type': 'totp',
              'name': 'edo',
              'issuer': 'GitHub',
              'note': 'work',
              'favorite': true,
              'info': {
                'secret': secret,
                'algo': 'SHA256',
                'digits': 8,
                'period': 60,
              },
            },
            {
              'type': 'steam',
              'name': 'gamer',
              'issuer': 'Steam',
              'info': {
                'secret': secret,
                'algo': 'SHA1',
                'digits': 5,
                'period': 30,
              },
            },
            // No key: left out.
            {
              'type': 'totp',
              'name': 'broken',
              'issuer': 'X',
              'info': {'secret': ''},
            },
          ],
        },
      }),
    );
    expect(got.source, ImportSource.aegis);
    expect(got.accounts, hasLength(2));
    final a = got.accounts.first;
    expect(a.issuer, 'GitHub');
    expect(a.name, 'edo');
    expect(a.secret, secret);
    expect(a.algorithm, OtpAlgorithm.sha256);
    expect(a.digits, 8);
    expect(a.period, 60);
    expect(a.note, 'work');
    expect(a.pinned, isTrue);
    expect(got.accounts[1].type, OtpType.steam);
  });

  test('Aegis, encrypted with a password', () async {
    final text = jsonEncode(encrypted()['aegis']);
    await expectLater(
      Importer.read(text),
      throwsA(
        isA<PasswordNeeded>().having(
          (e) => e.source,
          'source',
          ImportSource.aegis,
        ),
      ),
    );
    await expectLater(
      Importer.read(text, password: 'wrong'),
      throwsA(isA<WrongPassphrase>()),
    );
    final got = await Importer.read(text, password: 'aegis-pass');
    expect(got.accounts, hasLength(3));
    expect(got.accounts[0].issuer, 'GitHub');
    expect(got.accounts[0].secret, secret);
    expect(got.accounts[0].pinned, isTrue);
    expect(got.accounts[1].type, OtpType.hotp);
    expect(got.accounts[1].algorithm, OtpAlgorithm.sha256);
    expect(got.accounts[1].digits, 8);
    expect(got.accounts[1].counter, 5);
    expect(got.accounts[2].type, OtpType.steam);
  });

  test('2FAS, plain and with a password', () async {
    final plain = await Importer.read(
      jsonEncode({
        'services': [
          {
            'name': 'GitHub',
            'secret': secret.toLowerCase(),
            'otp': {
              'account': 'edo',
              'issuer': 'GitHub',
              'digits': 6,
              'period': 30,
              'algorithm': 'SHA1',
              'tokenType': 'TOTP',
            },
          },
        ],
        'schemaVersion': 4,
      }),
    );
    expect(plain.source, ImportSource.twoFas);
    expect(plain.accounts.single.issuer, 'GitHub');
    expect(plain.accounts.single.name, 'edo');
    expect(plain.accounts.single.secret, secret);

    final text = jsonEncode(encrypted()['twoFas']);
    await expectLater(Importer.read(text), throwsA(isA<PasswordNeeded>()));
    await expectLater(
      Importer.read(text, password: 'nope'),
      throwsA(isA<WrongPassphrase>()),
    );
    final got = await Importer.read(text, password: '2fas-pass');
    expect(got.accounts, hasLength(2));
    expect(got.accounts[0].name, 'edo');
    expect(got.accounts[1].issuer, 'Bank');
    expect(got.accounts[1].name, 'bank');
    expect(got.accounts[1].type, OtpType.hotp);
    expect(got.accounts[1].counter, 3);
  });

  test('andOTP', () async {
    final got = await Importer.read(
      jsonEncode([
        {
          'secret': secret,
          'issuer': 'GitHub',
          'label': 'GitHub - edo',
          'digits': 6,
          'type': 'TOTP',
          'algorithm': 'SHA1',
          'period': 30,
        },
        {'secret': secret, 'label': 'Bank:me', 'type': 'HOTP', 'counter': 4},
      ]),
    );
    expect(got.source, ImportSource.andOtp);
    expect(got.accounts[0].issuer, 'GitHub');
    expect(got.accounts[0].name, 'edo');
    expect(got.accounts[1].issuer, 'Bank');
    expect(got.accounts[1].name, 'me');
    expect(got.accounts[1].type, OtpType.hotp);
    expect(got.accounts[1].counter, 4);
  });

  test('FreeOTP+: the key as signed bytes', () async {
    final got = await Importer.read(
      jsonEncode({
        'tokenOrder': ['GitHub:edo'],
        'tokens': [
          {
            'algo': 'SHA1',
            'counter': 0,
            'digits': 6,
            'issuerExt': 'GitHub',
            'label': 'edo',
            'period': 30,
            // "Hello!" then 0xDE 0xAD 0xBE 0xEF, as Java bytes.
            'secret': [72, 101, 108, 108, 111, 33, -34, -83, -66, -17],
            'type': 'TOTP',
          },
        ],
      }),
    );
    expect(got.source, ImportSource.freeOtp);
    expect(got.accounts.single.secret, secret);
    expect(got.accounts.single.issuer, 'GitHub');
  });

  test('Bitwarden: only the items with a code', () async {
    final got = await Importer.read(
      jsonEncode({
        'encrypted': false,
        'items': [
          {
            'type': 1,
            'name': 'GitHub',
            'login': {'username': 'edo', 'totp': 'jbsw y3dp ehpk 3pxp'},
          },
          {
            'type': 1,
            'name': 'Bank site',
            'login': {
              'username': 'me',
              'totp': 'otpauth://totp/Bank:me?secret=$secret&digits=8',
            },
          },
          {
            'type': 1,
            'name': 'No code',
            'login': {'username': 'x', 'totp': null},
          },
          {'type': 2, 'name': 'A note'},
        ],
      }),
    );
    expect(got.source, ImportSource.bitwarden);
    expect(got.accounts, hasLength(2));
    expect(got.accounts[0].issuer, 'GitHub');
    expect(got.accounts[0].name, 'edo');
    expect(got.accounts[0].secret, secret);
    expect(got.accounts[1].issuer, 'Bank');
    expect(got.accounts[1].digits, 8);
  });

  test('links, one per line (Ente Auth, or pasted)', () async {
    final got = await Importer.read('''
otpauth://totp/GitHub:edo?secret=$secret&issuer=GitHub
this line is not a link
otpauth://totp/broken
otpauth://hotp/Bank:me?secret=$secret&counter=2
''');
    expect(got.source, ImportSource.links);
    expect([for (final a in got.accounts) a.issuer], ['GitHub', 'Bank']);
  });

  test('what is not an export is said to be unknown', () async {
    for (final text in ['', 'hello', '{"a": 1}', '[1, 2]', '{not json']) {
      await expectLater(
        Importer.read(text),
        throwsA(isA<UnknownImport>()),
        reason: text,
      );
    }
  });

  test(
    'the backup file: sealed, opened, and closed to a wrong password',
    () async {
      final accounts = [
        const Account(
          id: 'a1',
          issuer: 'GitHub',
          name: 'edo',
          secret: secret,
          groupId: 'g1',
          recoveryCodes: ['aaaa-bbbb'],
          domains: ['github.com'],
          pinned: true,
          order: 1,
        ),
        const Account(
          id: 'a2',
          issuer: 'Bank',
          secret: 'GEZDGNBVGY3TQOJQ',
          type: OtpType.hotp,
          counter: 9,
          order: 2,
        ),
      ];
      const groups = [AccountGroup(id: 'g1', name: 'Work', order: 1)];
      final text = await BackupFile.seal(
        accounts: accounts,
        groups: groups,
        passphrase: 'correct horse',
        // Fewer rounds than the real 600,000, to keep the test quick.
        params: const KdfParams(iterations: 1000),
      );
      // Nothing readable in the file.
      expect(text, isNot(contains(secret)));
      expect(text, isNot(contains('GitHub')));

      await expectLater(Importer.read(text), throwsA(isA<PasswordNeeded>()));
      await expectLater(
        Importer.read(text, password: 'wrong horse'),
        throwsA(isA<WrongPassphrase>()),
      );
      final got = await Importer.read(text, password: 'correct horse');
      expect(got.source, ImportSource.ztBackup);
      expect(
        [for (final a in got.accounts) a.toJson()],
        [for (final a in accounts) a.toJson()],
      );
      expect(got.accounts.first.id, 'a1');
      expect(got.groups.single.name, 'Work');

      // A changed file is refused, not half-read.
      final json = (jsonDecode(text) as Map).cast<String, Object?>();
      final data = base64.decode(json['data'] as String);
      data[data.length - 1] ^= 1;
      json['data'] = base64.encode(data);
      await expectLater(
        Importer.read(jsonEncode(json), password: 'correct horse'),
        throwsA(isA<WrongPassphrase>()),
      );
    },
  );
}
