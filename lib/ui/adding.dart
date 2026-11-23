import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/accounts_store.dart';
import '../l10n/l10n.dart';
import '../model/account.dart';
import '../otp/otpauth.dart';
import '../platform/files.dart';
import '../transfer/backup_file.dart';
import '../transfer/importer.dart';
import 'common.dart';
import 'scan_page.dart';

/// Adds [drafts] (from a scan, a link or a file) and says what happened.
Future<void> addAccounts(
  BuildContext context,
  WidgetRef ref,
  List<Account> drafts, {
  List<AccountGroup> groups = const [],
}) async {
  final l = context.l10n;
  final repo = ref.read(accountsRepositoryProvider);
  final AddResult result;
  try {
    // A backup brings its groups; one already here keeps its name.
    final existing = {for (final g in await repo.allGroups()) g.id};
    for (final g in groups) {
      if (g.id.isNotEmpty && !existing.contains(g.id)) await repo.saveGroup(g);
    }
    result = await repo.addAll(drafts);
  } on Object {
    if (context.mounted) showSnack(context, l.couldNotSave);
    return;
  }
  if (!context.mounted) return;
  final added = result.added;
  final String message;
  if (added.isEmpty) {
    message = result.alreadyThere > 0 ? l.alreadyHere : l.nothingToAdd;
  } else if (added.length == 1 && result.alreadyThere == 0) {
    message = l.addedOne(added.single.title);
  } else if (result.alreadyThere == 0) {
    message = l.addedMany(added.length);
  } else {
    message = l.addedSomeSkipped(added.length, result.alreadyThere);
  }
  showSnack(context, message);
}

/// Scans a QR code with the camera and adds what is in it.
Future<void> scanAndAdd(BuildContext context, WidgetRef ref) async {
  final accounts = await Navigator.of(
    context,
  ).push<List<Account>>(MaterialPageRoute(builder: (_) => const ScanPage()));
  if (accounts == null || !context.mounted) return;
  await addAccounts(context, ref, accounts);
}

/// Reads the QR code in a picked picture and adds what is in it.
Future<void> pickPictureAndAdd(BuildContext context, WidgetRef ref) async {
  final l = context.l10n;
  final picked = await ref.read(filesProvider).pick(image: true);
  if (picked == null || !context.mounted) return;
  final text = await readQrFromImage(picked.$2);
  if (!context.mounted) return;
  if (text == null) {
    showSnack(context, l.noQrInPicture);
    return;
  }
  await addFromLink(context, ref, text);
}

/// Adds the account(s) in an `otpauth://` link or a Google Authenticator
/// export link.
Future<void> addFromLink(
  BuildContext context,
  WidgetRef ref,
  String link,
) async {
  final List<Account> accounts;
  try {
    accounts = OtpAuth.parse(link);
  } on FormatException {
    showSnack(context, context.l10n.notAccountQr);
    return;
  }
  await addAccounts(context, ref, accounts);
}

/// Picks a backup or export file of any supported app and adds what is in
/// it, asking for the file's password when it has one.
Future<void> pickFileAndImport(BuildContext context, WidgetRef ref) async {
  final picked = await ref.read(filesProvider).pick();
  if (picked == null || !context.mounted) return;
  await importText(context, ref, utf8.decode(picked.$2, allowMalformed: true));
}

/// Adds what is in [text]: a file's contents or pasted links.
Future<void> importText(
  BuildContext context,
  WidgetRef ref,
  String text,
) async {
  final l = context.l10n;
  String? password;
  while (true) {
    try {
      final imported = await Importer.read(text, password: password);
      if (!context.mounted) return;
      await addAccounts(
        context,
        ref,
        imported.accounts,
        groups: imported.groups,
      );
      return;
    } on PasswordNeeded {
      if (!context.mounted) return;
      password = await askPassword(
        context,
        title: l.filePasswordTitle,
        message: l.filePasswordBody,
      );
      if (password == null) return;
    } on WrongPassphrase {
      if (!context.mounted) return;
      password = await askPassword(
        context,
        title: l.filePasswordTitle,
        message: l.filePasswordBody,
        error: l.wrongPassword,
      );
      if (password == null) return;
    } on UnknownImport {
      if (context.mounted) showSnack(context, l.unknownFile);
      return;
    } on Object {
      if (context.mounted) showSnack(context, l.unreadableFile);
      return;
    }
  }
}

/// Asks for a password. Null when cancelled.
Future<String?> askPassword(
  BuildContext context, {
  required String title,
  required String message,
  String? error,
  bool confirm = false,
}) => showDialog<String>(
  context: context,
  builder: (_) => _PasswordDialog(
    title: title,
    message: message,
    error: error,
    confirm: confirm,
  ),
);

class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog({
    required this.title,
    required this.message,
    this.error,
    required this.confirm,
  });

  final String title;
  final String message;
  final String? error;

  /// A new password: typed twice, at least 8 characters.
  final bool confirm;

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _again = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    _again.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    Navigator.pop(context, _password.text);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.message),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('password'),
              controller: _password,
              obscureText: true,
              autofocus: true,
              decoration: InputDecoration(
                labelText: l.password,
                errorText: widget.error,
              ),
              validator: (v) {
                if ((v ?? '').isEmpty) return l.passwordRequired;
                if (widget.confirm && v!.length < 8) return l.passwordTooShort;
                return null;
              },
              onFieldSubmitted: widget.confirm ? null : (_) => _submit(),
            ),
            if (widget.confirm) ...[
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('password-again'),
                controller: _again,
                obscureText: true,
                decoration: InputDecoration(labelText: l.passwordAgain),
                validator: (v) =>
                    v == _password.text ? null : l.passwordsDiffer,
                onFieldSubmitted: (_) => _submit(),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        TextButton(
          key: const Key('password-ok'),
          onPressed: _submit,
          child: Text(l.continueLabel),
        ),
      ],
    );
  }
}

/// Saves every account and group as one encrypted backup file.
Future<void> exportBackup(BuildContext context, WidgetRef ref) async {
  final l = context.l10n;
  final repo = ref.read(accountsRepositoryProvider);
  final passphrase = await askPassword(
    context,
    title: l.exportTitle,
    message: l.exportBody,
    confirm: true,
  );
  if (passphrase == null || !context.mounted) return;
  try {
    final accounts = await repo.allAccounts();
    final text = await BackupFile.seal(
      accounts: [...accounts]..sort(compareAccounts),
      groups: await repo.allGroups(),
      passphrase: passphrase,
    );
    final day = DateTime.now().toIso8601String().substring(0, 10);
    final saved = await ref
        .read(filesProvider)
        .save(
          name: 'zt-authenticator-$day.ztauth',
          mimeType: 'application/json',
          bytes: utf8.encode(text),
        );
    if (saved && context.mounted) showSnack(context, l.exportDone);
  } on Object {
    if (context.mounted) showSnack(context, l.exportFailed);
  }
}
