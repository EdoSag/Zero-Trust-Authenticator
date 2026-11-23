import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../otp/otpauth.dart';

/// The links that open this app: account emails (password reset), and
/// account links from a setup page (`otpauth://…`, tapped instead of
/// scanned when signing up on the same phone).
abstract final class IncomingLinks {
  /// The password-reset email links straight here:
  /// https://zerotrust.bz/auth/authenticator/#token_hash=…&type=recovery
  /// (see the reset-password email template). Android opens it in this app
  /// (App Links: the intent filter in AndroidManifest.xml and the website's
  /// /.well-known/assetlinks.json), whatever the default browser is, and
  /// [listen] turns it into the password-recovery sign-in, after which
  /// AppGate shows ZtResetPasswordScreen. On the web there is no app, so
  /// the Site URL is used.
  static String? get passwordReset =>
      kIsWeb ? null : 'https://zerotrust.bz/auth/authenticator/';

  /// The confirm-email link lands on a website page that says the address is
  /// confirmed and to sign in here.
  static const confirmed = 'https://zerotrust.bz/auth/confirmed/';

  /// Account links that opened the app and are not added yet. They wait
  /// here until the vault is unlocked; the home screen asks before adding.
  static final accountLinks = ValueNotifier<List<String>>(const []);

  /// Takes the waiting account links.
  static List<String> takeAccountLinks() {
    final links = accountLinks.value;
    if (links.isNotEmpty) accountLinks.value = const [];
    return links;
  }

  static StreamSubscription<String>? _links;
  static final _used = <String>{};

  /// Starts handling links. Call once, after Supabase.initialize. (Reset
  /// links that carry `?code=` instead, from the default email template,
  /// are handled by supabase_flutter itself.)
  static Future<void> listen() async {
    if (kIsWeb || _links != null) return;
    final appLinks = AppLinks();
    _links = appLinks.stringLinkStream.listen(handle, onError: (_) {});
    try {
      final initial = await appLinks.getInitialLinkString();
      if (initial != null) await handle(initial);
    } on Object catch (e) {
      debugPrint('Initial link unavailable: $e');
    }
  }

  @visibleForTesting
  static Future<void> handle(String link) async {
    // The same link can arrive twice (initial link and stream).
    if (OtpAuth.looksLikeLink(link)) {
      if (!accountLinks.value.contains(link)) {
        accountLinks.value = [...accountLinks.value, link];
      }
      return;
    }
    final uri = Uri.tryParse(link);
    if (uri == null) return;
    if (uri.host != 'zerotrust.bz' || !uri.path.startsWith('/auth/')) return;
    // The token is after the # so it never reaches a web server.
    final params = Uri.splitQueryString(uri.fragment);
    final tokenHash = params['token_hash'];
    if (tokenHash == null || params['type'] != 'recovery') return;
    if (!_used.add(tokenHash)) return;
    try {
      // Signs in for recovery and raises AuthChangeEvent.passwordRecovery.
      await Supabase.instance.client.auth.verifyOTP(
        type: OtpType.recovery,
        tokenHash: tokenHash,
      );
    } on Object catch (e) {
      // Expired or already used: the sign-in screen stays, and Forgot
      // password sends a new link.
      debugPrint('Password-reset link not accepted: $e');
    }
  }
}
