import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zerotrust_authenticator/app/app_gate.dart';
import 'package:zerotrust_authenticator/links/code_matcher.dart';
import 'package:zerotrust_authenticator/model/account.dart';
import 'package:zerotrust_authenticator/otp/otp.dart';
import 'package:zerotrust_authenticator/ui/home_page.dart';
import 'package:zerotrust_authenticator/ui/pick_code_page.dart';

import 'support/app.dart';

// A code that lasts a day, so the test never lands on the last seconds of
// one (where the app rightly waits for the next code).
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
const bank = Account(
  id: 'bank',
  issuer: 'Bank',
  secret: 'MFRGGZDFMZTWQ2LK',
  type: OtpType.hotp,
  counter: 4,
  order: 3,
);

const onGithub = CodeRequest(
  package: 'com.android.chrome',
  domain: 'github.com',
  appLabel: 'Chrome',
);

/// The code and the time it runs out, as handed back to the keyboard.
void expectAnswer(Account account) {
  final (code, until) = bridge.answers.single;
  expect(code, account.codeAt(DateTime.now()));
  expect(code, matches(RegExp(r'^\d+$')), reason: 'digits only');
  expect(until, account.validUntil(DateTime.now()));
}

/// Lets a code go out. The screen then shows a spinner until Android
/// closes it, so there is nothing to settle.
Future<void> sent(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  testWidgets('opened for a code: the picker; opened normally: the list', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        const AuthenticatorHome(),
        accounts: const [github, forum],
        request: onGithub,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(PickCodePage), findsOneWidget);
    expect(find.byType(HomePage), findsNothing);

    await tester.pumpWidget(
      app(
        const AuthenticatorHome(key: Key('plain')),
        accounts: const [github, forum],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(HomePage), findsOneWidget);
    expect(find.byType(PickCodePage), findsNothing);
  });

  testWidgets(
    'first time on a site: likely account first, pick is remembered',
    (tester) async {
      tester.view.physicalSize = const Size(360 * 3, 740 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        app(
          const PickCodePage(request: onGithub),
          accounts: const [forum, github, bank],
          request: onGithub,
        ),
      );
      await tester.pumpAndSettle();
      // Nothing goes back on its own: the built-in list only suggests.
      expect(bridge.answers, isEmpty);
      expect(find.text('Code for github.com'), findsOneWidget);
      expect(find.text('For github.com'), findsOneWidget);
      expect(find.text('All accounts'), findsOneWidget);
      // The suggested account is above the others, under its heading.
      final heading = tester.getRect(find.text('For github.com'));
      final likely = tester.getRect(find.byKey(const Key('pick-gh')));
      final others = tester.getRect(find.text('All accounts'));
      final rest = tester.getRect(find.byKey(const Key('pick-forum')));
      expect(likely.top, greaterThanOrEqualTo(heading.bottom));
      expect(others.top, greaterThanOrEqualTo(likely.bottom));
      expect(rest.top, greaterThanOrEqualTo(others.bottom));
      // No code is shown on this screen.
      expect(find.textContaining(github.codeAt(DateTime.now())), findsNothing);

      await tester.tap(find.byKey(const Key('pick-gh')));
      await sent(tester);
      expectAnswer(github);
      // Remembered for the site, not for the browser.
      expect(repo.account('gh').domains, ['github.com']);
      expect(repo.account('gh').packages, isEmpty);
    },
  );

  testWidgets('next time the linked account answers without asking', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        const PickCodePage(request: onGithub),
        accounts: [
          forum,
          github.copyWith(domains: const ['github.com']),
        ],
        request: onGithub,
      ),
    );
    await sent(tester);
    expectAnswer(github);
    expect(find.text('Sending the code for GitHub'), findsOneWidget);
  });

  testWidgets('two accounts linked to one place: the user still picks', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        const PickCodePage(request: onGithub),
        accounts: [
          forum.copyWith(domains: const ['github.com']),
          github.copyWith(domains: const ['github.com']),
        ],
        request: onGithub,
      ),
    );
    await tester.pumpAndSettle();
    expect(bridge.answers, isEmpty);
    expect(find.byKey(const Key('pick-gh')), findsOneWidget);
    expect(find.byKey(const Key('pick-forum')), findsOneWidget);
  });

  testWidgets('a look-alike site gets a warning before any code', (
    tester,
  ) async {
    const fake = CodeRequest(
      package: 'com.android.chrome',
      domain: 'github.com.evil.io',
    );
    await tester.pumpWidget(
      app(
        const PickCodePage(request: fake),
        accounts: const [github, forum],
        request: fake,
      ),
    );
    await tester.pumpAndSettle();
    // Not suggested for the look-alike.
    expect(find.text('For github.com.evil.io'), findsNothing);
    await tester.tap(find.byKey(const Key('pick-gh')));
    await tester.pumpAndSettle();
    expect(find.text("This doesn't look right"), findsOneWidget);
    expect(
      find.textContaining(
        'GitHub is saved for github.com, but the code was asked for by '
        'github.com.evil.io.',
      ),
      findsOneWidget,
    );
    // The two answers are side by side and both readable.
    final cancel = tester.getRect(find.text('Cancel'));
    final send = tester.getRect(find.text('Send anyway'));
    expect(cancel.right, lessThanOrEqualTo(send.left));
    expect(send.width, lessThan(240));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(bridge.answers, isEmpty);
    expect(repo.account('gh').domains, isEmpty);
  });

  testWidgets('without "remember", the pick is not saved', (tester) async {
    const request = CodeRequest(
      package: 'org.tinyforum.app',
      appLabel: 'Tiny Forum',
    );
    await tester.pumpWidget(
      app(
        const PickCodePage(request: request),
        accounts: const [github, forum],
        request: request,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Code for Tiny Forum'), findsOneWidget);
    expect(find.text('Remember my choice for Tiny Forum'), findsOneWidget);
    await tester.tap(find.byKey(const Key('pick-remember')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pick-forum')));
    await sent(tester);
    expectAnswer(forum);
    expect(repo.account('forum').packages, isEmpty);
  });

  testWidgets('a browser with no site: nothing to remember, search works', (
    tester,
  ) async {
    const request = CodeRequest(
      package: 'com.android.chrome',
      appLabel: 'Chrome',
    );
    await tester.pumpWidget(
      app(
        const PickCodePage(request: request),
        accounts: const [github, forum],
        request: request,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pick-remember')), findsNothing);
    await tester.enterText(find.byKey(const Key('pick-search')), 'tiny');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pick-gh')), findsNothing);
    await tester.tap(find.byKey(const Key('pick-forum')));
    await sent(tester);
    expectAnswer(forum);
    expect(repo.account('forum').packages, isEmpty);
    expect(repo.account('forum').domains, isEmpty);
  });

  testWidgets('a counter-based code moves the counter on when it is used', (
    tester,
  ) async {
    const request = CodeRequest(package: 'com.bank.app', appLabel: 'Bank');
    await tester.pumpWidget(
      app(
        const PickCodePage(request: request),
        accounts: const [bank],
        request: request,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pick-bank')));
    await sent(tester);
    final (code, until) = bridge.answers.single;
    expect(code, bank.codeAt(DateTime.now()));
    expect(until, isNull);
    expect(repo.account('bank').counter, 5);
    expect(repo.account('bank').packages, ['com.bank.app']);
  });

  testWidgets('closing the screen or going back declines', (tester) async {
    await tester.pumpWidget(
      app(
        const PickCodePage(request: onGithub),
        accounts: const [github],
        request: onGithub,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Cancel'));
    await tester.pumpAndSettle();
    expect(bridge.answers.single, (null, null));

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(bridge.answers, hasLength(2));
    expect(bridge.answers.last.$1, isNull);
  });

  testWidgets('no accounts yet: says so, sends nothing', (tester) async {
    await tester.pumpWidget(
      app(const PickCodePage(request: onGithub), request: onGithub),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('There are no accounts yet'), findsOneWidget);
    expect(bridge.answers, isEmpty);
  });

  testWidgets('a code about to run out is not sent: the next one is', (
    tester,
  ) async {
    // A two-second code is always inside its last three seconds.
    final quick = github.copyWith(period: 2, domains: const ['github.com']);
    await tester.pumpWidget(
      app(
        const PickCodePage(request: onGithub),
        accounts: [quick],
        request: onGithub,
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    // Waiting for the next code, nothing sent yet.
    expect(bridge.answers, isEmpty);
    expect(find.text('Sending the code for GitHub'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await sent(tester);
    expect(bridge.answers, hasLength(1));
  });

  testWidgets('locked while waiting for the next code: nothing is sent', (
    tester,
  ) async {
    final quick = github.copyWith(period: 2, domains: const ['github.com']);
    await tester.pumpWidget(
      app(
        const PickCodePage(request: onGithub),
        accounts: [quick],
        request: onGithub,
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Sending the code for GitHub'), findsOneWidget);
    // The app locks: the picker is taken off the screen, as the unlock
    // screen does.
    final request = bridge.request;
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
    await sent(tester);
    expect(bridge.answers, isEmpty);
    // Still waiting, so it is asked again after unlocking.
    expect(bridge.request, same(request));
  });
}
