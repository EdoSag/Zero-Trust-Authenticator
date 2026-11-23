import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';
import 'adding.dart';

/// Bringing accounts over from another authenticator app, or from a ZT
/// Authenticator backup file.
class ImportPage extends ConsumerWidget {
  const ImportPage({super.key});

  Future<void> _paste(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.pasteLinks),
        content: TextField(
          key: const Key('paste-links'),
          controller: controller,
          maxLines: 6,
          minLines: 3,
          autofocus: true,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(hintText: l.pasteLinksHint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.cancel),
          ),
          TextButton(
            key: const Key('paste-ok'),
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: Text(l.add),
          ),
        ],
      ),
    );
    if (text == null || text.trim().isEmpty || !context.mounted) return;
    await importText(context, ref, text);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    Widget how(String app, String steps) =>
        ListTile(dense: true, title: Text(app), subtitle: Text(steps));
    return Scaffold(
      appBar: AppBar(title: Text(l.importTitle)),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(l.importIntro),
          ),
          ListTile(
            key: const Key('import-file'),
            leading: const Icon(Icons.folder_open_outlined),
            title: Text(l.importFile),
            subtitle: Text(l.importFileHint),
            onTap: () => pickFileAndImport(context, ref),
          ),
          ListTile(
            key: const Key('import-scan'),
            leading: const Icon(Icons.qr_code_scanner),
            title: Text(l.scanQr),
            subtitle: Text(l.importScanHint),
            onTap: () => scanAndAdd(context, ref),
          ),
          ListTile(
            key: const Key('import-picture'),
            leading: const Icon(Icons.image_outlined),
            title: Text(l.pickPicture),
            subtitle: Text(l.pickPictureHint),
            onTap: () => pickPictureAndAdd(context, ref),
          ),
          ListTile(
            key: const Key('import-paste'),
            leading: const Icon(Icons.content_paste),
            title: Text(l.pasteLinks),
            subtitle: Text(l.pasteLinksSubtitle),
            onTap: () => _paste(context, ref),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(l.howToExport, style: theme.textTheme.titleSmall),
          ),
          how('Google Authenticator', l.howGoogle),
          how('Aegis', l.howAegis),
          how('2FAS', l.howTwoFas),
          how('Ente Auth', l.howEnte),
          how('Bitwarden', l.howBitwarden),
          how('andOTP, FreeOTP+', l.howOthers),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
