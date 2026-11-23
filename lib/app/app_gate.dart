import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_trust_core/zero_trust_core.dart';

import '../links/code_matcher.dart';
import '../platform/device_bridge.dart';
import '../ui/home_page.dart';
import '../ui/pick_code_page.dart';
import 'auth_providers.dart';
import 'incoming_links.dart';

/// Routes between the shared account screens and the Authenticator.
///
/// Signed out: sign in or create an account. Signed in but locked (cold
/// start, auto-lock): unlock with the account password or biometrics. A new
/// recovery key is always shown, and confirmed, before the vault opens.
class AppGate extends ConsumerStatefulWidget {
  const AppGate({super.key});

  @override
  ConsumerState<AppGate> createState() => _AppGateState();
}

class _AppGateState extends ConsumerState<AppGate> with WidgetsBindingObserver {
  /// Stays on the sign-in screen until it hands back a result, even though
  /// Supabase reports the session a moment earlier.
  late bool _signingIn = ref.read(currentUserProvider) == null;
  UnlockResult? _awaitingRecoveryKey;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// A key still waiting behind the recovery-key screen is zeroed when the
  /// app leaves the foreground, so coming back asks for the password.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      final UnlockResult? pending = _awaitingRecoveryKey;
      if (pending != null) {
        pending.dek.fillRange(0, pending.dek.length, 0);
        setState(() => _awaitingRecoveryKey = null);
      }
    }
  }

  void _onUnlocked(UnlockResult result) {
    if (result.newRecoveryKey != null) {
      setState(() {
        _signingIn = false;
        _awaitingRecoveryKey = result;
      });
      return;
    }
    setState(() => _signingIn = false);
    ref
        .read(vaultControllerProvider.notifier)
        .unlock(result.dek, legacyDek: result.legacyDek);
  }

  void _forgotPassword() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) =>
          ZtForgotPasswordScreen(redirectTo: IncomingLinks.passwordReset),
    ),
  );

  @override
  Widget build(BuildContext context) {
    ref.listen(vaultControllerProvider, (_, VaultState next) {
      // Don't leave a page open over a locked vault.
      if (next is VaultLocked) {
        Navigator.of(context).popUntil((Route<dynamic> r) => r.isFirst);
      }
    });
    ref.listen(currentUserProvider, (_, user) {
      if (user == null) {
        ref.read(vaultControllerProvider.notifier).lock();
        setState(() => _signingIn = true);
      }
    });

    final UnlockResult? pending = _awaitingRecoveryKey;
    if (pending != null) {
      return ZtRecoveryKeyScreen(
        recoveryKey: pending.newRecoveryKey!,
        onDone: () {
          setState(() => _awaitingRecoveryKey = null);
          ref
              .read(vaultControllerProvider.notifier)
              .unlock(pending.dek, legacyDek: pending.legacyDek);
        },
      );
    }

    if (ref.watch(passwordRecoveryProvider)) {
      return ZtResetPasswordScreen(
        onUnlocked: (UnlockResult result) {
          ref.read(passwordRecoveryProvider.notifier).done();
          _onUnlocked(result);
        },
      );
    }

    final user = ref.watch(currentUserProvider);
    if (user == null || _signingIn) {
      return ZtSignInScreen(
        emailRedirectTo: IncomingLinks.confirmed,
        onUnlocked: _onUnlocked,
        onForgotPassword: _forgotPassword,
      );
    }

    if (ref.watch(vaultControllerProvider) is VaultLocked) {
      return ZtUnlockScreen(
        email: user.email,
        onUnlocked: _onUnlocked,
        onSignOut: () => ref.read(accountServiceProvider).signOut(),
        onForgotPassword: _forgotPassword,
      );
    }

    return const AuthenticatorHome();
  }
}

/// The Authenticator once unlocked: the account list, or, when ZT Keyboard
/// or another Zero-Trust app opened this screen for a code, the picker that
/// hands one back.
class AuthenticatorHome extends ConsumerStatefulWidget {
  const AuthenticatorHome({super.key});

  @override
  ConsumerState<AuthenticatorHome> createState() => _AuthenticatorHomeState();
}

class _AuthenticatorHomeState extends ConsumerState<AuthenticatorHome> {
  late final Future<CodeRequest?> _request = ref
      .read(deviceBridgeProvider)
      .pendingCodeRequest()
      .catchError((Object _) => null);

  @override
  Widget build(BuildContext context) => FutureBuilder<CodeRequest?>(
    future: _request,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      final request = snapshot.data;
      return request == null
          ? const HomePage()
          : PickCodePage(request: request);
    },
  );
}
