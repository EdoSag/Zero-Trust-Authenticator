import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:qr_code_scanner_plus/qr_code_scanner_plus.dart';
import 'package:zxing2/qrcode.dart';

import '../l10n/l10n.dart';
import '../model/account.dart';
import '../otp/otpauth.dart';
import 'common.dart';

/// Scans an account's QR code with the camera and pops the accounts in it:
/// one for a service's own code, several for a Google Authenticator export.
/// The picture never leaves the phone.
class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  final _key = GlobalKey(debugLabel: 'qr');
  bool _done = false;
  DateTime _lastWarning = DateTime(2000);

  /// The camera read [code]: done when it is an account, a short notice
  /// (not more often than every few seconds) when it is something else.
  void _scanned(String? code, QRViewController controller) {
    if (_done || code == null || !mounted) return;
    final List<Account> accounts;
    try {
      accounts = OtpAuth.parse(code);
    } on FormatException {
      final now = DateTime.now();
      if (now.difference(_lastWarning).inSeconds >= 4) {
        _lastWarning = now;
        showSnack(context, context.l10n.notAccountQr);
      }
      return;
    }
    _done = true;
    controller.pauseCamera();
    Navigator.of(context).pop(accounts);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.scanQr)),
      body: Stack(
        children: [
          QRView(
            key: _key,
            overlay: QrScannerOverlayShape(
              borderColor: Theme.of(context).colorScheme.primary,
              borderRadius: 12,
              borderLength: 32,
              borderWidth: 8,
              cutOutSize: 260,
            ),
            onPermissionSet: (_, allowed) {
              if (!allowed && mounted) showSnack(context, l.cameraRefused);
            },
            onQRViewCreated: (controller) {
              controller.scannedDataStream.listen(
                (b) => _scanned(b.code, controller),
              );
            },
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 32,
            child: Text(
              l.scanHint,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

/// The text of the QR code in a picture (a screenshot of a setup page, a
/// photo of a screen), or null when none is found. Decoded on the phone.
Future<String?> readQrFromImage(Uint8List bytes) => compute(_decodeQr, bytes);

String? _decodeQr(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  // Big photos are slow and no easier to read; shrink them first, then try
  // smaller still, which helps with blurry ones.
  for (final side in const [1200, 800, 500]) {
    var image = decoded;
    if (image.width > side || image.height > side) {
      image = image.width >= image.height
          ? img.copyResize(image, width: side)
          : img.copyResize(image, height: side);
    }
    final pixels = image
        .convert(numChannels: 4)
        .getBytes(order: img.ChannelOrder.abgr)
        .buffer
        .asInt32List();
    final source = RGBLuminanceSource(image.width, image.height, pixels);
    for (final binarizer in [
      HybridBinarizer(source),
      GlobalHistogramBinarizer(source),
    ]) {
      try {
        return QRCodeReader().decode(BinaryBitmap(binarizer)).text;
      } on Object {
        // Try the next way.
      }
    }
    if (decoded.width <= side && decoded.height <= side) break;
  }
  return null;
}
