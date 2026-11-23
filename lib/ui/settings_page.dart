import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zero_trust_core/zero_trust_core.dart';

import '../app/authenticator_settings.dart';
import '../data/accounts_store.dart';
import '../l10n/l10n.dart';
import 'adding.dart';
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

/// The Authenticator's own rows: hide codes, clear the clipboard, trash.
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
