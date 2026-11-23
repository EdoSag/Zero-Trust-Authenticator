import 'dart:convert';
import 'dart:typed_data';

import 'package:zero_trust_core/zero_trust_core.dart';

import '../model/account.dart';

/// The wrong passphrase, or a file that was changed.
class WrongPassphrase implements Exception {
  const WrongPassphrase();
}

/// ZT Authenticator's own backup file: every account and group, encrypted
/// with a passphrase the user picks, so it can sit in a cloud drive or an
/// email without giving the keys away.
///
/// ```json
/// {"format": "zt-authenticator-backup", "version": 1,
///  "kdf": {"alg": "pbkdf2-sha256", "iter": 600000, "salt": "<base64>"},
///  "data": "<base64 of nonce(12) || ciphertext || tag(16), AES-256-GCM>"}
/// ```
///
/// The plain text inside is `{"accounts": [...], "groups": [...]}`, each
/// entry its `toJson()` plus its `id`.
abstract final class BackupFile {
  static const format = 'zt-authenticator-backup';
  static const version = 1;
  static final _aad = utf8.encode('$format/v$version');

  /// Whether [json] is one of these files.
  static bool isBackup(Object? json) => json is Map && json['format'] == format;

  static Future<String> seal({
    required List<Account> accounts,
    required List<AccountGroup> groups,
    required String passphrase,
    KdfParams params = KdfParams.current,
  }) async {
    final salt = Kdf.newSalt();
    final key = await Kdf.deriveMasterKey(
      password: passphrase,
      salt: salt,
      params: params,
    );
    final plain = jsonEncode({
      'accounts': [
        for (final a in accounts) {'id': a.id, ...a.toJson()},
      ],
      'groups': [
        for (final g in groups) {'id': g.id, ...g.toJson()},
      ],
    });
    final sealed = await SealedBox.seal(utf8.encode(plain), key, aad: _aad);
    key.fillRange(0, key.length, 0);
    return const JsonEncoder.withIndent(' ').convert({
      'format': format,
      'version': version,
      'kdf': {...params.toJson(), 'salt': base64.encode(salt)},
      'data': base64.encode(sealed),
    });
  }

  /// Throws [WrongPassphrase], or [FormatException] for a file this version
  /// cannot read.
  static Future<({List<Account> accounts, List<AccountGroup> groups})> open(
    Map<Object?, Object?> json,
    String passphrase,
  ) async {
    if ((json['version'] as num?)?.toInt() != version) {
      throw const FormatException('Backup from a newer version');
    }
    final KdfParams params;
    final Uint8List salt;
    final Uint8List data;
    try {
      final kdf = (json['kdf'] as Map).cast<String, Object?>();
      params = KdfParams.fromJson(kdf);
      salt = base64.decode(kdf['salt'] as String);
      data = base64.decode(json['data'] as String);
    } on Object {
      throw const FormatException('Damaged backup file');
    }
    final key = await Kdf.deriveMasterKey(
      password: passphrase,
      salt: salt,
      params: params,
    );
    final Uint8List plain;
    try {
      plain = await SealedBox.open(data, key, aad: _aad);
    } on Object {
      throw const WrongPassphrase();
    } finally {
      key.fillRange(0, key.length, 0);
    }
    final inner = (jsonDecode(utf8.decode(plain)) as Map)
        .cast<String, Object?>();
    Map<String, Object?> map(Object? e) => (e as Map).cast<String, Object?>();
    return (
      accounts: [
        for (final e in inner['accounts'] as List? ?? const [])
          Account.fromJson(map(e)['id'] as String? ?? '', map(e)),
      ],
      groups: [
        for (final e in inner['groups'] as List? ?? const [])
          AccountGroup.fromJson(map(e)['id'] as String? ?? '', map(e)),
      ],
    );
  }
}
