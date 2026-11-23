import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../l10n/l10n.dart';
import '../model/account.dart';
import '../otp/otpauth.dart';

/// Shows [account] as a QR code another authenticator app can scan, to move
/// or copy the account. Whoever sees it can make its codes.
Future<void> showAccountQr(BuildContext context, Account account) {
  final l = context.l10n;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              account.title,
              style: Theme.of(ctx).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            if (account.subtitle.isNotEmpty)
              Text(account.subtitle, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            // Always dark on white, so it scans in dark mode too.
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(12),
              child: QrImageView(
                data: OtpAuth.format(account),
                size: 240,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l.qrWarning,
              textAlign: TextAlign.center,
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    ),
  );
}
