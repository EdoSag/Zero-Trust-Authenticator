import '../model/account.dart';
import 'service_directory.dart';

/// A code asked for from outside the app: by ZT Keyboard, ZT Browser or
/// Android autofill.
class CodeRequest {
  const CodeRequest({this.package, this.domain, this.appLabel});

  /// The request as the Kotlin side reports it (`pendingCodeRequest`).
  ///
  /// A site named by a Zero-Trust app (the keyboard handoff) is believed:
  /// only apps signed with the suite's key get that far. A site named by
  /// Android autofill is what the app on screen says it is showing, so it
  /// is believed from browsers only. Any other app could name a site it
  /// has nothing to do with to be handed that site's code without the
  /// wrong-place warning; such an app is treated as itself.
  factory CodeRequest.fromDevice(Map<Object?, Object?> raw) {
    String? text(String key) {
      final v = raw[key];
      return v is String && v.trim().isNotEmpty ? v.trim() : null;
    }

    final package = text('package');
    final fromAutofill = text('source') == 'autofill';
    return CodeRequest(
      package: package,
      domain: fromAutofill && !browsers.contains(package)
          ? null
          : text('domain'),
      appLabel: text('appLabel'),
    );
  }

  /// The Android app being typed into.
  final String? package;

  /// The site being typed into, when the asker knows it.
  final String? domain;

  /// The app's name, for the screen ("GitHub").
  final String? appLabel;

  bool get inBrowser => package != null && browsers.contains(package);

  /// The site, cleaned up, or null.
  String? get site {
    final d = domain;
    if (d == null) return null;
    final clean = CodeMatcher.cleanDomain(d);
    return clean.isEmpty ? null : clean;
  }

  /// The app the code is for, unless it is a browser: a browser shows any
  /// site, so the browser itself says nothing about where the code goes.
  String? get app => site == null && !inBrowser ? package : null;

  /// Whether it is known where the code is going.
  bool get knowsTarget => site != null || app != null;

  /// What to call the place asking: the site, or the app's name.
  String get targetName => site ?? appLabel ?? package ?? '';

  /// Browsers, by Android package. A code asked for from one of these
  /// without a site is never tied to the browser.
  static const browsers = {
    'dev.sagron.zerotrustbrowser',
    'com.android.chrome',
    'com.chrome.beta',
    'org.chromium.chrome',
    'app.vanadium.browser',
    'org.mozilla.firefox',
    'org.mozilla.firefox_beta',
    'org.mozilla.fenix',
    'org.mozilla.focus',
    'org.ironfoxoss.ironfox',
    'io.github.forkmaintainers.iceraven',
    'us.spotco.fennec_dos',
    'org.torproject.torbrowser',
    'com.brave.browser',
    'com.microsoft.emmx',
    'com.opera.browser',
    'com.opera.mini.native',
    'com.vivaldi.browser',
    'com.duckduckgo.mobile.android',
    'com.sec.android.app.sbrowser',
    'com.kiwibrowser.browser',
    'org.bromite.bromite',
    'org.cromite.cromite',
    'com.mi.globalbrowser',
    'com.huawei.browser',
  };
}

/// How sure it is that an account is the one a request wants.
enum LinkStrength {
  /// The user gave this account's code to this app or site before.
  linked,

  /// The built-in list says the account's service lives here.
  suggested,
  none,
}

/// Finds the account a [CodeRequest] is after, and notices when a code is
/// about to go somewhere it does not belong.
abstract final class CodeMatcher {
  /// "https://www.GitHub.com:443/login" -> "github.com".
  static String cleanDomain(String input) {
    var d = input.trim().toLowerCase();
    final scheme = d.indexOf('://');
    if (scheme >= 0) d = d.substring(scheme + 3);
    d = d.split(RegExp(r'[/?#]')).first;
    final at = d.lastIndexOf('@');
    if (at >= 0) d = d.substring(at + 1);
    if (!d.startsWith('[')) d = d.split(':').first;
    if (d.startsWith('www.')) d = d.substring(4);
    while (d.endsWith('.')) {
      d = d.substring(0, d.length - 1);
    }
    return d;
  }

  /// Whether the site [asked] is [saved] or one of its subdomains.
  static bool sameSite(String asked, String saved) =>
      asked == saved || asked.endsWith('.$saved');

  static LinkStrength strength(Account account, CodeRequest request) {
    final known = ServiceDirectory.find(account.issuer);
    final site = request.site;
    if (site != null) {
      if (account.domains.any((d) => sameSite(site, d))) {
        return LinkStrength.linked;
      }
      if (known != null && known.domains.any((d) => sameSite(site, d))) {
        return LinkStrength.suggested;
      }
      return LinkStrength.none;
    }
    final app = request.app;
    if (app != null) {
      if (account.packages.contains(app)) return LinkStrength.linked;
      if (known != null && known.packages.contains(app)) {
        return LinkStrength.suggested;
      }
    }
    return LinkStrength.none;
  }

  /// The one account the user already gave to this app or site, when there
  /// is exactly one: its code can go back without asking again.
  static Account? onlyLinked(List<Account> accounts, CodeRequest request) {
    Account? found;
    for (final a in accounts) {
      if (a.trashed || strength(a, request) != LinkStrength.linked) continue;
      if (found != null) return null;
      found = a;
    }
    return found;
  }

  /// [accounts] with the ones for this request first: linked, then
  /// suggested, then the rest in their own order.
  static List<Account> ranked(List<Account> accounts, CodeRequest request) {
    final live = [
      for (final a in accounts)
        if (!a.trashed) a,
    ];
    final rank = {for (final a in live) a.id: strength(a, request).index};
    final order = {for (var i = 0; i < live.length; i++) live[i].id: i};
    return live..sort((a, b) {
      final byRank = rank[a.id]!.compareTo(rank[b.id]!);
      return byRank != 0 ? byRank : order[a.id]!.compareTo(order[b.id]!);
    });
  }

  /// Set when [account] is known to belong somewhere other than where
  /// [request] is asking from; null when nothing is wrong (or nothing is
  /// known). A code typed into a look-alike site is how these accounts are
  /// stolen.
  static WrongPlace? belongsElsewhere(Account account, CodeRequest request) {
    final known = ServiceDirectory.find(account.issuer);
    final site = request.site;
    if (site != null) {
      final home = [...account.domains, ...?known?.domains];
      if (home.isEmpty || home.any((d) => sameSite(site, d))) return null;
      return WrongPlace(site: home.first);
    }
    final app = request.app;
    if (app != null) {
      final home = [...account.packages, ...?known?.packages];
      if (home.isEmpty || home.contains(app)) return null;
      return const WrongPlace();
    }
    return null;
  }
}

/// See [CodeMatcher.belongsElsewhere].
class WrongPlace {
  const WrongPlace({this.site});

  /// The site the account is saved for, when the request came from another
  /// site; null when it came from an app the account was never used in.
  final String? site;
}
