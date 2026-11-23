import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/authenticator_settings.dart';
import '../data/accounts_store.dart';
import '../l10n/l10n.dart';
import '../model/account.dart';
import '../platform/device_bridge.dart';
import 'common.dart';

/// One account in the list: its name, the code right now and how long the
/// code has left. A tap copies the code; a long press opens [onMenu].
class AccountTile extends ConsumerStatefulWidget {
  const AccountTile({super.key, required this.account, this.onMenu});

  final Account account;
  final VoidCallback? onMenu;

  @override
  ConsumerState<AccountTile> createState() => _AccountTileState();
}

class _AccountTileState extends ConsumerState<AccountTile> {
  /// With "hide codes" on: the code shows until this moment.
  DateTime? _shownUntil;

  Account get _account => widget.account;

  Future<void> _copy() async {
    final l = context.l10n;
    final settings = ref.read(authenticatorSettingsProvider);
    final now = DateTime.now();
    final String code;
    try {
      code = _account.codeAt(now);
    } on FormatException {
      showSnack(context, l.badKey);
      return;
    }
    setState(() {
      _shownUntil =
          _account.validUntil(now) ?? now.add(const Duration(seconds: 30));
    });
    await ref
        .read(deviceBridgeProvider)
        .copyPrivately(code, clearAfter: settings.clipboardClearAfter);
    if (!mounted) return;
    showSnack(
      context,
      settings.clipboardSeconds > 0
          ? l.copiedClears(settings.clipboardSeconds)
          : l.copied,
    );
  }

  Future<void> _next() async {
    await ref.read(accountsRepositoryProvider).nextCounter(_account);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final now = ref.watch(clockProvider).value ?? DateTime.now();
    final hide = ref.watch(
      authenticatorSettingsProvider.select((s) => s.hideCodes),
    );
    final shown = !hide || (_shownUntil?.isAfter(now) ?? false);

    String code;
    try {
      code = _account.codeAt(now);
    } on FormatException {
      code = '';
    }
    final remaining = _account.remaining(now);
    final until = _account.validUntil(now);
    final secondsLeft = until == null
        ? null
        : (until.difference(now).inMilliseconds / 1000).ceil();
    final ending = secondsLeft != null && secondsLeft <= 5;
    String? next;
    if (ending && shown && code.isNotEmpty && until != null) {
      try {
        next = _account.codeAt(until.add(const Duration(milliseconds: 1)));
      } on FormatException {
        next = null;
      }
    }
    final codeColour = ending
        ? theme.colorScheme.error
        : theme.colorScheme.primary;

    return InkWell(
      onTap: _copy,
      onLongPress: widget.onMenu,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            AccountAvatar(_account),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          _account.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      if (_account.pinned) ...[
                        const SizedBox(width: 6),
                        Icon(
                          Icons.push_pin,
                          size: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                          semanticLabel: l.pinned,
                        ),
                      ],
                    ],
                  ),
                  if (_account.subtitle.isNotEmpty)
                    Text(
                      _account.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  const SizedBox(height: 4),
                  // Digits read left to right in Hebrew too.
                  Text(
                    code.isEmpty
                        ? l.badKey
                        : shown
                        ? spacedCode(code)
                        : spacedCode('•' * code.length),
                    key: Key('code-${_account.id}'),
                    textDirection: TextDirection.ltr,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: code.isEmpty
                          ? theme.colorScheme.error
                          : codeColour,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  // In a code's last seconds: the one that comes after it,
                  // so nobody types a code that is about to stop working.
                  if (next != null)
                    Text(
                      // Kept left to right inside a Hebrew sentence.
                      l.nextCodeIs('\u2066${spacedCode(next)}\u2069'),
                      key: Key('next-${_account.id}'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (_account.timeBased)
              SizedBox(
                width: 36,
                height: 36,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: remaining,
                      strokeWidth: 3,
                      color: codeColour,
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                    ),
                    Text(
                      '${secondsLeft ?? ''}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              )
            else
              IconButton(
                tooltip: l.nextCode,
                icon: const Icon(Icons.refresh),
                onPressed: _next,
              ),
          ],
        ),
      ),
    );
  }
}
