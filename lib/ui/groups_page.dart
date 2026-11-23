import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/accounts_store.dart';
import '../l10n/l10n.dart';
import '../model/account.dart';
import 'common.dart';

/// Asks for a group's name: a new one, or [initial] to change. Null when
/// cancelled. A name another group already has is refused.
Future<String?> askGroupName(
  BuildContext context, {
  required List<AccountGroup> groups,
  AccountGroup? rename,
}) => showDialog<String>(
  context: context,
  builder: (_) => _GroupNameDialog(groups: groups, rename: rename),
);

class _GroupNameDialog extends StatefulWidget {
  const _GroupNameDialog({required this.groups, this.rename});

  final List<AccountGroup> groups;
  final AccountGroup? rename;

  @override
  State<_GroupNameDialog> createState() => _GroupNameDialogState();
}

class _GroupNameDialogState extends State<_GroupNameDialog> {
  late final _name = TextEditingController(text: widget.rename?.name);
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _done() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final taken = widget.groups.any(
      (g) =>
          g.id != widget.rename?.id &&
          g.name.toLowerCase() == name.toLowerCase(),
    );
    if (taken) {
      setState(() => _error = context.l10n.groupNameTaken);
      return;
    }
    Navigator.pop(context, name);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(widget.rename == null ? l.newGroup : l.renameGroup),
      content: TextField(
        key: const Key('group-name'),
        controller: _name,
        autofocus: true,
        maxLength: 40,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(labelText: l.groupName, errorText: _error),
        onChanged: (_) {
          if (_error != null) setState(() => _error = null);
        },
        onSubmitted: (_) => _done(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        TextButton(
          key: const Key('group-name-ok'),
          onPressed: _done,
          child: Text(l.save),
        ),
      ],
    );
  }
}

/// Lets the user put [account] in a group, in none, or in a new one.
Future<void> moveAccountToGroup(
  BuildContext context,
  WidgetRef ref,
  Account account,
) async {
  final l = context.l10n;
  final repo = ref.read(accountsRepositoryProvider);
  final groups = ref.read(groupsProvider).value ?? await repo.allGroups();
  if (!context.mounted) return;
  // '' stands for "no group", null for "cancelled".
  const newGroup = '\u0000new';
  final picked = await showDialog<String>(
    context: context,
    builder: (ctx) {
      Widget choice(String key, String value, String title, bool selected) =>
          ListTile(
            key: Key(key),
            leading: Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
            ),
            title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
            onTap: () => Navigator.pop(ctx, value),
          );
      final current = groups.any((g) => g.id == account.groupId)
          ? account.groupId
          : null;
      return SimpleDialog(
        title: Text(l.moveToGroup),
        children: [
          choice('group-none', '', l.noGroup, current == null),
          for (final g in groups)
            choice('group-${g.id}', g.id, g.name, current == g.id),
          ListTile(
            key: const Key('group-new'),
            leading: const Icon(Icons.add),
            title: Text(l.newGroup),
            onTap: () => Navigator.pop(ctx, newGroup),
          ),
        ],
      );
    },
  );
  if (picked == null || !context.mounted) return;
  try {
    if (picked == newGroup) {
      final name = await askGroupName(context, groups: groups);
      if (name == null) return;
      final group = await repo.addGroup(name);
      await repo.moveToGroup(account, group.id);
    } else {
      await repo.moveToGroup(account, picked.isEmpty ? null : picked);
    }
  } on Object {
    if (context.mounted) showSnack(context, l.couldNotSave);
  }
}

/// The groups: add, rename, reorder (drag) and delete. Deleting a group
/// keeps its accounts.
class GroupsPage extends ConsumerWidget {
  const GroupsPage({super.key});

  Future<void> _add(
    BuildContext context,
    WidgetRef ref,
    List<AccountGroup> groups,
  ) async {
    final name = await askGroupName(context, groups: groups);
    if (name == null) return;
    await ref.read(accountsRepositoryProvider).addGroup(name);
  }

  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    List<AccountGroup> groups,
    AccountGroup group,
  ) async {
    final name = await askGroupName(context, groups: groups, rename: group);
    if (name == null || name == group.name) return;
    await ref
        .read(accountsRepositoryProvider)
        .saveGroup(group.copyWith(name: name));
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    AccountGroup group,
  ) async {
    final l = context.l10n;
    final ok = await confirm(
      context,
      title: l.deleteGroupTitle(group.name),
      body: l.deleteGroupBody,
      action: l.deleteGroup,
      destructive: true,
    );
    if (!ok) return;
    await ref.read(accountsRepositoryProvider).deleteGroup(group.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final groups = ref.watch(groupsProvider).value ?? const <AccountGroup>[];
    final accounts = ref.watch(accountsProvider).value ?? const <Account>[];
    int count(AccountGroup g) =>
        accounts.where((a) => a.groupId == g.id).length;

    return Scaffold(
      appBar: AppBar(title: Text(l.groups)),
      body: groups.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(32, 32, 32, 112),
                child: Text(l.groupsEmpty, textAlign: TextAlign.center),
              ),
            )
          : ReorderableListView.builder(
              padding: const EdgeInsets.only(bottom: 96),
              buildDefaultDragHandles: false,
              itemCount: groups.length,
              onReorderItem: (from, to) {
                final ids = [for (final g in groups) g.id];
                final moved = ids.removeAt(from);
                ids.insert(to, moved);
                ref.read(accountsRepositoryProvider).reorderGroups(ids);
              },
              itemBuilder: (context, i) {
                final g = groups[i];
                return ListTile(
                  key: Key('group-row-${g.id}'),
                  leading: ReorderableDragStartListener(
                    index: i,
                    child: const Icon(Icons.drag_handle),
                  ),
                  title: Text(
                    g.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(l.groupAccounts(count(g))),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        key: Key('group-rename-${g.id}'),
                        tooltip: l.renameGroup,
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _rename(context, ref, groups, g),
                      ),
                      IconButton(
                        key: Key('group-delete-${g.id}'),
                        tooltip: l.deleteGroup,
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _delete(context, ref, g),
                      ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('add-group'),
        icon: const Icon(Icons.add),
        label: Text(l.newGroup),
        onPressed: () => _add(context, ref, groups),
      ),
    );
  }
}
