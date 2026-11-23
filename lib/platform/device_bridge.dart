import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../links/code_matcher.dart';

/// Whether this phone can make ZT Authenticator its autofill app, and
/// whether it is that now.
class AutofillState {
  const AutofillState({required this.supported, required this.enabled});

  static const unsupported = AutofillState(supported: false, enabled: false);

  final bool supported;
  final bool enabled;
}

/// The phone-side jobs done in Kotlin (`CodeActivity`): answering whoever
/// asked for a code (ZT Keyboard, or Android autofill), the private
/// clipboard, and the autofill switch.
abstract class DeviceBridge {
  /// The code request this screen was opened for, or null when the app was
  /// simply opened. The same request is returned until it is answered.
  Future<CodeRequest?> pendingCodeRequest();

  /// Hands [code] (digits only) back to whoever asked and closes this
  /// screen; null declines. [validUntil] is when the code stops working.
  Future<void> answerCodeRequest(String? code, {DateTime? validUntil});

  /// Copies [text] marked as private (Android hides it from the clipboard
  /// preview) and clears it after [clearAfter]; null leaves it.
  Future<void> copyPrivately(String text, {Duration? clearAfter});

  /// Whether Android offers this app's codes on other apps' code fields.
  Future<AutofillState> autofillState();

  /// On: opens Android's own screen, where the user makes this app the
  /// phone's autofill app (nothing changes until they do). Off: stops
  /// being it. Ask [autofillState] again when the app is back in front.
  Future<void> setAutofill(bool on);
}

class MethodChannelDeviceBridge implements DeviceBridge {
  const MethodChannelDeviceBridge();

  static const _channel = MethodChannel('zt_authenticator/device');

  @override
  Future<CodeRequest?> pendingCodeRequest() async {
    final Map<Object?, Object?>? raw;
    try {
      raw = await _channel.invokeMapMethod<Object?, Object?>(
        'pendingCodeRequest',
      );
    } on MissingPluginException {
      return null;
    }
    return raw == null ? null : CodeRequest.fromDevice(raw);
  }

  @override
  Future<void> answerCodeRequest(String? code, {DateTime? validUntil}) =>
      _channel.invokeMethod<void>('answerCodeRequest', {
        'code': code,
        'validUntil': validUntil?.millisecondsSinceEpoch,
      });

  @override
  Future<void> copyPrivately(String text, {Duration? clearAfter}) async {
    try {
      await _channel.invokeMethod<void>('copyPrivately', {
        'text': text,
        'clearAfterMs': clearAfter?.inMilliseconds,
      });
    } on MissingPluginException {
      await Clipboard.setData(ClipboardData(text: text));
    }
  }

  @override
  Future<AutofillState> autofillState() async {
    try {
      final raw = await _channel.invokeMapMethod<Object?, Object?>(
        'autofillState',
      );
      return AutofillState(
        supported: raw?['supported'] == true,
        enabled: raw?['enabled'] == true,
      );
    } on MissingPluginException {
      return AutofillState.unsupported;
    }
  }

  @override
  Future<void> setAutofill(bool on) =>
      _channel.invokeMethod<void>('setAutofill', {'on': on});
}

final deviceBridgeProvider = Provider<DeviceBridge>(
  (ref) => const MethodChannelDeviceBridge(),
);
