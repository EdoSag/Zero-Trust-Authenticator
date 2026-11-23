import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zero_trust_core/zero_trust_core.dart';

import 'app/app_gate.dart';
import 'app/authenticator_config.dart';
import 'app/incoming_links.dart';
import 'l10n/l10n.dart';
import 'platform/files.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    publishableKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );
  unawaited(IncomingLinks.listen());
  // English or Hebrew, as picked in Settings, from the first frame.
  await ZtLanguageController.preload();
  runApp(
    ProviderScope(
      overrides: [
        ztAppConfigProvider.overrideWithValue(authenticatorAppConfig),
        // Settings, Backup: "Back up everything" and "Restore from a
        // backup" (every Zero-Trust app's data in one encrypted file).
        ztBackupFilesProvider.overrideWith((ref) {
          final files = ref.watch(filesProvider);
          return ZtBackupFiles(
            save: (name, bytes) => files.save(
              name: name,
              mimeType: 'application/octet-stream',
              bytes: bytes,
            ),
            pick: () async => (await files.pick())?.$2,
          );
        }),
      ],
      child: const ZeroTrustAuthenticatorApp(),
    ),
  );
}

class ZeroTrustAuthenticatorApp extends ConsumerWidget {
  const ZeroTrustAuthenticatorApp({super.key, this.home = const AppGate()});

  final Widget home;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ZtThemeBuilder(
      builder: (context, theme, darkTheme, mode) => MaterialApp(
        // On-device task switcher label; the store name is Zero-Trust Authenticator.
        title: 'ZT Authenticator',
        theme: theme,
        darkTheme: darkTheme,
        themeMode: mode,
        // English (default) or Hebrew, from Settings → Appearance → Language.
        locale: ref.watch(ztLanguageProvider),
        supportedLocales: ZtLanguages.supported,
        localizationsDelegates: const [
          AppL10n.delegate,
          ...ZtLanguages.delegates,
        ],
        home: ZtSignInHandoffScope(child: home),
        // Any touch on any screen counts as activity for auto-lock.
        builder: (BuildContext context, Widget? child) => Listener(
          onPointerDown: (_) =>
              ref.read(vaultControllerProvider.notifier).touch(),
          child: child,
        ),
      ),
    );
  }
}
