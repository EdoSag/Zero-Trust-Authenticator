import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_authenticator/links/code_matcher.dart';
import 'package:zerotrust_authenticator/model/account.dart';
import 'package:zerotrust_authenticator/platform/device_bridge.dart';
import 'package:zerotrust_authenticator/ui/pick_code_page.dart';
import 'package:zerotrust_authenticator/ui/settings_page.dart';

import 'support/app.dart';

// A code that lasts a day, so a test never lands on a code's last seconds.
const github = Account(
  id: 'gh',
  issuer: 'GitHub',
  name: 'edo',
  secret: testSecret,
  period: 86400,
  order: 1,
);
const forum = Account(
  id: 'forum',
  issuer: 'Tiny Forum',
  secret: 'GEZDGNBVGY3TQOJQ',
  period: 86400,
  order: 2,
);

void phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(360 * 3, 740 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

/// The app's own settings rows, on a phone whose autofill is [autofill].
Widget settings({
  Locale locale = ZtLanguages.english,
  AutofillState autofill = AutofillState.unsupported,
}) {
  final widget = app(
    Scaffold(body: ListView(children: const [AppSettingsRows()])),
    locale: locale,
  );
  bridge.autofill = autofill;
  return widget;
}

/// The app goes behind Android's screen and comes back to the front.
void awayAndBack(WidgetTester tester, void Function() meanwhile) {
  for (final state in const [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
  meanwhile();
  for (final state in const [
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
}

const on = AutofillState(supported: true, enabled: true);
const off = AutofillState(supported: true, enabled: false);

void main() {
  group('who is asking', () {
    test('autofill in a browser: the site the browser shows', () {
      final request = CodeRequest.fromDevice(const {
        'source': 'autofill',
        'package': 'app.vanadium.browser',
        'domain': 'github.com',
        'appLabel': 'Vanadium',
      });
      expect(request.site, 'github.com');
      expect(request.app, isNull);
      expect(request.targetName, 'github.com');
    });

    test('autofill in another app: a site it names is not believed', () {
      final request = CodeRequest.fromDevice(const {
        'source': 'autofill',
        'package': 'com.evil.app',
        'domain': 'github.com',
        'appLabel': 'Free Games',
      });
      expect(request.site, isNull);
      expect(request.app, 'com.evil.app');
      expect(request.targetName, 'Free Games');
      // So GitHub's account is not offered as the likely one for it.
      expect(CodeMatcher.strength(github, request), LinkStrength.none);
    });

    test('autofill in a browser that names no site: no target', () {
      final request = CodeRequest.fromDevice(const {
        'source': 'autofill',
        'package': 'com.android.chrome',
        'domain': null,
      });
      expect(request.knowsTarget, isFalse);
    });

    test('a Zero-Trust app that names a site is believed', () {
      final request = CodeRequest.fromDevice(const {
        'source': 'keyboard',
        'package': 'dev.sagron.zerotrustbrowser',
        'domain': 'github.com',
      });
      expect(request.site, 'github.com');
      // As is a request from before the source was sent.
      expect(
        CodeRequest.fromDevice(const {
          'package': 'com.example',
          'domain': 'example.com',
        }).site,
        'example.com',
      );
    });
  });

  group('the phone side', () {
    const channel = MethodChannel('zt_authenticator/device');
    final calls = <MethodCall>[];
    Object? Function(MethodCall call)? answer;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      calls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return answer?.call(call);
          });
    });
    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('reads whether Android uses this app for autofill', () async {
      answer = (_) => {'supported': true, 'enabled': true};
      final state = await const MethodChannelDeviceBridge().autofillState();
      expect(state.supported, isTrue);
      expect(state.enabled, isTrue);

      answer = (_) => {'supported': true, 'enabled': false};
      expect(
        (await const MethodChannelDeviceBridge().autofillState()).enabled,
        isFalse,
      );
    });

    test('turning it on and off reaches the phone', () async {
      answer = (_) => null;
      await const MethodChannelDeviceBridge().setAutofill(true);
      await const MethodChannelDeviceBridge().setAutofill(false);
      expect(calls.map((c) => c.method), ['setAutofill', 'setAutofill']);
      expect(calls.map((c) => (c.arguments as Map)['on']), [true, false]);
    });

    test('an autofill request arrives with its source applied', () async {
      answer = (_) => {
        'source': 'autofill',
        'package': 'com.evil.app',
        'domain': 'github.com',
        'appLabel': 'Free Games',
      };
      final request = await const MethodChannelDeviceBridge()
          .pendingCodeRequest();
      expect(request!.site, isNull);
      expect(request.app, 'com.evil.app');
    });
  });

  group('settings', () {
    testWidgets('no switch on a phone without autofill', (tester) async {
      phone(tester);
      await tester.pumpWidget(settings());
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('setting-autofill')), findsNothing);
      // The other rows are there as before.
      expect(find.byKey(const Key('setting-clipboard')), findsOneWidget);
      expect(find.byKey(const Key('setting-trash')), findsOneWidget);
    });

    testWidgets('turning it on opens Android\'s screen; the switch follows '
        'what was chosen there', (tester) async {
      phone(tester);
      await tester.pumpWidget(settings(autofill: off));
      await tester.pumpAndSettle();

      final row = find.byKey(const Key('setting-autofill'));
      expect(tester.widget<SwitchListTile>(row).value, isFalse);
      expect(find.textContaining('one app fill in fields'), findsOneWidget);
      // Between the clipboard row and the trash, whole on the screen, and
      // the switch itself can be reached.
      final rect = tester.getRect(row);
      expect(
        rect.top,
        greaterThanOrEqualTo(
          tester.getRect(find.byKey(const Key('setting-clipboard'))).bottom,
        ),
      );
      expect(
        rect.bottom,
        lessThanOrEqualTo(
          tester.getRect(find.byKey(const Key('setting-trash'))).top,
        ),
      );
      expect(rect.left, 0);
      expect(rect.right, 360);
      final toggle = tester.getRect(
        find.descendant(of: row, matching: find.byType(Switch)),
      );
      expect(toggle.right, lessThanOrEqualTo(360));
      expect(toggle.left, greaterThan(180));

      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(bridge.autofillAsked, [true]);
      // Nothing was chosen yet: still off.
      expect(tester.widget<SwitchListTile>(row).value, isFalse);

      // The user picks ZT Authenticator on Android's screen and comes back.
      awayAndBack(tester, () => bridge.autofill = on);
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(row).value, isTrue);
      expect(find.textContaining("this phone's autofill app"), findsOneWidget);

      // Off needs no Android screen.
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(bridge.autofillAsked, [true, false]);
      expect(tester.widget<SwitchListTile>(row).value, isFalse);
    });

    testWidgets('a phone that cannot open the screen says so', (tester) async {
      phone(tester);
      await tester.pumpWidget(settings(autofill: off));
      bridge.autofillFails = true;
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('setting-autofill')));
      await tester.pump();
      expect(
        find.text("This phone doesn't let apps fill in fields"),
        findsOneWidget,
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });

    testWidgets('Hebrew: the switch is on the left and the text fits', (
      tester,
    ) async {
      phone(tester);
      await tester.pumpWidget(
        settings(locale: ZtLanguages.hebrew, autofill: off),
      );
      await tester.pumpAndSettle();
      final row = find.byKey(const Key('setting-autofill'));
      final toggle = tester.getRect(
        find.descendant(of: row, matching: find.byType(Switch)),
      );
      expect(toggle.left, greaterThanOrEqualTo(0));
      expect(toggle.right, lessThan(180));
      final title = tester.getRect(
        find.text('הצעת קודים באפליקציות ובדפדפנים אחרים'),
      );
      expect(title.left, greaterThanOrEqualTo(toggle.right));
      expect(title.right, lessThanOrEqualTo(360));
    });
  });

  group('a code asked for by autofill', () {
    testWidgets('in a browser: the pick is remembered for the site', (
      tester,
    ) async {
      final request = CodeRequest.fromDevice(const {
        'source': 'autofill',
        'package': 'com.android.chrome',
        'domain': 'github.com',
        'appLabel': 'Chrome',
      });
      await tester.pumpWidget(
        app(
          PickCodePage(request: request),
          accounts: const [forum, github],
          request: request,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('For github.com'), findsOneWidget);
      await tester.tap(find.byKey(const Key('pick-gh')));
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(bridge.answers.single.$1, github.codeAt(DateTime.now()));
      expect(repo.account('gh').domains, ['github.com']);
      expect(repo.account('gh').packages, isEmpty);
    });

    testWidgets('an app that only claims to be the site gets the warning', (
      tester,
    ) async {
      final linked = github.copyWith(domains: ['github.com']);
      final request = CodeRequest.fromDevice(const {
        'source': 'autofill',
        'package': 'com.evil.app',
        'domain': 'github.com',
        'appLabel': 'Free Games',
      });
      await tester.pumpWidget(
        app(
          PickCodePage(request: request),
          accounts: [forum, linked],
          request: request,
        ),
      );
      await tester.pumpAndSettle();
      // The code does not go out on its own, and the account is not put
      // forward as the likely one.
      expect(bridge.answers, isEmpty);
      expect(find.text('For Free Games'), findsNothing);
      await tester.tap(find.byKey(const Key('pick-gh')));
      await tester.pumpAndSettle();
      expect(find.text("This doesn't look right"), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(bridge.answers, isEmpty);
      expect(repo.account('gh').packages, isEmpty);
    });
  });
}
