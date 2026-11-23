import 'dart:typed_data';

/// RFC 4648 base32, as account keys are written ("JBSW Y3DP EHPK 3PXP").
abstract final class Base32 {
  static const _alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

  /// The key as typed or scanned, without spaces, dashes or padding, in
  /// upper case. Not checked: see [isValid].
  static String normalize(String input) =>
      input.replaceAll(RegExp(r'[\s\-=]'), '').toUpperCase();

  /// Whether [input] is a key that can make codes: base32 with at least one
  /// whole byte.
  static bool isValid(String input) {
    final s = normalize(input);
    return s.length >= 2 && RegExp(r'^[A-Z2-7]+$').hasMatch(s);
  }

  /// Throws [FormatException] on anything that is not base32.
  static Uint8List decode(String input) {
    final s = normalize(input);
    final out = BytesBuilder();
    var buffer = 0;
    var bits = 0;
    for (final unit in s.codeUnits) {
      final value = _alphabet.indexOf(String.fromCharCode(unit));
      if (value < 0) throw const FormatException('Not a base32 key');
      buffer = (buffer << 5) | value;
      bits += 5;
      if (bits >= 8) {
        bits -= 8;
        out.addByte((buffer >> bits) & 0xff);
        buffer &= (1 << bits) - 1;
      }
    }
    return out.toBytes();
  }

  static String encode(List<int> bytes) {
    final out = StringBuffer();
    var buffer = 0;
    var bits = 0;
    for (final byte in bytes) {
      buffer = (buffer << 8) | (byte & 0xff);
      bits += 8;
      while (bits >= 5) {
        bits -= 5;
        out.write(_alphabet[(buffer >> bits) & 31]);
        buffer &= (1 << bits) - 1;
      }
    }
    if (bits > 0) out.write(_alphabet[(buffer << (5 - bits)) & 31]);
    return out.toString();
  }
}
