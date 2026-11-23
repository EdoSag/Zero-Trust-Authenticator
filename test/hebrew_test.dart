import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_authenticator/l10n/l10n.dart';
import 'package:zerotrust_authenticator/links/code_matcher.dart';
import 'package:zerotrust_authenticator/model/account.dart';
import 'package:zerotrust_authenticator/ui/edit_account_page.dart';
import 'package:zerotrust_authenticator/ui/home_page.dart';
import 'package:zerotrust_authenticator/ui/import_page.dart';
import 'package:zerotrust_authenticator/ui/pick_code_page.dart';
import 'package:zerotrust_authenticator/ui/settings_page.dart';
import 'package:zerotrust_authenticator/ui/trash_page.dart';

import 'support/app.dart';

const github = Account(
  id: 'gh',
  issuer: 'GitHub',
  name: 'edo@example.com',
  secret: testSecret,
  domains: ['github.com'],
  packages: ['com.github.android'],
  order: 1,
);

void phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(360 * 3, 740 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('Hebrew: right to left, but the code reads left to right', (
    tester,
  ) async {
    phone(tester);
    await tester.pumpWidget(
      app(
        const HomePage(),
        locale: ZtLanguages.hebrew,
        accounts: const [github],
      ),
    );
    await tester.pumpAndSettle();
    expect(
      Directionality.of(tester.element(find.byType(HomePage))),
      TextDirection.rtl,
    );
    // Mirrored row: avatar on the right, countdown on the left.
    final avatar = tester.getRect(find.text('G'));
    final title = tester.getRect(find.text('GitHub'));
    final ring = tester.getRect(find.text('10'));
    expect(avatar.left, greaterThan(title.right));
    expect(ring.right, lessThan(title.left));
    expect(ring.left, greaterThanOrEqualTo(0));
    // The digits keep their order.
    final code = tester.widget<Text>(find.byKey(const Key('code-gh')));
    expect(code.data, '324 550');
    expect(code.textDirection, TextDirection.ltr);
    expect(find.text('הוספת חשבון'), findsOneWidget);
    // The add button moves to the left corner.
    final add = tester.getRect(find.byKey(const Key('add-account')));
    expect(add.center.dx, lessThan(180));
    expect(add.left, greaterThanOrEqualTo(0));
  });

  testWidgets('Hebrew: every screen opens, translated, nothing overflows', (
    tester,
  ) async {
    phone(tester);
    final trashed = const Account(
      id: 'old',
      issuer: 'Old',
      secret: 'MFRGGZDFMZTWQ2LK',
    ).copyWith(trashedAt: () => DateTime.now());
    final screens = <String, Widget>{
      'עריכת חשבון': const EditAccountPage(account: github),
      'ייבוא מאפליקציה אחרת': const ImportPage(),
      'אשפה': const TrashPage(),
      'קוד עבור github.com': const PickCodePage(
        request: CodeRequest(domain: 'github.com.evil.io'),
      ),
      'הסתרת הקודים עד להקשה': Scaffold(
        body: ListView(
          children: const [AppSettingsRows(), BackupSettingsRows()],
        ),
      ),
    };
    for (final entry in screens.entries) {
      await tester.pumpWidget(
        app(
          KeyedSubtree(key: ValueKey(entry.key), child: entry.value),
          locale: ZtLanguages.hebrew,
          accounts: [github, trashed],
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: entry.key);
      if (entry.key.startsWith('קוד עבור')) {
        expect(find.text('קוד עבור github.com.evil.io'), findsOneWidget);
      } else {
        expect(find.text(entry.key), findsWidgets, reason: entry.key);
      }
    }
  });

  testWidgets('Hebrew: the add sheet and the account menu fit the screen', (
    tester,
  ) async {
    phone(tester);
    await tester.pumpWidget(
      app(
        const HomePage(),
        locale: ZtLanguages.hebrew,
        accounts: const [github],
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-account')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      tester.getRect(find.byKey(const Key('add-import'))).bottom,
      lessThanOrEqualTo(740),
    );
    await tester.tapAt(const Offset(180, 40));
    await tester.pumpAndSettle();
    await tester.longPress(find.text('GitHub'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      tester.getRect(find.byKey(const Key('menu-trash'))).bottom,
      lessThanOrEqualTo(740),
    );
    expect(find.text('העברה לאשפה'), findsOneWidget);
  });

  test('both languages have every text, with the same blanks to fill', () {
    final en = lookupAppL10n(const Locale('en'));
    final he = lookupAppL10n(const Locale('he'));
    // Texts with something filled in keep it in both languages.
    expect(en.addedOne('GitHub'), contains('GitHub'));
    expect(he.addedOne('GitHub'), contains('GitHub'));
    expect(
      he.mismatchBodySite('GitHub', 'github.com', 'evil.io'),
      contains('evil.io'),
    );
    expect(he.mismatchBodyApp('GitHub', 'Some app'), contains('Some app'));
    expect(he.copiedClears(30), contains('30'));
    // Plurals.
    expect(en.daysLeft(0), 'Deleted today');
    expect(en.daysLeft(1), 'Deleted in 1 day');
    expect(en.daysLeft(12), 'Deleted in 12 days');
    expect(he.daysLeft(1), 'יימחק בעוד יום');
    expect(he.daysLeft(2), 'יימחק בעוד יומיים');
    expect(he.daysLeft(12), 'יימחק בעוד 12 ימים');
    expect(en.trashCount(1), '1 account');
    expect(en.trashCount(3), '3 accounts');
    // No text was left in English by mistake (names of apps and examples
    // aside).
    expect(he.save, isNot(en.save));
    expect(he.emptyBody, isNot(en.emptyBody));
  });
}
