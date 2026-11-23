import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../links/code_matcher.dart';

/// The phone-side jobs done in Kotlin (`MainActivity`): answering another
/// Zero-Trust app that asked for a code, and the private clipboard.
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
    if (raw == null) return null;
    String? text(String key) {
      final v = raw![key];
      return v is String && v.trim().isNotEmpty ? v.trim() : null;
    }

    return CodeRequest(
      package: text('package'),
      domain: text('domain'),
      appLabel: text('appLabel'),
    );
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
}

final deviceBridgeProvider = Provider<DeviceBridge>(
  (ref) => const MethodChannelDeviceBridge(),
);
