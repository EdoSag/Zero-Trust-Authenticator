import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_authenticator/model/account.dart';
import 'package:zerotrust_authenticator/platform/clock_check.dart';
import 'package:zerotrust_authenticator/ui/groups_page.dart';
import 'package:zerotrust_authenticator/ui/home_page.dart';
import 'package:zerotrust_authenticator/ui/scan_page.dart';
import 'package:zerotrust_authenticator/ui/settings_page.dart';

import 'support/app.dart';

const github = Account(
  id: 'gh',
  issuer: 'GitHub',
  name: 'edo@example.com',
  secret: testSecret,
  order: 1,
);
const mail = Account(
  id: 'mail',
  issuer: 'Mail',
  secret: 'GEZDGNBVGY3TQOJQ',
  order: 2,
);
const game = Account(
  id: 'game',
  issuer: 'Game',
  secret: 'MFRGGZDFMZTWQ2LK',
  order: 3,
);
const work = AccountGroup(id: 'work', name: 'Work', order: 1);
const play = AccountGroup(id: 'play', name: 'Play', order: 2);

void phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(360 * 3, 740 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

/// The home screen with [groups] already there.
Future<void> home(
  WidgetTester tester, {
  List<Account> accounts = const [github, mail, game],
  List<AccountGroup> groups = const [],
  Locale locale = ZtLanguages.english,
}) async {
  await tester.pumpWidget(
    app(const HomePage(), accounts: accounts, locale: locale),
  );
  await tester.pump();
  for (final g in groups) {
    await repo.saveGroup(g);
  }
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('no groups: no chip row, and the list starts under the bar', (
    tester,
  ) async {
    phone(tester);
    await home(tester);
    expect(find.byKey(const Key('group-chips')), findsNothing);
    expect(tester.getRect(find.byKey(const ValueKey('gh'))).top, 56);
  });

  testWidgets('a new group from an account\'s menu, then the chips filter', (
    tester,
  ) async {
    phone(tester);
    await home(tester);
    await tester.longPress(find.byKey(const ValueKey('gh')));
    await tester.pumpAndSettle();
    // The menu still fits the screen with its new row.
    final menuRow = tester.getRect(find.byKey(const Key('menu-group')));
    expect(menuRow.bottom, lessThanOrEqualTo(740));
    expect(
      tester.getRect(find.byKey(const Key('menu-trash'))).bottom,
      lessThanOrEqualTo(740),
    );
    await tester.tap(find.byKey(const Key('menu-group')));
    await tester.pumpAndSettle();
    expect(find.text('No group'), findsOneWidget);
    await tester.tap(find.byKey(const Key('group-new')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('group-name')), '  Work ');
    await tester.tap(find.byKey(const Key('group-name-ok')));
    await tester.pumpAndSettle();

    final group = repo.groups.single;
    expect(group.name, 'Work');
    expect(repo.account('gh').groupId, group.id);

    // The chips: under the bar, on one line, inside the screen.
    final all = tester.getRect(find.byKey(const Key('chip-all')));
    final chip = tester.getRect(find.byKey(Key('chip-${group.id}')));
    final edit = tester.getRect(find.byKey(const Key('edit-groups')));
    expect(all.top, greaterThanOrEqualTo(56));
    expect(all.left, greaterThanOrEqualTo(16));
    expect(chip.left, greaterThan(all.right));
    expect(edit.left, greaterThanOrEqualTo(chip.right));
    expect(edit.right, lessThanOrEqualTo(360));
    expect((chip.center.dy - all.center.dy).abs(), lessThan(1));
    // The list starts below them.
    expect(
      tester.getRect(find.byKey(const ValueKey('gh'))).top,
      greaterThanOrEqualTo(all.bottom),
    );

    await tester.tap(find.byKey(Key('chip-${group.id}')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('gh')), findsOneWidget);
    expect(find.byKey(const ValueKey('mail')), findsNothing);
    await tester.tap(find.byKey(const Key('chip-all')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mail')), findsOneWidget);
  });

  testWidgets('move between groups and out again; an empty group says so', (
    tester,
  ) async {
    phone(tester);
    await home(
      tester,
      accounts: [
        github.copyWith(groupId: () => 'work'),
        mail,
      ],
      groups: const [work, play],
    );
    await tester.tap(find.byKey(const Key('chip-play')));
    await tester.pumpAndSettle();
    expect(find.text('No accounts in this group yet'), findsOneWidget);

    await tester.tap(find.byKey(const Key('chip-work')));
    await tester.pumpAndSettle();
    await tester.longPress(find.byKey(const ValueKey('gh')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('menu-group')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('group-play')));
    await tester.pumpAndSettle();
    expect(repo.account('gh').groupId, 'play');
    expect(find.byKey(const ValueKey('gh')), findsNothing);

    await tester.tap(find.byKey(const Key('chip-play')));
    await tester.pumpAndSettle();
    await tester.longPress(find.byKey(const ValueKey('gh')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('menu-group')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('group-none')));
    await tester.pumpAndSettle();
    expect(repo.account('gh').groupId, isNull);
  });

  testWidgets('a group deleted while it is picked: back to every account', (
    tester,
  ) async {
    phone(tester);
    await home(
      tester,
      accounts: [
        github.copyWith(groupId: () => 'work'),
        mail,
      ],
      groups: const [work],
    );
    await tester.tap(find.byKey(const Key('chip-work')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mail')), findsNothing);
    await repo.deleteGroup('work');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('group-chips')), findsNothing);
    expect(find.byKey(const ValueKey('mail')), findsOneWidget);
    expect(find.byKey(const ValueKey('gh')), findsOneWidget);
  });

  testWidgets('the groups screen: add, rename, a taken name, delete', (
    tester,
  ) async {
    phone(tester);
    await tester.pumpWidget(
      app(
        const GroupsPage(),
        accounts: [
          github.copyWith(groupId: () => 'work'),
          mail,
        ],
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.textContaining('No groups yet'), findsOneWidget);
    await repo.saveGroup(work);
    await tester.pumpAndSettle();
    expect(find.text('1 account'), findsOneWidget);

    // The add button is in reach and inside the screen.
    final add = tester.getRect(find.byKey(const Key('add-group')));
    expect(add.right, lessThanOrEqualTo(360));
    expect(add.bottom, lessThanOrEqualTo(740));
    expect(add.width, lessThan(240));
    await tester.tap(find.byKey(const Key('add-group')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('group-name')), 'work');
    await tester.tap(find.byKey(const Key('group-name-ok')));
    await tester.pumpAndSettle();
    expect(
      find.text('There is already a group with this name'),
      findsOneWidget,
    );
    // The dialog's two buttons are side by side.
    final cancel = tester.getRect(find.text('Cancel'));
    final save = tester.getRect(find.text('Save'));
    expect(cancel.right, lessThanOrEqualTo(save.left));
    await tester.enterText(find.byKey(const Key('group-name')), 'Play');
    await tester.tap(find.byKey(const Key('group-name-ok')));
    await tester.pumpAndSettle();
    expect(repo.groups.map((g) => g.name), containsAll(['Work', 'Play']));
    expect(find.text('No accounts'), findsOneWidget);

    // A row: handle, name, then rename and delete, in that order.
    final row = tester.getRect(find.byKey(const Key('group-row-work')));
    final name = tester.getRect(find.text('Work'));
    final rename = tester.getRect(find.byKey(const Key('group-rename-work')));
    final delete = tester.getRect(find.byKey(const Key('group-delete-work')));
    expect(row.width, 360);
    expect(name.right, lessThanOrEqualTo(rename.left));
    expect(rename.right, lessThanOrEqualTo(delete.left));
    expect(delete.right, lessThanOrEqualTo(360));

    await tester.tap(find.byKey(const Key('group-rename-work')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('group-name')), 'Office');
    await tester.tap(find.byKey(const Key('group-name-ok')));
    await tester.pumpAndSettle();
    expect(find.text('Office'), findsOneWidget);

    await tester.tap(find.byKey(const Key('group-delete-work')));
    await tester.pumpAndSettle();
    expect(find.text('Delete Office?'), findsOneWidget);
    await tester.tap(find.text('Delete group'));
    await tester.pumpAndSettle();
    expect(repo.groups.map((g) => g.name), ['Play']);
    // The account is kept, without a group.
    expect(repo.account('gh').groupId, isNull);
  });

  testWidgets('reordering saves the new order', (tester) async {
    await tester.pumpWidget(app(const GroupsPage()));
    await tester.pump();
    await repo.saveGroup(work);
    await repo.saveGroup(play);
    await repo.reorderGroups(['play', 'work']);
    await tester.pumpAndSettle();
    final first = tester.getRect(find.text('Play'));
    final second = tester.getRect(find.text('Work'));
    expect(first.top, lessThan(second.top));
    final added = await repo.addGroup(' Later ');
    expect(added.name, 'Later');
    expect(added.order, 3);
    await tester.pumpAndSettle();
  });

  testWidgets('Hebrew: the chips run from the right', (tester) async {
    phone(tester);
    await home(tester, groups: const [work], locale: ZtLanguages.hebrew);
    final all = tester.getRect(find.byKey(const Key('chip-all')));
    final chip = tester.getRect(find.byKey(const Key('chip-work')));
    expect(find.text('הכול'), findsOneWidget);
    expect(all.right, lessThanOrEqualTo(360 - 16));
    expect(chip.right, lessThan(all.left));
  });

  testWidgets('in a code\'s last seconds the next code is shown too', (
    tester,
  ) async {
    phone(tester);
    // 21 seconds: one second left at the tests' moment. 30: ten left.
    final ending = github.copyWith(period: 21);
    await home(tester, accounts: [ending, mail]);
    final until = ending.validUntil(testNow)!;
    expect(until.difference(testNow).inSeconds, lessThanOrEqualTo(5));
    final next = ending.codeAt(until.add(const Duration(milliseconds: 1)));
    final line = find.byKey(const Key('next-gh'));
    expect(line, findsOneWidget);
    expect(
      tester.widget<Text>(line).data,
      'Next: \u2066${spacedCode(next)}\u2069',
    );
    // Under the code, inside the row.
    final code = tester.getRect(find.byKey(const Key('code-gh')));
    expect(tester.getRect(line).top, greaterThanOrEqualTo(code.bottom));
    expect(tester.getRect(line).right, lessThanOrEqualTo(360));
    // Not for a code with time to spare.
    expect(find.byKey(const Key('next-mail')), findsNothing);
  });

  group('the clock check', () {
    test('compares the middle of the question with the server\'s second', () {
      final sent = DateTime.utc(2026, 1, 1, 12, 0, 40);
      expect(
        clockOffset(
          sent: sent,
          received: sent.add(const Duration(milliseconds: 400)),
          serverDate: DateTime.utc(2026, 1, 1, 12),
        ),
        const Duration(seconds: 39, milliseconds: 700),
      );
      expect(
        clockOffset(
          sent: sent,
          received: sent,
          serverDate: DateTime.utc(2026, 1, 1, 12, 1, 30),
        ).inSeconds,
        -50,
      );
    });

    Future<void> check(WidgetTester tester, Duration? offset) async {
      phone(tester);
      await tester.pumpWidget(
        app(
          Scaffold(body: ListView(children: const [AppSettingsRows()])),
          clockCheck: () async => offset,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('setting-clock')));
      await tester.pumpAndSettle();
    }

    testWidgets('a clock that is right', (tester) async {
      await check(tester, const Duration(seconds: -3));
      expect(find.text('The clock is right'), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('clock-result')), findsNothing);
    });

    testWidgets('a clock that is off says by how much and what to do', (
      tester,
    ) async {
      await check(tester, const Duration(seconds: -95));
      expect(find.textContaining('95 seconds off'), findsOneWidget);
      expect(find.textContaining('automatic date and time'), findsOneWidget);
      // The message fits the screen.
      final dialog = tester.getRect(find.byKey(const Key('clock-result')));
      expect(dialog.left, greaterThanOrEqualTo(0));
      expect(dialog.right, lessThanOrEqualTo(360));
    });

    testWidgets('no answer from the server', (tester) async {
      await check(tester, null);
      expect(find.textContaining("Couldn't check the clock"), findsOneWidget);
    });
  });

  testWidgets('settings: groups row counts the groups and opens them', (
    tester,
  ) async {
    phone(tester);
    await tester.pumpWidget(
      app(Scaffold(body: ListView(children: const [AppSettingsRows()]))),
    );
    await tester.pump();
    final row = find.byKey(const Key('setting-groups'));
    expect(
      find.descendant(
        of: row,
        matching: find.text('Keep work, personal and other accounts apart'),
      ),
      findsOneWidget,
    );
    await repo.saveGroup(work);
    await repo.saveGroup(play);
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: row, matching: find.text('2 groups')),
      findsOneWidget,
    );
    // Every row is whole on the screen, one under the other.
    var bottom = 0.0;
    for (final key in const [
      'setting-hide-codes',
      'setting-clipboard',
      'setting-groups',
      'setting-clock',
      'setting-trash',
    ]) {
      final rect = tester.getRect(find.byKey(Key(key)));
      expect(rect.top, greaterThanOrEqualTo(bottom), reason: key);
      expect(rect.right, 360, reason: key);
      bottom = rect.bottom;
    }
    expect(bottom, lessThanOrEqualTo(740));
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(find.byType(GroupsPage), findsOneWidget);
  });

  testWidgets('the widget\'s scan button opens the scanner, once', (
    tester,
  ) async {
    final widget = app(const HomePage(), accounts: const [github]);
    bridge.startAction = 'scan';
    await tester.pumpWidget(widget);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    // A new screen is measured for one frame before it shows.
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(ScanPage), findsOneWidget);
    expect(bridge.startAction, isNull);
  });
}
