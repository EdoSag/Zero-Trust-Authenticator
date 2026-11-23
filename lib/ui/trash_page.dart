import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/accounts_store.dart';
import '../l10n/l10n.dart';
import '../model/account.dart';
import 'common.dart';

/// Accounts moved to the trash: put back, or deleted for good. Each is
/// deleted on its own after 30 days.
class TrashPage extends ConsumerWidget {
  const TrashPage({super.key});

  Future<void> _delete(BuildContext context, WidgetRef ref, Account a) async {
    final l = context.l10n;
    final ok = await confirm(
      context,
      title: l.deleteForeverTitle(a.title),
      body: l.deleteForeverBody,
      action: l.deleteForever,
      destructive: true,
    );
    if (!ok) return;
    await ref.read(accountsRepositoryProvider).deleteForever(a.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final trashed = ref.watch(trashedAccountsProvider);
    final now = DateTime.now();
    return Scaffold(
      appBar: AppBar(title: Text(l.trash)),
      body: trashed.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(l.trashEmpty, textAlign: TextAlign.center),
              ),
            )
          : ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(l.trashHint),
                ),
                for (final a in trashed)
                  ListTile(
                    key: Key('trashed-${a.id}'),
                    leading: AccountAvatar(a),
                    title: Text(a.title),
                    subtitle: Text(
                      [
                        if (a.subtitle.isNotEmpty) a.subtitle,
                        l.daysLeft(
                          (AccountsRepository.trashKeeps.inDays -
                                  now.difference(a.trashedAt!).inDays)
                              .clamp(0, AccountsRepository.trashKeeps.inDays),
                        ),
                      ].join(' · '),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: l.restore,
                          icon: const Icon(Icons.restore_from_trash_outlined),
                          onPressed: () =>
                              ref.read(accountsRepositoryProvider).restore(a),
                        ),
                        IconButton(
                          tooltip: l.deleteForever,
                          icon: const Icon(Icons.delete_forever_outlined),
                          onPressed: () => _delete(context, ref, a),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}
