import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_authenticator/model/account.dart';
import 'package:zerotrust_authenticator/otp/otp.dart';
import 'package:zerotrust_authenticator/otp/otpauth.dart';
import 'package:zerotrust_authenticator/transfer/importer.dart';
import 'package:zerotrust_authenticator/ui/home_page.dart';
import 'package:zerotrust_authenticator/ui/import_page.dart';
import 'package:zerotrust_authenticator/ui/settings_page.dart';
import 'package:zerotrust_authenticator/ui/trash_page.dart';

import 'support/app.dart';

const github = Account(
  id: 'gh',
  issuer: 'GitHub',
  name: 'edo@example.com',
  secret: testSecret,
  order: 1,
);
const bank = Account(
  id: 'bank',
  issuer: 'Bank',
  name: 'me',
  secret: 'GEZDGNBVGY3TQOJQ',
  type: OtpType.hotp,
  counter: 2,
  order: 2,
);

void phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(360 * 3, 740 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('empty: says how to start, and the add button is in reach', (
    tester,
  ) async {
    phone(tester);
    await tester.pumpWidget(app(const HomePage()));
    await tester.pumpAndSettle();
    expect(find.text('No accounts yet'), findsOneWidget);
    final add = tester.getRect(find.byKey(const Key('add-account')));
    // Bottom corner at the end of the row, fully on screen, a real button.
    expect(add.right, lessThanOrEqualTo(360));
    expect(add.center.dx, greaterThan(180));
    expect(add.bottom, lessThanOrEqualTo(740));
    expect(add.top, greaterThan(600));
    expect(add.width, greaterThan(100));
    expect(add.width, lessThan(260));
    // And it does not sit on top of the explanation.
    expect(
      tester.getRect(find.textContaining('Turn on two-step sign-in')).bottom,
      lessThan(add.top),
    );
  });

  testWidgets('the list: name, code and countdown, laid out in a row', (
    tester,
  ) async {
    phone(tester);
    await tester.pumpWidget(
      app(const HomePage(), accounts: const [github, bank]),
    );
    await tester.pumpAndSettle();

    // The code of the test clock, split in the middle.
    final code = find.byKey(const Key('code-gh'));
    expect(tester.widget<Text>(code).data, '324 550');
    expect(find.text('GitHub'), findsOneWidget);
    expect(find.text('edo@example.com'), findsOneWidget);
    // 10 seconds left on the clock.
    expect(find.text('10'), findsOneWidget);

    // Avatar, then the texts, then the countdown; code under the name.
    final avatar = tester.getRect(find.text('G'));
    final title = tester.getRect(find.text('GitHub'));
    final codeRect = tester.getRect(code);
    final ring = tester.getRect(find.text('10'));
    expect(avatar.right, lessThan(title.left));
    expect(codeRect.left, title.left);
    expect(codeRect.top, greaterThan(title.bottom));
    expect(ring.left, greaterThan(codeRect.right));
    expect(ring.right, lessThanOrEqualTo(360));

    // The counter-based account has a "next code" button instead of a ring,
    // and sits below the first one.
    final next = tester.getRect(find.byTooltip('Next code'));
    expect(next.top, greaterThan(codeRect.bottom));
    expect(next.right, lessThanOrEqualTo(360));
    final before = tester.widget<Text>(find.byKey(const Key('code-bank'))).data;
    await tester.tap(find.byTooltip('Next code'));
    await tester.pumpAndSettle();
    expect(repo.account('bank').counter, 3);
    expect(
      tester.widget<Text>(find.byKey(const Key('code-bank'))).data,
      isNot(before),
    );
  });

  testWidgets('a tap copies the code privately and says when it clears', (
    tester,
  ) async {
    await tester.pumpWidget(app(const HomePage(), accounts: const [github]));
    await tester.pumpAndSettle();
    await tester.tap(find.text('GitHub'));
    await tester.pump();
    final (code, clearAfter) = bridge.copied.single;
    expect(code, hasLength(6));
    expect(int.tryParse(code), isNotNull);
    expect(clearAfter, const Duration(seconds: 30));
    expect(find.text('Code copied. It clears in 30 seconds.'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('hidden codes show as dots until tapped', (tester) async {
    final prefs = InMemoryPreferencesStore();
    await prefs.write('authenticator_hide_codes', 'true');
    await tester.pumpWidget(
      app(const HomePage(), accounts: const [github], prefs: prefs),
    );
    await tester.pumpAndSettle();
    final code = find.byKey(const Key('code-gh'));
    expect(tester.widget<Text>(code).data, '••• •••');
    await tester.tap(find.text('GitHub'));
    await tester.pump();
    // The real clock is past the test clock, so the copy leaves the dots;
    // what matters is that the copied code is the real one.
    expect(bridge.copied.single.$1, isNot(contains('•')));
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('search narrows the list', (tester) async {
    await tester.pumpWidget(
      app(const HomePage(), accounts: const [github, bank]),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('search-toggle')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('search-field')), 'ban');
    await tester.pumpAndSettle();
    expect(find.text('Bank'), findsOneWidget);
    expect(find.text('GitHub'), findsNothing);
    await tester.enterText(find.byKey(const Key('search-field')), 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('Nothing found'), findsOneWidget);
    await tester.tap(find.byKey(const Key('search-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('GitHub'), findsOneWidget);
  });

  testWidgets('add by typing the key: checked, saved, and shown', (
    tester,
  ) async {
    phone(tester);
    await tester.pumpWidget(app(const HomePage()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-account')));
    await tester.pumpAndSettle();
    // The four ways to add, one under the other, each a full row.
    final ways = [
      for (final k in ['add-scan', 'add-picture', 'add-manual', 'add-import'])
        tester.getRect(find.byKey(Key(k))),
    ];
    for (var i = 1; i < ways.length; i++) {
      expect(ways[i].top, greaterThanOrEqualTo(ways[i - 1].bottom));
    }
    expect(ways.last.bottom, lessThanOrEqualTo(740));
    await tester.tap(find.byKey(const Key('add-manual')));
    await tester.pumpAndSettle();

    // Save sits in the top bar at the end, not stretched across it.
    final save = tester.getRect(find.byKey(const Key('save-account')));
    expect(save.width, lessThan(160));
    expect(save.right, lessThanOrEqualTo(360));
    expect(save.left, greaterThan(180));

    // Nothing typed: both problems are named, nothing is saved.
    await tester.tap(find.byKey(const Key('save-account')));
    await tester.pumpAndSettle();
    expect(find.text('Type the service or the account'), findsOneWidget);
    expect(
      find.text('A key has only the letters A to Z and the digits 2 to 7'),
      findsOneWidget,
    );
    expect(repo.accounts, isEmpty);

    await tester.enterText(find.byKey(const Key('field-issuer')), 'GitHub');
    await tester.enterText(find.byKey(const Key('field-name')), 'edo');
    await tester.enterText(
      find.byKey(const Key('field-secret')),
      'jbsw y3dp ehpk 3pxp',
    );
    await tester.tap(find.byKey(const Key('save-account')));
    await tester.pumpAndSettle();

    final saved = repo.accounts.single;
    expect(saved.issuer, 'GitHub');
    expect(saved.name, 'edo');
    expect(saved.secret, testSecret);
    expect(saved.id, isNotEmpty);
    expect(saved.order, 1);
    // Back on the list, with its code.
    expect(
      tester.widget<Text>(find.byKey(Key('code-${saved.id}'))).data,
      '324 550',
    );
  });

  testWidgets('the same key twice is not added again', (tester) async {
    await tester.pumpWidget(app(const HomePage(), accounts: const [github]));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-account')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-manual')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('field-issuer')), 'Copy');
    await tester.enterText(find.byKey(const Key('field-secret')), testSecret);
    await tester.tap(find.byKey(const Key('save-account')));
    await tester.pump();
    await tester.pump();
    expect(find.text('This account is already here'), findsOneWidget);
    expect(repo.accounts, hasLength(1));
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('long press: edit, pin, and trash with undo', (tester) async {
    await tester.pumpWidget(
      app(const HomePage(), accounts: const [github, bank]),
    );
    await tester.pumpAndSettle();

    // Pin the second account: it moves above the first.
    await tester.longPress(find.text('Bank'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('menu-pin')));
    await tester.pumpAndSettle();
    expect(repo.account('bank').pinned, isTrue);
    expect(
      tester.getRect(find.text('Bank')).top,
      lessThan(tester.getRect(find.text('GitHub')).top),
    );

    // Edit: the name changes, the key cannot be changed here.
    await tester.longPress(find.text('GitHub'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('menu-edit')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('field-secret')), findsNothing);
    await tester.enterText(
      find.byKey(const Key('field-issuer')),
      'GitHub work',
    );
    await tester.tap(find.byKey(const Key('save-account')));
    await tester.pumpAndSettle();
    expect(repo.account('gh').issuer, 'GitHub work');
    expect(repo.account('gh').secret, testSecret);

    // Trash, then undo.
    await tester.longPress(find.text('GitHub work'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('menu-trash')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    expect(repo.account('gh').trashed, isTrue);
    expect(find.byKey(const Key('code-gh')), findsNothing);
    expect(find.text('GitHub work moved to trash'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(repo.account('gh').trashed, isFalse);
    expect(find.byKey(const Key('code-gh')), findsOneWidget);
  });

  testWidgets('the trash: put back, or delete for good after a warning', (
    tester,
  ) async {
    phone(tester);
    final now = DateTime.now();
    await tester.pumpWidget(
      app(
        const TrashPage(),
        accounts: [
          github.copyWith(
            trashedAt: () => now.subtract(const Duration(days: 3)),
          ),
          bank.copyWith(trashedAt: () => now),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Deleted in 27 days'), findsOneWidget);
    expect(find.textContaining('Deleted in 30 days'), findsOneWidget);
    // Both buttons of a row are on screen, side by side.
    final restore = tester.getRect(find.byTooltip('Put back').first);
    final delete = tester.getRect(find.byTooltip('Delete forever').first);
    expect(restore.right, lessThanOrEqualTo(delete.left));
    expect(delete.right, lessThanOrEqualTo(360));

    await tester.tap(find.byTooltip('Put back').first);
    await tester.pumpAndSettle();
    expect(repo.account('gh').trashed, isFalse);

    await tester.tap(find.byTooltip('Delete forever'));
    await tester.pumpAndSettle();
    expect(find.text('Delete Bank forever?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repo.accounts, hasLength(2));
    await tester.tap(find.byTooltip('Delete forever'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete forever'));
    await tester.pumpAndSettle();
    expect([for (final a in repo.accounts) a.id], ['gh']);
    expect(find.text('The trash is empty'), findsOneWidget);
  });

  testWidgets('old trash is emptied when the app opens', (tester) async {
    final now = DateTime.now();
    await tester.pumpWidget(
      app(
        const HomePage(),
        accounts: [
          github.copyWith(
            trashedAt: () => now.subtract(const Duration(days: 31)),
          ),
          bank.copyWith(
            trashedAt: () => now.subtract(const Duration(days: 29)),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect([for (final a in repo.accounts) a.id], ['bank']);
  });

  testWidgets('import: pasted links are added, duplicates skipped', (
    tester,
  ) async {
    phone(tester);
    await tester.pumpWidget(app(const ImportPage(), accounts: const [github]));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('import-paste')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('paste-links')),
      '${OtpAuth.format(github)}\n'
      'otpauth://totp/Mail:me?secret=GEZDGNBVGY3TQOJQ&issuer=Mail',
    );
    // The two buttons of the dialog are side by side, both visible.
    final cancel = tester.getRect(find.text('Cancel'));
    final ok = tester.getRect(find.byKey(const Key('paste-ok')));
    expect(cancel.right, lessThanOrEqualTo(ok.left));
    expect(ok.width, lessThan(200));
    await tester.tap(find.byKey(const Key('paste-ok')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(repo.accounts, hasLength(2));
    expect(find.text('Added 1. 1 were already here.'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('import: a locked file asks for its password, again when wrong', (
    tester,
  ) async {
    await tester.pumpWidget(app(const ImportPage()));
    await tester.pumpAndSettle();
    // A real backup, made outside the fake clock of the test.
    final text = await tester.runAsync(
      () => BackupFileForTest.make(const [github, bank]),
    );
    files.toPick = ('backup.ztauth', utf8.encode(text!));

    Future<void> settle() async {
      // The key is worked out off the fake clock.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pumpAndSettle();
    }

    await tester.tap(find.byKey(const Key('import-file')));
    await settle();
    expect(find.text('This file is locked'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('password')), 'wrong');
    await tester.tap(find.byKey(const Key('password-ok')));
    await settle();
    expect(find.text('Wrong password'), findsOneWidget);
    expect(repo.accounts, isEmpty);
    await tester.enterText(find.byKey(const Key('password')), 'backup-pass');
    await tester.tap(find.byKey(const Key('password-ok')));
    await settle();
    expect(repo.accounts, hasLength(2));
    expect(find.text('Added 2 accounts'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('import: a file that is not an export says so', (tester) async {
    await tester.pumpWidget(app(const ImportPage()));
    await tester.pumpAndSettle();
    files.toPick = ('holiday.txt', utf8.encode('see you in July'));
    await tester.tap(find.byKey(const Key('import-file')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      find.text("This isn't a file ZT Authenticator knows"),
      findsOneWidget,
    );
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('settings: the app rows, and an encrypted backup that opens', (
    tester,
  ) async {
    phone(tester);
    // The app's own rows, as the shared settings screen shows them.
    await tester.pumpWidget(
      app(
        Scaffold(
          body: ListView(
            children: const [AppSettingsRows(), BackupSettingsRows()],
          ),
        ),
        accounts: [
          github,
          bank,
          const Account(
            id: 'old',
            issuer: 'Old',
            secret: 'MFRGGZDFMZTWQ2LK',
          ).copyWith(trashedAt: () => DateTime.now()),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('setting-trash')),
        matching: find.text('1 account'),
      ),
      findsOneWidget,
    );

    final hide = find.byKey(const Key('setting-hide-codes'));
    await tester.tap(hide);
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(hide).value, isTrue);

    final clipboard = find.byKey(const Key('setting-clipboard'));
    expect(
      find.descendant(of: clipboard, matching: find.text('After 30 seconds')),
      findsOneWidget,
    );
    await tester.tap(clipboard);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Never'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: clipboard, matching: find.text('Never')),
      findsOneWidget,
    );

    final export = find.byKey(const Key('setting-export'));
    await tester.tap(export);
    await tester.pumpAndSettle();
    // A new password: too short and mismatched are both refused.
    await tester.enterText(find.byKey(const Key('password')), 'short');
    await tester.enterText(find.byKey(const Key('password-again')), 'short');
    await tester.tap(find.byKey(const Key('password-ok')));
    await tester.pumpAndSettle();
    expect(find.text('At least 8 characters'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('password')), 'long enough 1');
    await tester.enterText(
      find.byKey(const Key('password-again')),
      'long enough 2',
    );
    await tester.tap(find.byKey(const Key('password-ok')));
    await tester.pumpAndSettle();
    expect(find.text("The two don't match"), findsOneWidget);
    expect(files.saved, isEmpty);
    await tester.enterText(
      find.byKey(const Key('password-again')),
      'long enough 1',
    );
    await tester.tap(find.byKey(const Key('password-ok')));
    // 600,000 rounds, off the fake clock.
    for (var i = 0; i < 100 && files.saved.isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle(const Duration(seconds: 5));

    final (name, bytes) = files.saved.single;
    expect(
      name,
      matches(RegExp(r'^zt-authenticator-\d{4}-\d\d-\d\d\.ztauth$')),
    );
    final text = utf8.decode(bytes);
    expect(text, isNot(contains(testSecret)));
    final back = await tester.runAsync(
      () => Importer.read(text, password: 'long enough 1'),
    );
    expect([for (final a in back!.accounts) a.id], ['old', 'gh', 'bank']);
    // What was in the trash is still in the trash after a restore.
    expect(back.accounts.first.trashed, isTrue);
  });
}
