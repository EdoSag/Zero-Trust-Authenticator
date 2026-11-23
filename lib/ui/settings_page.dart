import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zero_trust_core/zero_trust_core.dart';

import '../app/authenticator_settings.dart';
import '../data/accounts_store.dart';
import '../l10n/l10n.dart';
import '../platform/device_bridge.dart';
import 'adding.dart';
import 'common.dart';
import 'import_page.dart';
import 'trash_page.dart';

/// The shared Zero-Trust settings screen, with the Authenticator's own rows.
class AuthenticatorSettingsPage extends ConsumerWidget {
  const AuthenticatorSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ZtSettingsPage(
      showSyncStatus: true,
      onSignedOut: () => Navigator.of(context).popUntil((r) => r.isFirst),
      onOpenUrl: (url) => launchUrl(url, mode: LaunchMode.externalApplication),
      privacyPolicyUrl: Uri.parse('https://zerotrust.bz/privacy'),
      termsUrl: Uri.parse('https://zerotrust.bz/terms'),
      supportUrl: Uri.parse('https://zerotrust.bz/support'),
      // "Export my data": every account as readable files, after a warning
      // and the fingerprint or password. For leaving, not for backups.
      onDataExported: (file, _) => ref
          .read(vaultControllerProvider.notifier)
          .whileShowingSystemUi(
            () => SharePlus.instance.share(
              ShareParams(files: [XFile(file.path)]),
            ),
          ),
      appSection: const [AppSettingsRows()],
      backupSection: const [BackupSettingsRows()],
    );
  }
}

/// The Authenticator's own rows: hide codes, clear the clipboard, codes in
/// other apps (autofill), trash.
class AppSettingsRows extends ConsumerWidget {
  const AppSettingsRows({super.key});

  Future<void> _pickClipboard(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final current = ref.read(authenticatorSettingsProvider).clipboardSeconds;
    final picked = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l.clearClipboard),
        children: [
          for (final s in AuthenticatorSettings.clipboardChoices)
            ListTile(
              leading: Icon(
                s == current
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
              ),
              title: Text(s == 0 ? l.never : l.afterSeconds(s)),
              onTap: () => Navigator.pop(ctx, s),
            ),
        ],
      ),
    );
    if (picked != null) {
      await ref
          .read(authenticatorSettingsProvider.notifier)
          .setClipboardSeconds(picked);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final settings = ref.watch(authenticatorSettingsProvider);
    final trashed = ref.watch(trashedAccountsProvider).length;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SwitchListTile(
          key: const Key('setting-hide-codes'),
          secondary: const Icon(Icons.visibility_off_outlined),
          title: Text(l.hideCodes),
          subtitle: Text(l.hideCodesHint),
          value: settings.hideCodes,
          onChanged: (on) =>
              ref.read(authenticatorSettingsProvider.notifier).setHideCodes(on),
        ),
        ListTile(
          key: const Key('setting-clipboard'),
          leading: const Icon(Icons.content_paste_off_outlined),
          title: Text(l.clearClipboard),
          subtitle: Text(
            settings.clipboardSeconds == 0
                ? l.never
                : l.afterSeconds(settings.clipboardSeconds),
          ),
          onTap: () => _pickClipboard(context, ref),
        ),
        const AutofillSettingRow(),
        ListTile(
          key: const Key('setting-trash'),
          leading: const Icon(Icons.delete_outline),
          title: Text(l.trash),
          subtitle: Text(trashed == 0 ? l.trashEmpty : l.trashCount(trashed)),
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute<void>(builder: (_) => const TrashPage())),
        ),
      ],
    );
  }
}

/// The switch that makes ZT Authenticator the phone's autofill app, so
/// Android offers a code on fields that ask for one. Android owns the
/// choice: turning it on opens Android's screen, and the switch shows what
/// Android says once the app is back in front. Not shown on a phone
/// without autofill.
class AutofillSettingRow extends ConsumerStatefulWidget {
  const AutofillSettingRow({super.key});

  @override
  ConsumerState<AutofillSettingRow> createState() => _AutofillSettingRowState();
}

class _AutofillSettingRowState extends ConsumerState<AutofillSettingRow> {
  AutofillState _state = AutofillState.unsupported;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Back from Android's screen: see what was chosen there.
    _lifecycle = AppLifecycleListener(onResume: _refresh);
    _refresh();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    AutofillState state;
    try {
      state = await ref.read(deviceBridgeProvider).autofillState();
    } on Object {
      state = AutofillState.unsupported;
    }
    if (mounted) setState(() => _state = state);
  }

  Future<void> _set(bool on) async {
    final unavailable = context.l10n.autofillUnavailable;
    try {
      await ref.read(deviceBridgeProvider).setAutofill(on);
    } on Object {
      if (mounted) showSnack(context, unavailable);
    }
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    if (!_state.supported) return const SizedBox.shrink();
    final l = context.l10n;
    return SwitchListTile(
      key: const Key('setting-autofill'),
      secondary: const Icon(Icons.password_outlined),
      title: Text(l.autofillTitle),
      subtitle: Text(_state.enabled ? l.autofillOnHint : l.autofillOffHint),
      value: _state.enabled,
      onChanged: _set,
    );
  }
}

/// The Authenticator's rows under Backup: its own encrypted backup file,
/// and import from other authenticator apps.
class BackupSettingsRows extends ConsumerWidget {
  const BackupSettingsRows({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          key: const Key('setting-export'),
          leading: const Icon(Icons.lock_outline),
          title: Text(l.exportTitle),
          subtitle: Text(l.exportHint),
          onTap: () => exportBackup(context, ref),
        ),
        ListTile(
          key: const Key('setting-import'),
          leading: const Icon(Icons.move_down_outlined),
          title: Text(l.importTitle),
          subtitle: Text(l.importHint),
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute<void>(builder: (_) => const ImportPage())),
        ),
      ],
    );
  }
}
