import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../model/account.dart';

void showSnack(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(text), duration: const Duration(seconds: 4)),
    );
}

Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String body,
  required String action,
  bool destructive = false,
}) async {
  final l = context.l10n;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(l.cancel),
        ),
        TextButton(
          style: destructive
              ? TextButton.styleFrom(
                  foregroundColor: Theme.of(ctx).colorScheme.error,
                )
              : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(action),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// The round badge beside an account: the first letter of the service on a
/// colour that is always the same for that service. Drawn in the app, never
/// downloaded: fetching a logo would tell a server which services someone
/// uses.
class AccountAvatar extends StatelessWidget {
  const AccountAvatar(this.account, {super.key, this.radius = 20});

  final Account account;
  final double radius;

  static const _colours = [
    Color(0xFF0EA5E9),
    Color(0xFF6366F1),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
    Color(0xFFEC4899),
    Color(0xFF8B5CF6),
    Color(0xFF14B8A6),
    Color(0xFFEF4444),
    Color(0xFF64748B),
  ];

  @override
  Widget build(BuildContext context) {
    final title = account.title.trim();
    var hash = 0;
    for (final unit in title.toLowerCase().codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: _colours[hash % _colours.length],
      foregroundColor: Colors.white,
      child: Text(
        title.isEmpty ? '?' : title.characters.first.toUpperCase(),
        style: TextStyle(fontSize: radius * 0.9, fontWeight: FontWeight.w600),
      ),
    );
  }
}
