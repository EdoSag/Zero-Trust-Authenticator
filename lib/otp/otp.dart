import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;

/// How an account's codes move on.
enum OtpType {
  /// A new code every period (RFC 6238). Nearly every account.
  totp,

  /// A new code each time one is asked for (RFC 4226).
  hotp,

  /// Steam Guard: time based, five letters and digits.
  steam,
}

enum OtpAlgorithm {
  sha1('SHA1'),
  sha256('SHA256'),
  sha512('SHA512');

  const OtpAlgorithm(this.label);

  /// As written in an `otpauth://` link.
  final String label;

  crypto.Hash get _hash => switch (this) {
    OtpAlgorithm.sha1 => crypto.sha1,
    OtpAlgorithm.sha256 => crypto.sha256,
    OtpAlgorithm.sha512 => crypto.sha512,
  };

  static OtpAlgorithm parse(String? value) =>
      switch ((value ?? '').toUpperCase().replaceAll('-', '')) {
        'SHA256' => OtpAlgorithm.sha256,
        'SHA512' => OtpAlgorithm.sha512,
        _ => OtpAlgorithm.sha1,
      };
}

/// The one-time code maths: HOTP (RFC 4226), TOTP (RFC 6238) and Steam
/// Guard. Pure functions of the key and the counter or time.
abstract final class Otp {
  static const _steamAlphabet = '23456789BCDFGHJKMNPQRTVWXY';

  /// The 31-bit number both code styles are cut from.
  static int _truncated(List<int> key, int counter, OtpAlgorithm algorithm) {
    final message = Uint8List(8);
    var c = counter;
    for (var i = 7; i >= 0; i--) {
      message[i] = c & 0xff;
      c >>= 8;
    }
    final mac = crypto.Hmac(algorithm._hash, key).convert(message).bytes;
    final offset = mac.last & 0x0f;
    return ((mac[offset] & 0x7f) << 24) |
        (mac[offset + 1] << 16) |
        (mac[offset + 2] << 8) |
        mac[offset + 3];
  }

  static String hotp(
    List<int> key,
    int counter, {
    int digits = 6,
    OtpAlgorithm algorithm = OtpAlgorithm.sha1,
  }) {
    var modulo = 1;
    for (var i = 0; i < digits; i++) {
      modulo *= 10;
    }
    return (_truncated(key, counter, algorithm) % modulo).toString().padLeft(
      digits,
      '0',
    );
  }

  /// Which period [time] falls in.
  static int step(DateTime time, int period) =>
      time.millisecondsSinceEpoch ~/ 1000 ~/ period;

  static String totp(
    List<int> key,
    DateTime time, {
    int period = 30,
    int digits = 6,
    OtpAlgorithm algorithm = OtpAlgorithm.sha1,
  }) => hotp(key, step(time, period), digits: digits, algorithm: algorithm);

  static String steam(List<int> key, DateTime time) {
    var n = _truncated(key, step(time, 30), OtpAlgorithm.sha1);
    final out = StringBuffer();
    for (var i = 0; i < 5; i++) {
      out.write(_steamAlphabet[n % _steamAlphabet.length]);
      n ~/= _steamAlphabet.length;
    }
    return out.toString();
  }
}
