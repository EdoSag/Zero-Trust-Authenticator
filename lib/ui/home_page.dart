import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/incoming_links.dart';
import '../data/accounts_store.dart';
import '../l10n/l10n.dart';
import '../model/account.dart';
import '../otp/otpauth.dart';
import '../platform/device_bridge.dart';
import 'account_tile.dart';
import 'adding.dart';
import 'common.dart';
import 'edit_account_page.dart';
import 'groups_page.dart';
import 'import_page.dart';
import 'settings_page.dart';
import 'show_qr_sheet.dart';

/// The list of accounts with their codes, search, and the ways to add one.
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final _search = TextEditingController();
  bool _searching = false;
  bool _askingAboutLink = false;

  /// The group whose accounts are shown; null shows all.
  String? _groupId;

  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    IncomingLinks.accountLinks.addListener(_offerLinks);
    // The widget's scan button, pressed while the app was in the
    // background. After the frame: if coming back also locked the app,
    // this screen is gone by then and the next one picks it up.
    _lifecycle = AppLifecycleListener(
      onResume: () =>
          WidgetsBinding.instance.addPostFrameCallback((_) => _startAction()),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _offerLinks();
      _startAction();
      ref.read(accountsRepositoryProvider).emptyOldTrash().ignore();
    });
  }

  /// Does what the home screen widget or the launcher shortcut opened the
  /// app for.
  Future<void> _startAction() async {
    if (!mounted) return;
    final String? action;
    try {
      action = await ref.read(deviceBridgeProvider).takeStartAction();
    } on Object {
      return;
    }
    if (action == 'scan' && mounted) await scanAndAdd(context, ref);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    IncomingLinks.accountLinks.removeListener(_offerLinks);
    _search.dispose();
    super.dispose();
  }

  /// An account link opened the app: ask before adding, since any app or
  /// web page can send one.
  Future<void> _offerLinks() async {
    if (_askingAboutLink || !mounted) return;
    _askingAboutLink = true;
    try {
      // Taken again after each batch: a link that arrives while a question
      // is on screen waits its turn instead of being left behind.
      while (mounted) {
        final links = IncomingLinks.takeAccountLinks();
        if (links.isEmpty) break;
        for (final link in links) {
          if (!mounted) return;
          final l = context.l10n;
          final List<Account> accounts;
          try {
            accounts = OtpAuth.parse(link);
          } on FormatException {
            showSnack(context, l.notAccountQr);
            continue;
          }
          final ok = await confirm(
            context,
            title: l.addFromLinkTitle,
            body: accounts.length == 1
                ? l.addFromLinkOne(
                    accounts.single.title.isEmpty
                        ? l.unnamedAccount
                        : accounts.single.title,
                  )
                : l.addFromLinkMany(accounts.length),
            action: l.add,
          );
          if (ok && mounted) await addAccounts(context, ref, accounts);
        }
      }
    } finally {
      _askingAboutLink = false;
    }
  }

  void _openAdd() {
    final l = context.l10n;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      // As tall as its rows need (a sheet is otherwise capped at about half
      // the screen, which cuts the last rows off on a small phone).
      isScrollControlled: true,
      builder: (sheet) {
        Widget option(
          String key,
          IconData icon,
          String title,
          String subtitle,
          VoidCallback action,
        ) => ListTile(
          key: Key(key),
          leading: Icon(icon),
          title: Text(title),
          subtitle: Text(subtitle),
          onTap: () {
            Navigator.pop(sheet);
            action();
          },
        );
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                option(
                  'add-scan',
                  Icons.qr_code_scanner,
                  l.scanQr,
                  l.scanQrHint,
                  () => scanAndAdd(context, ref),
                ),
                option(
                  'add-picture',
                  Icons.image_outlined,
                  l.pickPicture,
                  l.pickPictureHint,
                  () => pickPictureAndAdd(context, ref),
                ),
                option(
                  'add-manual',
                  Icons.keyboard_outlined,
                  l.typeKey,
                  l.typeKeyHint,
                  () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const EditAccountPage(),
                    ),
                  ),
                ),
                option(
                  'add-import',
                  Icons.move_down_outlined,
                  l.importTitle,
                  l.importHint,
                  () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const ImportPage()),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openMenu(Account account) {
    final l = context.l10n;
    final repo = ref.read(accountsRepositoryProvider);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      // As tall as its rows need (a sheet is otherwise capped at about half
      // the screen, which cuts the last rows off on a small phone).
      isScrollControlled: true,
      builder: (sheet) {
        Widget option(
          String key,
          IconData icon,
          String title,
          VoidCallback action,
        ) => ListTile(
          key: Key(key),
          leading: Icon(icon),
          title: Text(title),
          onTap: () {
            Navigator.pop(sheet);
            action();
          },
        );
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: AccountAvatar(account),
                  title: Text(account.title),
                  subtitle: account.subtitle.isEmpty
                      ? null
                      : Text(account.subtitle),
                ),
                const Divider(height: 1),
                option(
                  'menu-edit',
                  Icons.edit_outlined,
                  l.editAccount,
                  () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => EditAccountPage(account: account),
                    ),
                  ),
                ),
                option(
                  'menu-pin',
                  account.pinned ? Icons.push_pin : Icons.push_pin_outlined,
                  account.pinned ? l.unpin : l.pin,
                  () => repo.save(account.copyWith(pinned: !account.pinned)),
                ),
                option(
                  'menu-group',
                  Icons.folder_outlined,
                  l.moveToGroup,
                  () => moveAccountToGroup(context, ref, account),
                ),
                option(
                  'menu-qr',
                  Icons.qr_code_2,
                  l.showQr,
                  () => showAccountQr(context, account),
                ),
                option(
                  'menu-trash',
                  Icons.delete_outline,
                  l.moveToTrash,
                  () async {
                    await repo.trash(account);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        SnackBar(
                          content: Text(l.movedToTrash(account.title)),
                          // With an action a snack bar stays until dismissed
                          // unless it is given a duration.
                          duration: const Duration(seconds: 6),
                          action: SnackBarAction(
                            label: l.undo,
                            onPressed: () => repo.restore(account),
                          ),
                        ),
                      );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final accounts = ref.watch(accountsProvider);
    final groups = ref.watch(groupsProvider).value ?? const <AccountGroup>[];
    final query = _searching ? _search.text.trim().toLowerCase() : '';
    // A group deleted on another device: back to everything.
    final groupId = groups.any((g) => g.id == _groupId) ? _groupId : null;

    final Widget body = accounts.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(l.couldNotLoad, textAlign: TextAlign.center),
        ),
      ),
      data: (all) {
        if (all.isEmpty) return _Empty(onAdd: _openAdd);
        final shown = [
          for (final a in all)
            if ((groupId == null || a.groupId == groupId) &&
                (query.isEmpty ||
                    a.issuer.toLowerCase().contains(query) ||
                    a.name.toLowerCase().contains(query) ||
                    a.note.toLowerCase().contains(query)))
              a,
        ];
        return Column(
          children: [
            if (groups.isNotEmpty)
              _GroupChips(
                groups: groups,
                selected: groupId,
                onSelected: (id) => setState(() => _groupId = id),
              ),
            Expanded(
              child: shown.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(32, 32, 32, 112),
                        child: Text(
                          query.isEmpty && groupId != null
                              ? l.groupEmpty
                              : l.nothingFound,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.only(bottom: 96),
                      itemCount: shown.length,
                      separatorBuilder: (_, _) =>
                          const Divider(height: 1, indent: 72),
                      itemBuilder: (_, i) => AccountTile(
                        key: ValueKey(shown[i].id),
                        account: shown[i],
                        onMenu: () => _openMenu(shown[i]),
                      ),
                    ),
            ),
          ],
        );
      },
    );

    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                key: const Key('search-field'),
                controller: _search,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: l.search,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                ),
                style: theme.textTheme.titleMedium,
                onChanged: (_) => setState(() {}),
              )
            : const Text('ZT Authenticator'),
        actions: [
          IconButton(
            key: const Key('search-toggle'),
            tooltip: _searching ? l.closeSearch : l.search,
            icon: Icon(_searching ? Icons.close : Icons.search),
            onPressed: () => setState(() {
              _searching = !_searching;
              _search.clear();
            }),
          ),
          IconButton(
            key: const Key('open-settings'),
            tooltip: l.settings,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const AuthenticatorSettingsPage(),
              ),
            ),
          ),
        ],
      ),
      body: body,
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('add-account'),
        icon: const Icon(Icons.add),
        label: Text(l.addAccount),
        onPressed: _openAdd,
      ),
    );
  }
}

/// "All" and one chip per group, in a row that scrolls sideways, with the
/// way to the groups screen at its end.
class _GroupChips extends StatelessWidget {
  const _GroupChips({
    required this.groups,
    required this.selected,
    required this.onSelected,
  });

  final List<AccountGroup> groups;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    Widget chip(String key, String label, String? id) => Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: ChoiceChip(
        key: Key(key),
        label: Text(label),
        selected: selected == id,
        onSelected: (_) => onSelected(id),
      ),
    );
    return SizedBox(
      height: 56,
      child: ListView(
        key: const Key('group-chips'),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          chip('chip-all', l.allAccounts, null),
          for (final g in groups) chip('chip-${g.id}', g.name, g.id),
          IconButton(
            key: const Key('edit-groups'),
            tooltip: l.editGroups,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute<void>(builder: (_) => const GroupsPage())),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(32, 32, 32, 112),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.pin_outlined,
              size: 64,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              l.emptyTitle,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(l.emptyBody, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
