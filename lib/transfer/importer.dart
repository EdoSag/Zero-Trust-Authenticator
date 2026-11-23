import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;
import 'package:pointycastle/key_derivators/api.dart' show ScryptParameters;
import 'package:pointycastle/key_derivators/scrypt.dart';
import 'package:zero_trust_core/zero_trust_core.dart';

import '../model/account.dart';
import '../otp/base32.dart';
import '../otp/otp.dart';
import '../otp/otpauth.dart';
import 'backup_file.dart';

/// Where an imported file came from, as worked out from its contents.
enum ImportSource { ztBackup, aegis, twoFas, andOtp, freeOtp, bitwarden, links }

/// The file is encrypted and needs its password (asked for, then
/// [Importer.read] is called again with it).
class PasswordNeeded implements Exception {
  const PasswordNeeded(this.source);
  final ImportSource source;
}

/// A file that is none of the formats [Importer] reads.
class UnknownImport implements Exception {
  const UnknownImport();
}

class ImportedAccounts {
  const ImportedAccounts(this.source, this.accounts, {this.groups = const []});
  final ImportSource source;

  /// Without ids, except from a [ImportSource.ztBackup].
  final List<Account> accounts;
  final List<AccountGroup> groups;
}

/// Reads the export files of other authenticator apps, and this app's own
/// backup. The format is recognised from the contents, so the user never
/// has to say which app a file came from:
///
/// - ZT Authenticator backup (encrypted)
/// - Aegis: plain and password-encrypted vault exports (JSON)
/// - 2FAS: plain and password-protected backups (`.2fas`)
/// - andOTP: plain JSON
/// - FreeOTP+: JSON
/// - Bitwarden: unencrypted JSON export (the items with a code)
/// - Ente Auth, Google Authenticator and anything else that gives
///   `otpauth://` or `otpauth-migration://` links, one per line
abstract final class Importer {
  /// Throws [PasswordNeeded] (call again with [password]),
  /// [WrongPassphrase], [UnknownImport], or [FormatException] for a file of
  /// a known app that cannot be read.
  static Future<ImportedAccounts> read(String text, {String? password}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) throw const UnknownImport();
    Object? json;
    if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      try {
        json = jsonDecode(trimmed);
      } on FormatException {
        json = null;
      }
    }
    if (json == null) return _links(trimmed);

    if (BackupFile.isBackup(json)) {
      if (password == null) throw const PasswordNeeded(ImportSource.ztBackup);
      final opened = await BackupFile.open(json as Map, password);
      return ImportedAccounts(
        ImportSource.ztBackup,
        opened.accounts,
        groups: opened.groups,
      );
    }
    if (json is Map) {
      final map = json.cast<String, Object?>();
      if (map['db'] != null && map['header'] is Map) {
        return _aegis(map, password);
      }
      if (map.containsKey('services') || map.containsKey('servicesEncrypted')) {
        return _twoFas(map, password);
      }
      if (map['tokens'] is List) return _freeOtp(map);
      if (map['items'] is List) return _bitwarden(map);
      if (map['encrypted'] == true) {
        throw const FormatException('Encrypted Bitwarden export');
      }
    }
    if (json is List && json.every((e) => e is Map && e['secret'] != null)) {
      return _andOtp(json);
    }
    throw const UnknownImport();
  }

  static List<Account> _usable(Iterable<Account?> accounts) => [
    for (final a in accounts)
      if (a != null && Base32.isValid(a.secret)) a,
  ];

  static ImportedAccounts _links(String text) {
    final accounts = <Account>[];
    var sawLink = false;
    for (final line in const LineSplitter().convert(text)) {
      if (!OtpAuth.looksLikeLink(line)) continue;
      sawLink = true;
      try {
        accounts.addAll(OtpAuth.parse(line));
      } on FormatException {
        // One bad line doesn't lose the others.
      }
    }
    if (!sawLink) throw const UnknownImport();
    return ImportedAccounts(ImportSource.links, accounts);
  }

  static OtpType _type(Object? value) => switch ('$value'.toLowerCase()) {
    'hotp' => OtpType.hotp,
    'steam' => OtpType.steam,
    _ => OtpType.totp,
  };

  static int _int(Object? value, int fallback) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? fallback;

  // ---- Aegis ----

  static Future<ImportedAccounts> _aegis(
    Map<String, Object?> vault,
    String? password,
  ) async {
    Object? db = vault['db'];
    if (db is String) {
      if (password == null) throw const PasswordNeeded(ImportSource.aegis);
      db = jsonDecode(utf8.decode(await _openAegis(vault, db, password)));
    }
    if (db is! Map) throw const FormatException('Unreadable Aegis file');
    final entries = db['entries'] as List? ?? const [];
    return ImportedAccounts(
      ImportSource.aegis,
      _usable(
        entries.whereType<Map>().map((e) {
          final info = (e['info'] as Map?) ?? const {};
          final type = _type(e['type']);
          return Account(
            id: '',
            issuer: '${e['issuer'] ?? ''}'.trim(),
            name: '${e['name'] ?? ''}'.trim(),
            secret: Base32.normalize('${info['secret'] ?? ''}'),
            type: type,
            algorithm: OtpAlgorithm.parse(info['algo'] as String?),
            digits: type == OtpType.steam ? 5 : _int(info['digits'], 6),
            period: _int(info['period'], 30),
            counter: _int(info['counter'], 0),
            note: '${e['note'] ?? ''}',
            pinned: e['favorite'] == true,
          );
        }),
      ),
    );
  }

  /// An encrypted Aegis vault: a password slot holds the master key, sealed
  /// (AES-256-GCM) with a key made from the password with scrypt; the master
  /// key opens `db` (AES-256-GCM, nonce and tag in `header.params`).
  static Future<Uint8List> _openAegis(
    Map<String, Object?> vault,
    String db,
    String password,
  ) async {
    final header = (vault['header'] as Map).cast<String, Object?>();
    final slots = (header['slots'] as List? ?? const []).whereType<Map>();
    final params = (header['params'] as Map?)?.cast<String, Object?>();
    if (params == null) throw const FormatException('Unreadable Aegis file');
    for (final slot in slots) {
      if (_int(slot['type'], 0) != 1) continue; // 1 = password
      final Uint8List masterKey;
      try {
        final key = await compute(_scrypt, (
          password,
          _hex('${slot['salt']}'),
          _int(slot['n'], 32768),
          _int(slot['r'], 8),
          _int(slot['p'], 1),
        ));
        final keyParams = (slot['key_params'] as Map).cast<String, Object?>();
        masterKey = await SealedBox.open([
          ..._hex('${keyParams['nonce']}'),
          ..._hex('${slot['key']}'),
          ..._hex('${keyParams['tag']}'),
        ], key);
      } on Object {
        continue; // Not this slot's password.
      }
      try {
        return await SealedBox.open([
          ..._hex('${params['nonce']}'),
          ...base64.decode(base64.normalize(db)),
          ..._hex('${params['tag']}'),
        ], masterKey);
      } on Object {
        throw const FormatException('Unreadable Aegis file');
      }
    }
    throw const WrongPassphrase();
  }

  static Uint8List _scrypt((String, Uint8List, int, int, int) a) {
    final (password, salt, n, r, p) = a;
    final scrypt = Scrypt()..init(ScryptParameters(n, r, p, 32, salt));
    return scrypt.process(Uint8List.fromList(utf8.encode(password)));
  }

  static Uint8List _hex(String hex) {
    if (hex.length.isOdd) throw const FormatException('Bad hex');
    return Uint8List.fromList([
      for (var i = 0; i < hex.length; i += 2)
        int.parse(hex.substring(i, i + 2), radix: 16),
    ]);
  }

  // ---- 2FAS ----

  static Future<ImportedAccounts> _twoFas(
    Map<String, Object?> file,
    String? password,
  ) async {
    Object? services = file['services'];
    final encrypted = file['servicesEncrypted'];
    if (encrypted is String && encrypted.isNotEmpty) {
      if (password == null) throw const PasswordNeeded(ImportSource.twoFas);
      // "<data>:<salt>:<iv>", base64 each; PBKDF2-HMAC-SHA256, 10,000
      // rounds; AES-256-GCM with the tag at the end of the data.
      final parts = encrypted.split(':');
      if (parts.length < 3) throw const FormatException('Unreadable 2FAS file');
      final key = await Kdf.deriveMasterKey(
        password: password,
        salt: base64.decode(parts[1]),
        params: const KdfParams(iterations: 10000),
      );
      try {
        final plain = await SealedBox.open([
          ...base64.decode(parts[2]),
          ...base64.decode(parts[0]),
        ], key);
        services = jsonDecode(utf8.decode(plain));
      } on Object {
        throw const WrongPassphrase();
      }
    }
    if (services is! List) throw const FormatException('Unreadable 2FAS file');
    return ImportedAccounts(
      ImportSource.twoFas,
      _usable(
        services.whereType<Map>().map((s) {
          final otp = (s['otp'] as Map?) ?? const {};
          final type = _type(otp['tokenType']);
          final issuer = '${otp['issuer'] ?? s['name'] ?? ''}'.trim();
          return Account(
            id: '',
            issuer: issuer.isEmpty ? '${s['name'] ?? ''}'.trim() : issuer,
            name: '${otp['account'] ?? otp['label'] ?? ''}'.trim(),
            secret: Base32.normalize('${s['secret'] ?? ''}'),
            type: type,
            algorithm: OtpAlgorithm.parse(otp['algorithm'] as String?),
            digits: type == OtpType.steam ? 5 : _int(otp['digits'], 6),
            period: _int(otp['period'], 30),
            counter: _int(otp['counter'], 0),
          );
        }),
      ),
    );
  }

  // ---- andOTP ----

  static ImportedAccounts _andOtp(List<Object?> entries) => ImportedAccounts(
    ImportSource.andOtp,
    _usable(
      entries.whereType<Map>().map((e) {
        var issuer = '${e['issuer'] ?? ''}'.trim();
        var name = '${e['label'] ?? ''}'.trim();
        // Older exports keep "Issuer - name" or "Issuer:name" in the label.
        if (issuer.isEmpty) {
          final cut = RegExp(r'^(.+?)(?: - |:)(.+)$').firstMatch(name);
          if (cut != null) {
            issuer = cut.group(1)!.trim();
            name = cut.group(2)!.trim();
          }
        } else if (name.startsWith('$issuer - ')) {
          name = name.substring(issuer.length + 3);
        } else if (name.startsWith('$issuer:')) {
          name = name.substring(issuer.length + 1).trim();
        }
        final type = _type(e['type']);
        return Account(
          id: '',
          issuer: issuer,
          name: name,
          secret: Base32.normalize('${e['secret'] ?? ''}'),
          type: type,
          algorithm: OtpAlgorithm.parse(e['algorithm'] as String?),
          digits: type == OtpType.steam ? 5 : _int(e['digits'], 6),
          period: _int(e['period'], 30),
          counter: _int(e['counter'], 0),
        );
      }),
    ),
  );

  // ---- FreeOTP+ ----

  static ImportedAccounts _freeOtp(Map<String, Object?> file) =>
      ImportedAccounts(
        ImportSource.freeOtp,
        _usable(
          (file['tokens'] as List).whereType<Map>().map((t) {
            final secret = t['secret'];
            if (secret is! List) return null;
            // The key as a list of signed bytes.
            final bytes = [
              for (final b in secret)
                if (b is num) b.toInt() & 0xff,
            ];
            return Account(
              id: '',
              issuer: '${t['issuerExt'] ?? t['issuerInt'] ?? ''}'.trim(),
              name: '${t['label'] ?? ''}'.trim(),
              secret: Base32.encode(bytes),
              type: _type(t['type']),
              algorithm: OtpAlgorithm.parse(t['algo'] as String?),
              digits: _int(t['digits'], 6),
              period: _int(t['period'], 30),
              counter: _int(t['counter'], 0),
            );
          }),
        ),
      );

  // ---- Bitwarden ----

  static ImportedAccounts _bitwarden(Map<String, Object?> file) {
    final accounts = <Account>[];
    for (final item in (file['items'] as List).whereType<Map>()) {
      final login = item['login'];
      if (login is! Map) continue;
      final totp = '${login['totp'] ?? ''}'.trim();
      if (totp.isEmpty) continue;
      final title = '${item['name'] ?? ''}'.trim();
      final user = '${login['username'] ?? ''}'.trim();
      if (OtpAuth.looksLikeLink(totp)) {
        try {
          for (final a in OtpAuth.parse(totp)) {
            accounts.add(
              a.copyWith(
                issuer: a.issuer.isEmpty || a.type == OtpType.steam
                    ? title
                    : a.issuer,
                name: a.name.isEmpty ? user : a.name,
              ),
            );
          }
        } on FormatException {
          // Skipped.
        }
      } else {
        // Just the key.
        accounts.add(
          Account(
            id: '',
            issuer: title,
            name: user,
            secret: Base32.normalize(totp),
          ),
        );
      }
    }
    return ImportedAccounts(ImportSource.bitwarden, _usable(accounts));
  }
}
