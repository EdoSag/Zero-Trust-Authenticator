import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_authenticator/app/authenticator_config.dart';
import 'package:zerotrust_authenticator/data/accounts_store.dart';
import 'package:zerotrust_authenticator/l10n/l10n.dart';
import 'package:zerotrust_authenticator/links/code_matcher.dart';
import 'package:zerotrust_authenticator/model/account.dart';
import 'package:zerotrust_authenticator/platform/device_bridge.dart';
import 'package:zerotrust_authenticator/platform/files.dart';
import 'package:zerotrust_authenticator/transfer/backup_file.dart';

/// The moment the tests' clock shows: 10 seconds before a 30 second code
/// runs out.
final testNow = DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000);

/// The key every example uses ("Hello!" and four more bytes); its code at
/// [testNow] is 324550.
const testSecret = 'JBSWY3DPEHPK3PXP';

/// Keeps everything in memory, in place of the encrypted store.
class MemoryRepository extends AccountsRepository {
  MemoryRepository(super.ref, {List<Account> accounts = const []}) {
    for (final a in accounts) {
      _accounts[a.id] = a;
    }
  }

  final _accounts = <String, Account>{};
  final _groups = <String, AccountGroup>{};
  final _changes = StreamController<void>.broadcast();

  List<Account> get accounts => _accounts.values.toList();
  List<AccountGroup> get groups => _groups.values.toList();
  Account account(String id) => _accounts[id]!;

  Stream<List<T>> _watch<T>(List<T> Function() read) async* {
    yield read();
    yield* _changes.stream.map((_) => read());
  }

  Stream<List<Account>> watchAccounts() =>
      _watch(() => accounts..sort(compareAccounts));
  Stream<List<AccountGroup>> watchGroups() => _watch(() => groups);

  @override
  Future<List<Account>> allAccounts() async => accounts;
  @override
  Future<List<AccountGroup>> allGroups() async => groups;

  @override
  Future<void> save(Account account) async {
    _accounts[account.id] = account;
    _changes.add(null);
  }

  @override
  Future<void> deleteForever(String id) async {
    _accounts.remove(id);
    _changes.add(null);
  }

  @override
  Future<void> saveGroup(AccountGroup group) async {
    _groups[group.id] = group;
    _changes.add(null);
  }

  @override
  Future<void> deleteGroup(String id) async {
    _groups.remove(id);
    _changes.add(null);
  }
}

/// Stands in for the Kotlin side: remembers what was copied and what was
/// handed back to the keyboard.
class FakeBridge implements DeviceBridge {
  FakeBridge({this.request});

  CodeRequest? request;
  final copied = <(String, Duration?)>[];

  /// Every answer: the code (null when declined) and when it runs out.
  final answers = <(String?, DateTime?)>[];

  @override
  Future<CodeRequest?> pendingCodeRequest() async => request;

  @override
  Future<void> answerCodeRequest(String? code, {DateTime? validUntil}) async {
    request = null;
    answers.add((code, validUntil));
  }

  @override
  Future<void> copyPrivately(String text, {Duration? clearAfter}) async {
    copied.add((text, clearAfter));
  }

  /// What the phone says about autofill; a test changes it to stand in
  /// for the user's choice on Android's own screen.
  AutofillState autofill = AutofillState.unsupported;

  /// Every `setAutofill` call.
  final autofillAsked = <bool>[];

  /// Makes `setAutofill` fail, as on a phone without the settings screen.
  bool autofillFails = false;

  @override
  Future<AutofillState> autofillState() async => autofill;

  @override
  Future<void> setAutofill(bool on) async {
    if (autofillFails) throw PlatformException(code: 'unavailable');
    autofillAsked.add(on);
    if (!on) autofill = const AutofillState(supported: true, enabled: false);
  }
}

/// Stands in for the system's file screens.
class FakeFiles implements Files {
  (String, Uint8List)? toPick;
  final saved = <(String, Uint8List)>[];

  @override
  Future<(String, Uint8List)?> pick({bool image = false}) async => toPick;

  @override
  Future<bool> save({
    required String name,
    required String mimeType,
    required Uint8List bytes,
  }) async {
    saved.add((name, bytes));
    return true;
  }
}

late MemoryRepository repo;
late FakeBridge bridge;
late FakeFiles files;

Widget app(
  Widget home, {
  List<Account> accounts = const [],
  Locale locale = ZtLanguages.english,
  CodeRequest? request,
  PreferencesStore? prefs,
}) {
  bridge = FakeBridge(request: request);
  files = FakeFiles();
  return ProviderScope(
    overrides: [
      ztAppConfigProvider.overrideWithValue(authenticatorAppConfig),
      ztPreferencesStoreProvider.overrideWithValue(
        prefs ?? InMemoryPreferencesStore(),
      ),
      deviceBridgeProvider.overrideWithValue(bridge),
      filesProvider.overrideWithValue(files),
      clockProvider.overrideWith((ref) => Stream.value(testNow)),
      accountsRepositoryProvider.overrideWith(
        (ref) => repo = MemoryRepository(ref, accounts: accounts),
      ),
      allAccountsProvider.overrideWith(
        (ref) => (ref.watch(accountsRepositoryProvider) as MemoryRepository)
            .watchAccounts(),
      ),
      groupsProvider.overrideWith(
        (ref) => (ref.watch(accountsRepositoryProvider) as MemoryRepository)
            .watchGroups(),
      ),
    ],
    child: MaterialApp(
      // The suite's real theme: its full-width buttons break rows that a
      // plain theme lets through.
      theme: ZtTheme.light(accent: authenticatorAppConfig.accent),
      locale: locale,
      supportedLocales: ZtLanguages.supported,
      localizationsDelegates: const [
        AppL10n.delegate,
        ...ZtLanguages.delegates,
      ],
      // Makes the repository right away, so `repo` is this test's own from
      // the first frame.
      home: Consumer(
        builder: (context, ref, _) {
          ref.watch(accountsRepositoryProvider);
          return home;
        },
      ),
    ),
  );
}

/// A small real backup file, with few key rounds so tests stay quick.
abstract final class BackupFileForTest {
  static Future<String> make(List<Account> accounts) => BackupFile.seal(
    accounts: accounts,
    groups: const [],
    passphrase: 'backup-pass',
    params: const KdfParams(iterations: 1000),
  );
}
