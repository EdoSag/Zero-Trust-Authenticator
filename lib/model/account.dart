import '../otp/base32.dart';
import '../otp/otp.dart';

/// One account that asks for a code: its key and how codes are made from
/// it, plus what the user added (group, note, recovery codes, the apps and
/// sites it belongs to).
class Account {
  const Account({
    required this.id,
    required this.secret,
    this.issuer = '',
    this.name = '',
    this.type = OtpType.totp,
    this.algorithm = OtpAlgorithm.sha1,
    this.digits = 6,
    this.period = 30,
    this.counter = 0,
    this.groupId,
    this.note = '',
    this.recoveryCodes = const [],
    this.packages = const [],
    this.domains = const [],
    this.pinned = false,
    this.order = 0,
    this.createdAt,
    this.trashedAt,
  });

  final String id;

  /// The service: "GitHub".
  final String issuer;

  /// Which account there: "edo@example.com".
  final String name;

  /// The key, base32 without spaces, upper case.
  final String secret;
  final OtpType type;
  final OtpAlgorithm algorithm;
  final int digits;

  /// Seconds a time-based code lasts.
  final int period;

  /// HOTP only: the counter the next code is made from.
  final int counter;
  final String? groupId;
  final String note;

  /// The service's one-time recovery codes, kept beside the account.
  final List<String> recoveryCodes;

  /// Android apps the user gave this account's code to (package names).
  final List<String> packages;

  /// Sites the user gave this account's code to ("github.com").
  final List<String> domains;
  final bool pinned;

  /// Position in the list; lower comes first.
  final int order;
  final DateTime? createdAt;

  /// When it was moved to the trash, or null.
  final DateTime? trashedAt;

  bool get trashed => trashedAt != null;
  bool get timeBased => type != OtpType.hotp;

  /// What to call it in a list: the issuer, or the account name when the
  /// issuer was never given.
  String get title => issuer.isNotEmpty ? issuer : name;
  String get subtitle => issuer.isNotEmpty ? name : '';

  /// The code at [now]. For HOTP, the code of the current [counter].
  String codeAt(DateTime now) {
    final key = Base32.decode(secret);
    return switch (type) {
      OtpType.totp => Otp.totp(
        key,
        now,
        period: period,
        digits: digits,
        algorithm: algorithm,
      ),
      OtpType.steam => Otp.steam(key, now),
      OtpType.hotp => Otp.hotp(
        key,
        counter,
        digits: digits,
        algorithm: algorithm,
      ),
    };
  }

  int get _period => type == OtpType.steam ? 30 : period;

  /// When the code shown at [now] stops working; null for HOTP.
  DateTime? validUntil(DateTime now) {
    if (!timeBased) return null;
    final step = Otp.step(now, _period);
    return DateTime.fromMillisecondsSinceEpoch((step + 1) * _period * 1000);
  }

  /// How much of the current period is left, 1 down to 0; 1 for HOTP.
  double remaining(DateTime now) {
    final until = validUntil(now);
    if (until == null) return 1;
    return (until.difference(now).inMilliseconds / (_period * 1000)).clamp(
      0.0,
      1.0,
    );
  }

  Account copyWith({
    String? issuer,
    String? name,
    String? secret,
    OtpType? type,
    OtpAlgorithm? algorithm,
    int? digits,
    int? period,
    int? counter,
    String? Function()? groupId,
    String? note,
    List<String>? recoveryCodes,
    List<String>? packages,
    List<String>? domains,
    bool? pinned,
    int? order,
    DateTime? Function()? trashedAt,
  }) => Account(
    id: id,
    issuer: issuer ?? this.issuer,
    name: name ?? this.name,
    secret: secret ?? this.secret,
    type: type ?? this.type,
    algorithm: algorithm ?? this.algorithm,
    digits: digits ?? this.digits,
    period: period ?? this.period,
    counter: counter ?? this.counter,
    groupId: groupId != null ? groupId() : this.groupId,
    note: note ?? this.note,
    recoveryCodes: recoveryCodes ?? this.recoveryCodes,
    packages: packages ?? this.packages,
    domains: domains ?? this.domains,
    pinned: pinned ?? this.pinned,
    order: order ?? this.order,
    createdAt: createdAt,
    trashedAt: trashedAt != null ? trashedAt() : this.trashedAt,
  );

  /// Every field, with null for a cleared one (see `ZtCollection.encode`).
  Map<String, Object?> toJson() => {
    'issuer': issuer,
    'name': name,
    'secret': secret,
    'type': type.name,
    'algorithm': algorithm.name,
    'digits': digits,
    'period': period,
    'counter': counter,
    'groupId': groupId,
    'note': note,
    'recoveryCodes': recoveryCodes,
    'packages': packages,
    'domains': domains,
    'pinned': pinned,
    'order': order,
    'createdAt': createdAt?.toUtc().toIso8601String(),
    'trashedAt': trashedAt?.toUtc().toIso8601String(),
  };

  static Account fromJson(String id, Map<String, Object?> json) => Account(
    id: id,
    issuer: json['issuer'] as String? ?? '',
    name: json['name'] as String? ?? '',
    secret: json['secret'] as String? ?? '',
    type: OtpType.values.asNameMap()[json['type']] ?? OtpType.totp,
    algorithm:
        OtpAlgorithm.values.asNameMap()[json['algorithm']] ?? OtpAlgorithm.sha1,
    digits: (json['digits'] as num?)?.toInt() ?? 6,
    period: (json['period'] as num?)?.toInt() ?? 30,
    counter: (json['counter'] as num?)?.toInt() ?? 0,
    groupId: json['groupId'] as String?,
    note: json['note'] as String? ?? '',
    recoveryCodes: _strings(json['recoveryCodes']),
    packages: _strings(json['packages']),
    domains: _strings(json['domains']),
    pinned: json['pinned'] == true,
    order: (json['order'] as num?)?.toInt() ?? 0,
    createdAt: _date(json['createdAt']),
    trashedAt: _date(json['trashedAt']),
  );

  static List<String> _strings(Object? v) => v is List
      ? [
          for (final e in v)
            if (e is String) e,
        ]
      : const [];

  static DateTime? _date(Object? v) =>
      v is String ? DateTime.tryParse(v)?.toLocal() : null;
}

/// A named group of accounts ("Work", "Games").
class AccountGroup {
  const AccountGroup({required this.id, required this.name, this.order = 0});

  final String id;
  final String name;
  final int order;

  Map<String, Object?> toJson() => {'name': name, 'order': order};

  static AccountGroup fromJson(String id, Map<String, Object?> json) =>
      AccountGroup(
        id: id,
        name: json['name'] as String? ?? '',
        order: (json['order'] as num?)?.toInt() ?? 0,
      );
}

/// "123 456", "1234 5678": a code split in the middle so it reads easily.
String spacedCode(String code) {
  if (code.length < 6) return code;
  final half = (code.length / 2).ceil();
  return '${code.substring(0, half)} ${code.substring(half)}';
}
