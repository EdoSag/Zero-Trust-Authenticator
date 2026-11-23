import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/accounts_store.dart';
import '../l10n/l10n.dart';
import '../model/account.dart';
import '../otp/base32.dart';
import '../otp/otp.dart';
import 'common.dart';

/// Typing an account in by hand ([account] null), or changing one. The key
/// can only be typed for a new account; an existing one keeps its key.
class EditAccountPage extends ConsumerStatefulWidget {
  const EditAccountPage({super.key, this.account});

  final Account? account;

  @override
  ConsumerState<EditAccountPage> createState() => _EditAccountPageState();
}

class _EditAccountPageState extends ConsumerState<EditAccountPage> {
  final _form = GlobalKey<FormState>();
  late final _issuer = TextEditingController(text: widget.account?.issuer);
  late final _name = TextEditingController(text: widget.account?.name);
  final _secret = TextEditingController();
  late final _note = TextEditingController(text: widget.account?.note);
  late final _recovery = TextEditingController(
    text: widget.account?.recoveryCodes.join('\n'),
  );
  late final _period = TextEditingController(
    text: '${widget.account?.period ?? 30}',
  );
  late final _counter = TextEditingController(
    text: '${widget.account?.counter ?? 0}',
  );
  late OtpType _type = widget.account?.type ?? OtpType.totp;
  late OtpAlgorithm _algorithm = widget.account?.algorithm ?? OtpAlgorithm.sha1;
  late int _digits = widget.account?.digits ?? 6;
  late List<String> _packages = [...?widget.account?.packages];
  late List<String> _domains = [...?widget.account?.domains];
  bool _saving = false;

  bool get _isNew => widget.account == null;

  @override
  void dispose() {
    for (final c in [
      _issuer,
      _name,
      _secret,
      _note,
      _recovery,
      _period,
      _counter,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final l = context.l10n;
    final repo = ref.read(accountsRepositoryProvider);
    final steam = _type == OtpType.steam;
    final period = int.tryParse(_period.text.trim()) ?? 30;
    final counter = int.tryParse(_counter.text.trim()) ?? 0;
    final recovery = [
      for (final line in _recovery.text.split('\n'))
        if (line.trim().isNotEmpty) line.trim(),
    ];
    try {
      final existing = widget.account;
      if (existing == null) {
        final result = await repo.addAll([
          Account(
            id: '',
            issuer: _issuer.text.trim(),
            name: _name.text.trim(),
            secret: Base32.normalize(_secret.text),
            type: _type,
            algorithm: steam ? OtpAlgorithm.sha1 : _algorithm,
            digits: steam ? 5 : _digits,
            period: steam ? 30 : period,
            counter: counter,
            note: _note.text.trim(),
            recoveryCodes: recovery,
          ),
        ]);
        if (!mounted) return;
        if (result.added.isEmpty) {
          showSnack(context, l.alreadyHere);
          setState(() => _saving = false);
          return;
        }
      } else {
        await repo.save(
          existing.copyWith(
            issuer: _issuer.text.trim(),
            name: _name.text.trim(),
            type: _type,
            algorithm: steam ? OtpAlgorithm.sha1 : _algorithm,
            digits: steam ? 5 : _digits,
            period: steam ? 30 : period,
            counter: counter,
            note: _note.text.trim(),
            recoveryCodes: recovery,
            packages: _packages,
            domains: _domains,
          ),
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } on Object {
      if (!mounted) return;
      showSnack(context, l.couldNotSave);
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? l.addAccount : l.editAccount),
        actions: [
          TextButton(
            key: const Key('save-account'),
            onPressed: _saving ? null : _save,
            child: Text(l.save),
          ),
        ],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              key: const Key('field-issuer'),
              controller: _issuer,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: l.serviceLabel,
                hintText: l.serviceHint,
              ),
              validator: (v) =>
                  (v ?? '').trim().isEmpty && _name.text.trim().isEmpty
                  ? l.serviceRequired
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('field-name'),
              controller: _name,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: l.accountLabel,
                hintText: l.accountHint,
              ),
            ),
            if (_isNew) ...[
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('field-secret'),
                controller: _secret,
                autocorrect: false,
                enableSuggestions: false,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z2-7 \-=]')),
                ],
                decoration: InputDecoration(
                  labelText: l.keyLabel,
                  helperText: l.keyHelp,
                  helperMaxLines: 3,
                ),
                validator: (v) => Base32.isValid(v ?? '') ? null : l.keyInvalid,
              ),
            ],
            const SizedBox(height: 8),
            ExpansionTile(
              key: const Key('advanced'),
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 8),
              title: Text(l.advanced),
              subtitle: Text(l.advancedHint),
              children: [
                DropdownButtonFormField<OtpType>(
                  initialValue: _type,
                  decoration: InputDecoration(labelText: l.codeKind),
                  items: [
                    DropdownMenuItem(
                      value: OtpType.totp,
                      child: Text(l.kindTime),
                    ),
                    DropdownMenuItem(
                      value: OtpType.hotp,
                      child: Text(l.kindCounter),
                    ),
                    DropdownMenuItem(
                      value: OtpType.steam,
                      child: Text(l.kindSteam),
                    ),
                  ],
                  onChanged: (v) => setState(() => _type = v ?? OtpType.totp),
                ),
                if (_type != OtpType.steam) ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<OtpAlgorithm>(
                    initialValue: _algorithm,
                    decoration: InputDecoration(labelText: l.algorithm),
                    items: [
                      for (final a in OtpAlgorithm.values)
                        DropdownMenuItem(value: a, child: Text(a.label)),
                    ],
                    onChanged: (v) =>
                        setState(() => _algorithm = v ?? OtpAlgorithm.sha1),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    initialValue: const [6, 7, 8].contains(_digits)
                        ? _digits
                        : 6,
                    decoration: InputDecoration(labelText: l.digits),
                    items: [
                      for (final d in const [6, 7, 8])
                        DropdownMenuItem(value: d, child: Text('$d')),
                    ],
                    onChanged: (v) => setState(() => _digits = v ?? 6),
                  ),
                ],
                if (_type == OtpType.totp) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _period,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(labelText: l.periodSeconds),
                    validator: (v) {
                      final n = int.tryParse((v ?? '').trim());
                      return n == null || n < 5 || n > 3600
                          ? l.periodInvalid
                          : null;
                    },
                  ),
                ],
                if (_type == OtpType.hotp) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _counter,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(labelText: l.counter),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              key: const Key('field-note'),
              controller: _note,
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: l.note),
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('field-recovery'),
              controller: _recovery,
              maxLines: null,
              minLines: 2,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: l.recoveryCodes,
                helperText: l.recoveryCodesHelp,
                helperMaxLines: 3,
              ),
            ),
            if (_packages.isNotEmpty || _domains.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(l.usedIn, style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(l.usedInHelp, style: theme.textTheme.bodySmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final d in _domains)
                    InputChip(
                      avatar: const Icon(Icons.public, size: 18),
                      label: Text(d),
                      onDeleted: () =>
                          setState(() => _domains = [..._domains]..remove(d)),
                    ),
                  for (final p in _packages)
                    InputChip(
                      avatar: const Icon(Icons.apps, size: 18),
                      label: Text(p),
                      onDeleted: () =>
                          setState(() => _packages = [..._packages]..remove(p)),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
