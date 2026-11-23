import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:zero_trust_core/zero_trust_core.dart';

import '../model/account.dart';
import '../otp/otp.dart';

/// Accounts and groups are items of the Authenticator app, sealed with its
/// own key (`app = 'authenticator'`): `kind` account and group. No database
/// change.
final accountsCollection = ZtCollection<Account>(
  kind: 'account',
  fromJson: (id, json, _) => Account.fromJson(id, json),
  toJson: (a) => a.toJson(),
  idOf: (a) => a.id,
);

final groupsCollection = ZtCollection<AccountGroup>(
  kind: 'group',
  fromJson: (id, json, _) => AccountGroup.fromJson(id, json),
  toJson: (g) => g.toJson(),
  idOf: (g) => g.id,
);

Stream<List<T>> _watch<T>(Ref ref, ZtCollection<T> c) async* {
  final store = await ref.watch(ztLocalStoreProvider.future);
  if (store is ZtLocalStore) {
    yield* c.watch(store);
  } else {
    yield await c.list(store);
  }
}

/// Pinned first, then the order the user gave, then by name.
int compareAccounts(Account a, Account b) {
  if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
  final byOrder = a.order.compareTo(b.order);
  if (byOrder != 0) return byOrder;
  final byTitle = a.title.toLowerCase().compareTo(b.title.toLowerCase());
  if (byTitle != 0) return byTitle;
  return a.name.toLowerCase().compareTo(b.name.toLowerCase());
}

/// Every account, the trash included, in list order.
final allAccountsProvider = StreamProvider<List<Account>>(
  (ref) =>
      _watch(ref, accountsCollection).map((l) => [...l]..sort(compareAccounts)),
);

/// The accounts shown in the list (not in the trash).
final accountsProvider = Provider<AsyncValue<List<Account>>>(
  (ref) => ref
      .watch(allAccountsProvider)
      .whenData(
        (l) => [
          for (final a in l)
            if (!a.trashed) a,
        ],
      ),
);

final trashedAccountsProvider = Provider<List<Account>>(
  (ref) => [
    for (final a in ref.watch(allAccountsProvider).value ?? const <Account>[])
      if (a.trashed) a,
  ],
);

final groupsProvider = StreamProvider<List<AccountGroup>>(
  (ref) => _watch(ref, groupsCollection).map(
    (l) => [...l]
      ..sort((a, b) {
        final byOrder = a.order.compareTo(b.order);
        return byOrder != 0
            ? byOrder
            : a.name.toLowerCase().compareTo(b.name.toLowerCase());
      }),
  ),
);

/// The time, once a second, for the codes and their countdowns.
final clockProvider = StreamProvider<DateTime>((ref) async* {
  yield DateTime.now();
  yield* Stream<DateTime>.periodic(
    const Duration(seconds: 1),
    (_) => DateTime.now(),
  );
});

/// What an import did.
class AddResult {
  const AddResult({required this.added, required this.alreadyThere});
  final List<Account> added;
  final int alreadyThere;
}

final accountsRepositoryProvider = Provider<AccountsRepository>(
  (ref) => AccountsRepository(ref),
);

/// Saves and deletes through the shared sync controller, so every change is
/// encrypted, stored locally and sent to the account's other devices.
class AccountsRepository {
  AccountsRepository(this._ref);
  final Ref _ref;

  /// How long an account stays in the trash before it is deleted for good.
  static const trashKeeps = Duration(days: 30);

  static const _uuid = Uuid();
  static String newId() => _uuid.v4();

  SyncController get _sync => _ref.read(ztSyncControllerProvider.notifier);
  Future<LocalItemStore> get _store => _ref.read(ztLocalStoreProvider.future);

  Future<List<Account>> allAccounts() async =>
      accountsCollection.list(await _store);

  Future<List<AccountGroup>> allGroups() async =>
      groupsCollection.list(await _store);

  Future<void> save(Account account) async =>
      accountsCollection.save(_sync, await _store, account);

  Future<void> deleteForever(String id) => accountsCollection.delete(_sync, id);

  Future<void> saveGroup(AccountGroup group) async =>
      groupsCollection.save(_sync, await _store, group);

  /// Deletes the group; its accounts stay, ungrouped.
  Future<void> deleteGroup(String id) async {
    for (final a in await allAccounts()) {
      if (a.groupId == id) await save(a.copyWith(groupId: () => null));
    }
    await groupsCollection.delete(_sync, id);
  }

  /// Whether [a] and [b] make the same codes.
  static bool sameKey(Account a, Account b) =>
      a.secret == b.secret &&
      a.type == b.type &&
      a.algorithm == b.algorithm &&
      a.digits == b.digits &&
      (a.type != OtpType.totp || a.period == b.period);

  /// Adds [drafts] (accounts without an id, from a scan, a link or an
  /// import) at the end of the list. One that makes the same codes as an
  /// account already here, the trash included, is skipped.
  Future<AddResult> addAll(List<Account> drafts, {DateTime? now}) async {
    final existing = await allAccounts();
    var order = existing.fold<int>(0, (m, a) => a.order > m ? a.order : m);
    final added = <Account>[];
    var alreadyThere = 0;
    for (final draft in drafts) {
      if ([...existing, ...added].any((a) => sameKey(a, draft))) {
        alreadyThere++;
        continue;
      }
      final account = Account(
        id: newId(),
        issuer: draft.issuer,
        name: draft.name,
        secret: draft.secret,
        type: draft.type,
        algorithm: draft.algorithm,
        digits: draft.digits,
        period: draft.period,
        counter: draft.counter,
        groupId: draft.groupId,
        note: draft.note,
        recoveryCodes: draft.recoveryCodes,
        packages: draft.packages,
        domains: draft.domains,
        pinned: draft.pinned,
        order: ++order,
        createdAt: now ?? DateTime.now(),
        // Only this app's own backup has these: what was in the trash
        // comes back in the trash.
        trashedAt: draft.trashedAt,
      );
      await save(account);
      added.add(account);
    }
    return AddResult(added: added, alreadyThere: alreadyThere);
  }

  Future<void> trash(Account account, {DateTime? now}) =>
      save(account.copyWith(trashedAt: () => now ?? DateTime.now()));

  Future<void> restore(Account account) =>
      save(account.copyWith(trashedAt: () => null));

  /// Deletes what has been in the trash longer than [trashKeeps].
  Future<void> emptyOldTrash({DateTime? now}) async {
    final cutoff = (now ?? DateTime.now()).subtract(trashKeeps);
    for (final a in await allAccounts()) {
      final at = a.trashedAt;
      if (at != null && at.isBefore(cutoff)) await deleteForever(a.id);
    }
  }

  /// HOTP: moves on to the next code and returns the account with it.
  Future<Account> nextCounter(Account account) async {
    final next = account.copyWith(counter: account.counter + 1);
    await save(next);
    return next;
  }

  /// Saves the list in the order of [ids] (within pinned and unpinned).
  Future<void> reorder(List<String> ids) async {
    final byId = {for (final a in await allAccounts()) a.id: a};
    for (var i = 0; i < ids.length; i++) {
      final a = byId[ids[i]];
      if (a != null && a.order != i + 1) await save(a.copyWith(order: i + 1));
    }
  }

  /// Remembers that [account]'s code belongs in the app [package] and on
  /// the site [domain].
  Future<Account> link(
    Account account, {
    String? package,
    String? domain,
  }) async {
    final packages = [
      ...account.packages,
      if (package != null && !account.packages.contains(package)) package,
    ];
    final domains = [
      ...account.domains,
      if (domain != null && !account.domains.contains(domain)) domain,
    ];
    if (packages.length == account.packages.length &&
        domains.length == account.domains.length) {
      return account;
    }
    final next = account.copyWith(packages: packages, domains: domains);
    await save(next);
    return next;
  }
}
