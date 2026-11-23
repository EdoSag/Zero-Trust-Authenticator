import 'package:flutter_test/flutter_test.dart';
import 'package:zerotrust_authenticator/model/account.dart';
import 'package:zerotrust_authenticator/otp/otp.dart';
import 'package:zerotrust_authenticator/otp/otpauth.dart';

void main() {
  test('a key link as services show it', () {
    final a = OtpAuth.parse(
      'otpauth://totp/GitHub:edo%40example.com'
      '?secret=jbswy3dpehpk3pxp&issuer=GitHub&algorithm=SHA256&digits=8&period=60',
    ).single;
    expect(a.id, '');
    expect(a.issuer, 'GitHub');
    expect(a.name, 'edo@example.com');
    expect(a.secret, 'JBSWY3DPEHPK3PXP');
    expect(a.type, OtpType.totp);
    expect(a.algorithm, OtpAlgorithm.sha256);
    expect(a.digits, 8);
    expect(a.period, 60);
  });

  test('a bare link: no issuer, defaults for the rest', () {
    final a = OtpAuth.parse(
      'otpauth://totp/edo?secret=JBSWY3DPEHPK3PXP',
    ).single;
    expect(a.issuer, '');
    expect(a.name, 'edo');
    expect(a.title, 'edo');
    expect(a.digits, 6);
    expect(a.period, 30);
    expect(a.algorithm, OtpAlgorithm.sha1);
  });

  test('the issuer in the label is used when the link names none', () {
    final a = OtpAuth.parse(
      'otpauth://hotp/Bank%3A%20edo?secret=JBSWY3DPEHPK3PXP&counter=12',
    ).single;
    expect(a.issuer, 'Bank');
    expect(a.name, 'edo');
    expect(a.type, OtpType.hotp);
    expect(a.counter, 12);
  });

  test('Steam, however the exporting app wrote it', () {
    for (final link in [
      'otpauth://steam/Steam:gamer?secret=JBSWY3DPEHPK3PXP',
      'otpauth://totp/Steam:gamer?secret=JBSWY3DPEHPK3PXP&issuer=Steam&digits=5',
      'otpauth://totp/gamer?secret=JBSWY3DPEHPK3PXP&encoder=steam',
      'steam://JBSWY3DPEHPK3PXP',
    ]) {
      final a = OtpAuth.parse(link).single;
      expect(a.type, OtpType.steam, reason: link);
      expect(a.digits == 5 || link.startsWith('steam://'), isTrue);
    }
  });

  test('what is not an account is refused', () {
    for (final text in [
      'https://example.com',
      'otpauth://totp/edo',
      'otpauth://totp/edo?secret=not-a-key!',
      'otpauth://push/edo?secret=JBSWY3DPEHPK3PXP',
      'otpauth-migration://offline?data=%%%',
      'otpauth-migration://offline?data=',
    ]) {
      expect(() => OtpAuth.parse(text), throwsFormatException, reason: text);
    }
    expect(OtpAuth.looksLikeLink(' OTPAUTH://totp/x?secret=A'), isTrue);
    expect(OtpAuth.looksLikeLink('https://example.com'), isFalse);
  });

  test('a link written out is read back the same', () {
    const accounts = [
      Account(
        id: '',
        issuer: 'Git Hub & co',
        name: 'edo@example.com',
        secret: 'JBSWY3DPEHPK3PXP',
        algorithm: OtpAlgorithm.sha512,
        digits: 8,
        period: 45,
      ),
      Account(
        id: '',
        name: 'no issuer',
        secret: 'JBSWY3DPEHPK3PXP',
        type: OtpType.hotp,
        counter: 7,
      ),
      Account(
        id: '',
        issuer: 'Steam',
        name: 'gamer',
        secret: 'JBSWY3DPEHPK3PXP',
        type: OtpType.steam,
        digits: 5,
      ),
    ];
    for (final a in accounts) {
      final back = OtpAuth.parse(OtpAuth.format(a)).single;
      expect(back.toJson(), a.toJson(), reason: OtpAuth.format(a));
    }
  });

  test("Google Authenticator's export code, made by another program", () {
    final accounts = OtpAuth.parse(
      'otpauth-migration://offline?data=CjIKCkhlbGxvId6tvu8SFkdpdEh1YjplZG9AZXhhbXBsZS5jb20aBkdpdEh1YiABKAEwAgorChQxMjM0NTY3ODkwMTIzNDU2Nzg5MBIJYmFuayB1c2VyGgAgAigCMAE4BxABGAEgACjAxAc%3D',
    );
    expect(accounts, hasLength(2));
    final github = accounts[0];
    expect(github.issuer, 'GitHub');
    expect(github.name, 'edo@example.com');
    expect(github.secret, 'JBSWY3DPEHPK3PXP');
    expect(github.type, OtpType.totp);
    expect(github.digits, 6);
    final bank = accounts[1];
    expect(bank.issuer, '');
    expect(bank.name, 'bank user');
    expect(bank.secret, 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ');
    expect(bank.type, OtpType.hotp);
    expect(bank.algorithm, OtpAlgorithm.sha256);
    expect(bank.digits, 8);
    expect(bank.counter, 7);
  });

  test('an export code written here is read back, Steam left out', () {
    const accounts = [
      Account(
        id: '',
        issuer: 'GitHub',
        name: 'edo',
        secret: 'JBSWY3DPEHPK3PXP',
      ),
      Account(
        id: '',
        issuer: 'Bank',
        name: 'me',
        secret: 'GEZDGNBVGY3TQOJQ',
        type: OtpType.hotp,
        algorithm: OtpAlgorithm.sha512,
        digits: 8,
        counter: 300,
      ),
      Account(
        id: '',
        issuer: 'Steam',
        secret: 'JBSWY3DPEHPK3PXP',
        type: OtpType.steam,
      ),
    ];
    final back = OtpAuth.parse(OtpAuth.formatMigration(accounts));
    expect(back, hasLength(2));
    expect(back[0].toJson(), accounts[0].toJson());
    expect(back[1].toJson(), accounts[1].toJson());
  });
}
