import 'dart:convert';
import 'dart:typed_data';

import '../model/account.dart';
import 'base32.dart';
import 'otp.dart';

/// Reads and writes the links and QR code contents accounts travel in:
///
/// - `otpauth://totp/Issuer:name?secret=…` (the "key URI" every service
///   shows as a QR code), also `otpauth://hotp/…` and Aegis' `steam`.
/// - `otpauth-migration://offline?data=…`, Google Authenticator's export QR
///   codes, each holding several accounts.
///
/// Parsed accounts have an empty id; the store gives them one.
abstract final class OtpAuth {
  /// Whether [text] looks like something [parse] understands.
  static bool looksLikeLink(String text) {
    final t = text.trim().toLowerCase();
    return t.startsWith('otpauth://') ||
        t.startsWith('otpauth-migration://') ||
        t.startsWith('steam://');
  }

  /// Every account in [text]: one for a key link, several for a Google
  /// Authenticator export. Throws [FormatException] when it is neither or
  /// holds no usable key.
  static List<Account> parse(String text) {
    final t = text.trim();
    final lower = t.toLowerCase();
    if (lower.startsWith('otpauth-migration://')) return _parseMigration(t);
    if (lower.startsWith('steam://')) {
      final secret = Base32.normalize(t.substring('steam://'.length));
      if (!Base32.isValid(secret)) throw const FormatException('No key');
      return [
        Account(id: '', issuer: 'Steam', secret: secret, type: OtpType.steam),
      ];
    }
    if (lower.startsWith('otpauth://')) return [_parseKeyUri(t)];
    throw const FormatException('Not an account link');
  }

  static Account _parseKeyUri(String text) {
    final Uri uri;
    try {
      uri = Uri.parse(text);
    } on FormatException {
      throw const FormatException('Not an account link');
    }
    final kind = uri.host.toLowerCase();
    if (!const {'totp', 'hotp', 'steam'}.contains(kind)) {
      throw const FormatException('Unknown kind of code');
    }
    final q = uri.queryParameters;
    final secret = Base32.normalize(q['secret'] ?? '');
    if (!Base32.isValid(secret)) throw const FormatException('No key');

    var label = uri.pathSegments.join('/').trim();
    var issuer = (q['issuer'] ?? '').trim();
    var name = label;
    final colon = label.indexOf(':');
    if (colon >= 0) {
      final prefix = label.substring(0, colon).trim();
      name = label.substring(colon + 1).trim();
      if (issuer.isEmpty) issuer = prefix;
    }

    final isSteam =
        kind == 'steam' ||
        (q['encoder'] ?? '').toLowerCase() == 'steam' ||
        (issuer.toLowerCase() == 'steam' && q['digits'] == '5');
    final type = isSteam
        ? OtpType.steam
        : (kind == 'hotp' ? OtpType.hotp : OtpType.totp);
    final digits = int.tryParse(q['digits'] ?? '') ?? 6;
    final period = int.tryParse(q['period'] ?? '') ?? 30;
    return Account(
      id: '',
      issuer: issuer,
      name: name,
      secret: secret,
      type: type,
      algorithm: OtpAlgorithm.parse(q['algorithm']),
      digits: isSteam ? 5 : (digits >= 4 && digits <= 10 ? digits : 6),
      period: period > 0 && period <= 86400 ? period : 30,
      counter: int.tryParse(q['counter'] ?? '') ?? 0,
    );
  }

  /// The key link for [account], as other authenticator apps read it.
  static String format(Account account) {
    final label = account.issuer.isEmpty
        ? Uri.encodeComponent(account.name)
        : '${Uri.encodeComponent(account.issuer)}:'
              '${Uri.encodeComponent(account.name)}';
    final params = <String, String>{
      'secret': account.secret,
      if (account.issuer.isNotEmpty) 'issuer': account.issuer,
      if (account.type != OtpType.steam) ...{
        'algorithm': account.algorithm.label,
        'digits': '${account.digits}',
      },
      if (account.type == OtpType.totp) 'period': '${account.period}',
      if (account.type == OtpType.hotp) 'counter': '${account.counter}',
    };
    final query = params.entries
        .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    final kind = switch (account.type) {
      OtpType.totp => 'totp',
      OtpType.hotp => 'hotp',
      OtpType.steam => 'steam',
    };
    return 'otpauth://$kind/$label?$query';
  }

  // Google Authenticator's export: a protobuf `MigrationPayload`, base64 in
  // the `data` parameter.
  //
  //   message MigrationPayload { repeated OtpParameters otp_parameters = 1; … }
  //   message OtpParameters {
  //     bytes secret = 1; string name = 2; string issuer = 3;
  //     Algorithm algorithm = 4;  // 1 SHA1, 2 SHA256, 3 SHA512
  //     DigitCount digits = 5;    // 1 six, 2 eight
  //     OtpType type = 6;         // 1 HOTP, 2 TOTP
  //     int64 counter = 7;
  //   }
  static List<Account> _parseMigration(String text) {
    final Uint8List data;
    try {
      final raw = Uri.parse(text).queryParameters['data'] ?? '';
      data = base64.decode(base64.normalize(raw.replaceAll(' ', '+')));
    } on FormatException {
      throw const FormatException('Unreadable export code');
    }
    final accounts = <Account>[];
    for (final field in _ProtoReader(data).fields()) {
      if (field.number != 1 || field.bytes == null) continue;
      Uint8List? secret;
      var name = '';
      var issuer = '';
      var algorithm = OtpAlgorithm.sha1;
      var digits = 6;
      var type = OtpType.totp;
      var counter = 0;
      for (final f in _ProtoReader(field.bytes!).fields()) {
        switch (f.number) {
          case 1:
            secret = f.bytes;
          case 2:
            name = utf8.decode(f.bytes ?? const [], allowMalformed: true);
          case 3:
            issuer = utf8.decode(f.bytes ?? const [], allowMalformed: true);
          case 4:
            algorithm = switch (f.varint) {
              2 => OtpAlgorithm.sha256,
              3 => OtpAlgorithm.sha512,
              _ => OtpAlgorithm.sha1,
            };
          case 5:
            digits = f.varint == 2 ? 8 : 6;
          case 6:
            type = f.varint == 1 ? OtpType.hotp : OtpType.totp;
          case 7:
            counter = f.varint ?? 0;
        }
      }
      if (secret == null || secret.isEmpty) continue;
      // Google writes "Issuer:name" into the name as well.
      final colon = name.indexOf(':');
      if (colon >= 0) {
        if (issuer.isEmpty) issuer = name.substring(0, colon).trim();
        name = name.substring(colon + 1).trim();
      }
      accounts.add(
        Account(
          id: '',
          issuer: issuer.trim(),
          name: name.trim(),
          secret: Base32.encode(secret),
          type: type,
          algorithm: algorithm,
          digits: digits,
          counter: counter,
        ),
      );
    }
    if (accounts.isEmpty) throw const FormatException('No accounts inside');
    return accounts;
  }

  /// A Google Authenticator export link holding [accounts] (Steam accounts
  /// are left out: that app cannot hold them).
  static String formatMigration(List<Account> accounts) {
    final payload = _ProtoWriter();
    for (final a in accounts) {
      if (a.type == OtpType.steam) continue;
      final p = _ProtoWriter()
        ..bytes(1, Base32.decode(a.secret))
        ..bytes(2, utf8.encode(a.name))
        ..bytes(3, utf8.encode(a.issuer))
        ..varint(4, switch (a.algorithm) {
          OtpAlgorithm.sha1 => 1,
          OtpAlgorithm.sha256 => 2,
          OtpAlgorithm.sha512 => 3,
        })
        ..varint(5, a.digits == 8 ? 2 : 1)
        ..varint(6, a.type == OtpType.hotp ? 1 : 2);
      if (a.type == OtpType.hotp) p.varint(7, a.counter);
      payload.bytes(1, p.done());
    }
    payload
      ..varint(2, 1)
      ..varint(3, 1)
      ..varint(4, 0);
    return 'otpauth-migration://offline?data='
        '${Uri.encodeQueryComponent(base64.encode(payload.done()))}';
  }
}

class _ProtoField {
  const _ProtoField(this.number, {this.varint, this.bytes});
  final int number;
  final int? varint;
  final Uint8List? bytes;
}

/// Just enough protobuf to read the export: varints and length-delimited
/// fields; fixed-width fields are skipped.
class _ProtoReader {
  _ProtoReader(this._data);
  final Uint8List _data;
  var _at = 0;

  int _varint() {
    var result = 0;
    var shift = 0;
    while (true) {
      if (_at >= _data.length || shift > 63) {
        throw const FormatException('Unreadable export code');
      }
      final b = _data[_at++];
      result |= (b & 0x7f) << shift;
      if (b & 0x80 == 0) return result;
      shift += 7;
    }
  }

  List<_ProtoField> fields() {
    final out = <_ProtoField>[];
    while (_at < _data.length) {
      final tag = _varint();
      final number = tag >> 3;
      switch (tag & 7) {
        case 0:
          out.add(_ProtoField(number, varint: _varint()));
        case 2:
          final length = _varint();
          if (length < 0 || _at + length > _data.length) {
            throw const FormatException('Unreadable export code');
          }
          out.add(
            _ProtoField(
              number,
              bytes: Uint8List.sublistView(_data, _at, _at + length),
            ),
          );
          _at += length;
        case 1:
          _at += 8;
        case 5:
          _at += 4;
        default:
          throw const FormatException('Unreadable export code');
      }
    }
    return out;
  }
}

class _ProtoWriter {
  final _out = BytesBuilder();

  void _raw(int value) {
    var v = value;
    while (v > 0x7f) {
      _out.addByte((v & 0x7f) | 0x80);
      v >>= 7;
    }
    _out.addByte(v);
  }

  void varint(int field, int value) {
    _raw(field << 3);
    _raw(value);
  }

  void bytes(int field, List<int> value) {
    _raw((field << 3) | 2);
    _raw(value.length);
    _out.add(value);
  }

  Uint8List done() => _out.toBytes();
}
