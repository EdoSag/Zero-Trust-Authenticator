import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/accounts_store.dart';
import '../l10n/l10n.dart';
import '../links/code_matcher.dart';
import '../model/account.dart';
import '../otp/otp.dart';
import '../platform/device_bridge.dart';
import 'common.dart';

/// Shown instead of the home screen when this app was opened for a code,
/// by ZT Keyboard (or another Zero-Trust app) or from Android's autofill
/// suggestion: hands back the code of the account that belongs to the app
/// or site being typed into.
///
/// One account already given to that app or site: its code goes back at
/// once. Otherwise the user picks, with the likely accounts first, and the
/// pick is remembered. Only the digits leave; the key never does.
class PickCodePage extends ConsumerStatefulWidget {
  const PickCodePage({super.key, required this.request});

  final CodeRequest request;

  /// A code with less than this left is not handed over: by the time it is
  /// typed and sent it may have stopped working.
  static const freshFor = Duration(seconds: 3);

  @override
  ConsumerState<PickCodePage> createState() => _PickCodePageState();
}

class _PickCodePageState extends ConsumerState<PickCodePage> {
  final _search = TextEditingController();
  bool _remember = true;
  bool _triedOnlyLinked = false;

  /// The account whose code is on its way back.
  Account? _sending;

  CodeRequest get _request => widget.request;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _decline() =>
      ref.read(deviceBridgeProvider).answerCodeRequest(null);

  /// Hands [account]'s code back, waiting for the next one when the
  /// current code is about to run out.
  Future<void> _send(Account account) async {
    if (_sending != null) return;
    setState(() => _sending = account);
    final bridge = ref.read(deviceBridgeProvider);
    try {
      var now = DateTime.now();
      final until = account.validUntil(now);
      if (until != null && until.difference(now) < PickCodePage.freshFor) {
        await Future<void>.delayed(
          until.difference(now) + const Duration(milliseconds: 50),
        );
        now = DateTime.now();
      }
      final code = account.codeAt(now);
      if (account.type == OtpType.hotp) {
        // The counter moves on only once the code is really used.
        await ref.read(accountsRepositoryProvider).nextCounter(account);
      }
      await bridge.answerCodeRequest(code, validUntil: account.validUntil(now));
    } on Object {
      if (!mounted) return;
      setState(() => _sending = null);
      showSnack(context, context.l10n.badKey);
    }
  }

  Future<void> _picked(Account account) async {
    final l = context.l10n;
    final wrong = CodeMatcher.belongsElsewhere(account, _request);
    if (wrong != null) {
      final site = wrong.site;
      final ok = await confirm(
        context,
        title: l.mismatchTitle,
        body: site != null
            ? l.mismatchBodySite(account.title, site, _request.targetName)
            : l.mismatchBodyApp(account.title, _request.targetName),
        action: l.mismatchSendAnyway,
        destructive: true,
      );
      if (!ok || !mounted) return;
    }
    var chosen = account;
    if (_remember && _request.knowsTarget) {
      try {
        chosen = await ref
            .read(accountsRepositoryProvider)
            .link(account, package: _request.app, domain: _request.site);
      } on Object {
        // The code still goes back; the choice is asked again next time.
      }
    }
    await _send(chosen);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final accounts = ref.watch(accountsProvider);
    final target = _request.targetName;

    final list = accounts.value;
    if (list != null && !_triedOnlyLinked && _sending == null) {
      _triedOnlyLinked = true;
      final only = CodeMatcher.onlyLinked(list, _request);
      if (only != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _send(only));
      }
    }

    final sending = _sending;
    final Widget body;
    if (sending != null) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
              Text(
                l.sendingCode(sending.title),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
            ],
          ),
        ),
      );
    } else if (list == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (list.isEmpty) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(l.pickNoAccounts, textAlign: TextAlign.center),
        ),
      );
    } else {
      final query = _search.text.trim().toLowerCase();
      final ranked = [
        for (final a in CodeMatcher.ranked(list, _request))
          if (query.isEmpty ||
              a.issuer.toLowerCase().contains(query) ||
              a.name.toLowerCase().contains(query))
            a,
      ];
      final likely = [
        for (final a in ranked)
          if (CodeMatcher.strength(a, _request) != LinkStrength.none) a,
      ];
      final others = [
        for (final a in ranked)
          if (CodeMatcher.strength(a, _request) == LinkStrength.none) a,
      ];
      Widget tile(Account a) => ListTile(
        key: Key('pick-${a.id}'),
        leading: AccountAvatar(a),
        title: Text(a.title),
        subtitle: a.subtitle.isEmpty ? null : Text(a.subtitle),
        onTap: () => _picked(a),
      );
      Widget header(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(
          text,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
      );
      body = Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              key: const Key('pick-search'),
              controller: _search,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: l.search,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          if (_request.knowsTarget)
            CheckboxListTile(
              key: const Key('pick-remember'),
              value: _remember,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(l.rememberFor(target)),
              onChanged: (v) => setState(() => _remember = v ?? false),
            ),
          Expanded(
            child: ListView(
              children: [
                if (likely.isNotEmpty) ...[
                  header(l.pickLikely(target)),
                  ...likely.map(tile),
                  if (others.isNotEmpty) header(l.pickOthers),
                ],
                ...others.map(tile),
                if (ranked.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(l.nothingFound, textAlign: TextAlign.center),
                  ),
              ],
            ),
          ),
        ],
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _decline();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: l.cancel,
            icon: const Icon(Icons.close),
            onPressed: _decline,
          ),
          title: Text(target.isEmpty ? l.pickTitle : l.pickTitleFor(target)),
        ),
        body: body,
      ),
    );
  }
}
