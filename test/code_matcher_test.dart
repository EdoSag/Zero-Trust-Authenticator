import 'package:flutter_test/flutter_test.dart';
import 'package:zerotrust_authenticator/links/code_matcher.dart';
import 'package:zerotrust_authenticator/links/service_directory.dart';
import 'package:zerotrust_authenticator/model/account.dart';

const github = Account(id: 'gh', issuer: 'GitHub', secret: 'JBSWY3DPEHPK3PXP');
const work = Account(
  id: 'work',
  issuer: 'Intranet',
  secret: 'JBSWY3DPEHPK3PXP',
  domains: ['intra.example.com'],
  packages: ['com.example.intranet'],
);
const unknown = Account(
  id: 'x',
  issuer: 'Tiny Forum',
  secret: 'JBSWY3DPEHPK3PXP',
);

void main() {
  test('a site is cleaned up before it is compared', () {
    expect(
      CodeMatcher.cleanDomain('https://www.GitHub.com:443/login?x=1'),
      'github.com',
    );
    expect(CodeMatcher.cleanDomain('user@Example.com.'), 'example.com');
    expect(CodeMatcher.sameSite('gist.github.com', 'github.com'), isTrue);
    expect(CodeMatcher.sameSite('github.com', 'github.com'), isTrue);
    // A look-alike is not a subdomain.
    expect(CodeMatcher.sameSite('notgithub.com', 'github.com'), isFalse);
    expect(CodeMatcher.sameSite('github.com.evil.io', 'github.com'), isFalse);
  });

  test('the built-in list knows the common services', () {
    expect(ServiceDirectory.find('GitHub')!.domains, contains('github.com'));
    expect(ServiceDirectory.find('github')!.domains, contains('github.com'));
    expect(ServiceDirectory.find('Tiny Forum'), isNull);
    // Every entry is usable: lower case sites, no empty lists of names.
    for (final s in ServiceDirectory.services) {
      expect(s.names, isNotEmpty);
      for (final d in s.domains) {
        expect(d, CodeMatcher.cleanDomain(d), reason: d);
      }
    }
  });

  test('how sure the match is: linked, suggested or not at all', () {
    const onGithub = CodeRequest(
      package: 'com.android.chrome',
      domain: 'github.com',
    );
    expect(CodeMatcher.strength(github, onGithub), LinkStrength.suggested);
    expect(CodeMatcher.strength(work, onGithub), LinkStrength.none);
    expect(
      CodeMatcher.strength(
        work,
        const CodeRequest(domain: 'https://intra.example.com/login'),
      ),
      LinkStrength.linked,
    );
    expect(
      CodeMatcher.strength(
        work,
        const CodeRequest(package: 'com.example.intranet'),
      ),
      LinkStrength.linked,
    );
  });

  test('a browser without a site says nothing about where the code goes', () {
    const request = CodeRequest(package: 'com.android.chrome');
    expect(request.knowsTarget, isFalse);
    expect(request.app, isNull);
    const linkedToChrome = Account(
      id: 'c',
      secret: 'JBSWY3DPEHPK3PXP',
      packages: ['com.android.chrome'],
    );
    expect(CodeMatcher.strength(linkedToChrome, request), LinkStrength.none);
    expect(CodeMatcher.onlyLinked([linkedToChrome], request), isNull);
  });

  test('the code goes back on its own only for exactly one linked account', () {
    const request = CodeRequest(package: 'com.example.intranet');
    expect(CodeMatcher.onlyLinked([github, work, unknown], request), work);
    // Suggested by the built-in list is not enough.
    expect(
      CodeMatcher.onlyLinked([github], const CodeRequest(domain: 'github.com')),
      isNull,
    );
    // Two accounts linked to the same place: ask.
    final second = work.copyWith(issuer: 'Intranet admin');
    final other = Account(
      id: 'work2',
      issuer: second.issuer,
      secret: 'GEZDGNBVGY3TQOJQ',
      packages: second.packages,
    );
    expect(CodeMatcher.onlyLinked([work, other], request), isNull);
    // One in the trash does not count.
    final trashed = Account(
      id: 'work2',
      secret: 'GEZDGNBVGY3TQOJQ',
      packages: const ['com.example.intranet'],
      trashedAt: DateTime(2026),
    );
    expect(CodeMatcher.onlyLinked([work, trashed], request), work);
  });

  test('likely accounts come first, the rest keep their order', () {
    const request = CodeRequest(domain: 'intra.example.com');
    final ranked = CodeMatcher.ranked([unknown, github, work], request);
    expect([for (final a in ranked) a.id], ['work', 'x', 'gh']);
  });

  test('a code about to go to the wrong place is noticed', () {
    // GitHub's code asked for by a look-alike site.
    final wrong = CodeMatcher.belongsElsewhere(
      github,
      const CodeRequest(domain: 'github.com.evil.io'),
    );
    expect(wrong?.site, 'github.com');
    expect(
      CodeMatcher.belongsElsewhere(
        github,
        const CodeRequest(domain: 'gist.github.com'),
      ),
      isNull,
    );
    // An account linked to an app, asked for by another app.
    final wrongApp = CodeMatcher.belongsElsewhere(
      work,
      const CodeRequest(package: 'com.evil.app'),
    );
    expect(wrongApp, isNotNull);
    expect(wrongApp!.site, isNull);
    // Nothing known about the account: nothing to warn about.
    expect(
      CodeMatcher.belongsElsewhere(
        unknown,
        const CodeRequest(domain: 'anything.example'),
      ),
      isNull,
    );
  });
}
