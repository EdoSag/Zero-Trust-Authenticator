import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_trust_core/zero_trust_core.dart';

/// The Authenticator's own settings, kept on this phone only.
class AuthenticatorSettings {
  const AuthenticatorSettings({
    this.hideCodes = false,
    this.clipboardSeconds = 30,
  });

  /// Codes show as dots until one is tapped.
  final bool hideCodes;

  /// Seconds until a copied code is cleared from the clipboard; 0 never.
  final int clipboardSeconds;

  Duration? get clipboardClearAfter =>
      clipboardSeconds > 0 ? Duration(seconds: clipboardSeconds) : null;

  static const clipboardChoices = [15, 30, 60, 0];
}

class AuthenticatorSettingsController extends Notifier<AuthenticatorSettings> {
  static const _hideKey = 'authenticator_hide_codes';
  static const _clipboardKey = 'authenticator_clipboard_seconds';

  bool _changed = false;

  @override
  AuthenticatorSettings build() {
    _load();
    return const AuthenticatorSettings();
  }

  Future<void> _load() async {
    final String? hide;
    final String? clipboard;
    try {
      final store = ref.read(ztPreferencesStoreProvider);
      hide = await store.read(_hideKey);
      clipboard = await store.read(_clipboardKey);
    } on Object {
      return; // Unreadable: keep the defaults.
    }
    if (_changed) return;
    state = AuthenticatorSettings(
      hideCodes: hide == 'true',
      clipboardSeconds: int.tryParse(clipboard ?? '') ?? 30,
    );
  }

  Future<void> setHideCodes(bool on) async {
    _changed = true;
    state = AuthenticatorSettings(
      hideCodes: on,
      clipboardSeconds: state.clipboardSeconds,
    );
    await ref.read(ztPreferencesStoreProvider).write(_hideKey, '$on');
  }

  Future<void> setClipboardSeconds(int seconds) async {
    _changed = true;
    state = AuthenticatorSettings(
      hideCodes: state.hideCodes,
      clipboardSeconds: seconds,
    );
    await ref.read(ztPreferencesStoreProvider).write(_clipboardKey, '$seconds');
  }
}

final authenticatorSettingsProvider =
    NotifierProvider<AuthenticatorSettingsController, AuthenticatorSettings>(
      AuthenticatorSettingsController.new,
    );
