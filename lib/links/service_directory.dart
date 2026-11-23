/// A well-known service: the names it goes by as an account's issuer, its
/// sites and its Android apps.
class KnownService {
  const KnownService(this.names, this.domains, [this.packages = const []]);

  /// Lower-case issuer names ("github").
  final List<String> names;
  final List<String> domains;
  final List<String> packages;
}

/// Where the codes of well-known services belong, shipped inside the app so
/// nothing is looked up online (a lookup would tell a server which services
/// someone uses). Used to suggest the right account for the app or site
/// asking, and to warn when a code is about to go somewhere else. The user's
/// own choices (`Account.packages`, `Account.domains`) always come first.
abstract final class ServiceDirectory {
  static const List<KnownService> services = [
    KnownService(
      ['google', 'gmail', 'youtube'],
      ['google.com', 'youtube.com'],
      [
        'com.google.android.gms',
        'com.google.android.gm',
        'com.google.android.youtube',
      ],
    ),
    KnownService(
      ['microsoft', 'outlook', 'office 365', 'microsoft 365', 'azure'],
      ['microsoft.com', 'live.com', 'microsoftonline.com', 'office.com'],
      ['com.microsoft.office.outlook', 'com.microsoft.teams'],
    ),
    KnownService(['github'], ['github.com'], ['com.github.android']),
    KnownService(['gitlab'], ['gitlab.com']),
    KnownService(
      ['bitbucket', 'atlassian', 'jira'],
      ['atlassian.com', 'bitbucket.org'],
    ),
    KnownService(['amazon'], ['amazon.com', 'amazon.co.uk', 'amazon.de'], [
      'com.amazon.mShop.android.shopping',
    ]),
    KnownService(
      ['aws', 'amazon web services'],
      ['aws.amazon.com', 'signin.aws.amazon.com'],
    ),
    KnownService(['facebook', 'meta'], ['facebook.com'], [
      'com.facebook.katana',
    ]),
    KnownService(['instagram'], ['instagram.com'], ['com.instagram.android']),
    KnownService(['twitter', 'x'], ['x.com', 'twitter.com'], [
      'com.twitter.android',
    ]),
    KnownService(['discord'], ['discord.com'], ['com.discord']),
    KnownService(['reddit'], ['reddit.com'], ['com.reddit.frontpage']),
    KnownService(['linkedin'], ['linkedin.com'], ['com.linkedin.android']),
    KnownService(['snapchat'], ['snapchat.com'], ['com.snapchat.android']),
    KnownService(['tiktok'], ['tiktok.com'], ['com.zhiliaoapp.musically']),
    KnownService(['twitch'], ['twitch.tv'], ['tv.twitch.android.app']),
    KnownService(['tumblr'], ['tumblr.com'], ['com.tumblr']),
    KnownService(['pinterest'], ['pinterest.com'], ['com.pinterest']),
    KnownService(['dropbox'], ['dropbox.com'], ['com.dropbox.android']),
    KnownService(['paypal'], ['paypal.com'], ['com.paypal.android.p2pmobile']),
    KnownService(
      ['proton', 'protonmail', 'proton mail'],
      ['proton.me', 'protonmail.com'],
      ['ch.protonmail.android'],
    ),
    KnownService(['tuta', 'tutanota'], ['tuta.com', 'tutanota.com']),
    KnownService(['steam'], ['steampowered.com', 'steamcommunity.com'], [
      'com.valvesoftware.android.steam.community',
    ]),
    KnownService(['epic games', 'epicgames'], ['epicgames.com']),
    KnownService(['ubisoft'], ['ubisoft.com']),
    KnownService(['electronic arts', 'ea'], ['ea.com']),
    KnownService(['nintendo'], ['nintendo.com']),
    KnownService(['playstation', 'sony'], ['playstation.com', 'sony.com']),
    KnownService(['binance'], ['binance.com'], ['com.binance.dev']),
    KnownService(['coinbase'], ['coinbase.com'], ['com.coinbase.android']),
    KnownService(['kraken'], ['kraken.com']),
    KnownService(['cloudflare'], ['cloudflare.com']),
    KnownService(['digitalocean'], ['digitalocean.com']),
    KnownService(['hetzner'], ['hetzner.com']),
    KnownService(['ovh', 'ovhcloud'], ['ovh.com', 'ovhcloud.com']),
    KnownService(['namecheap'], ['namecheap.com']),
    KnownService(['godaddy'], ['godaddy.com']),
    KnownService(['heroku'], ['heroku.com']),
    KnownService(['vercel'], ['vercel.com']),
    KnownService(['netlify'], ['netlify.com']),
    KnownService(['supabase'], ['supabase.com']),
    KnownService(['npm'], ['npmjs.com']),
    KnownService(['pypi'], ['pypi.org']),
    KnownService(['docker'], ['docker.com']),
    KnownService(['slack'], ['slack.com'], ['com.Slack']),
    KnownService(['zoom'], ['zoom.us'], ['us.zoom.videomeetings']),
    KnownService(['notion'], ['notion.so', 'notion.com'], ['notion.id']),
    KnownService(['figma'], ['figma.com']),
    KnownService(['linear'], ['linear.app']),
    KnownService(['stripe'], ['stripe.com']),
    KnownService(['paddle'], ['paddle.com']),
    KnownService(['shopify'], ['shopify.com'], ['com.shopify.mobile']),
    KnownService(['wordpress'], ['wordpress.com']),
    KnownService(['mailchimp'], ['mailchimp.com']),
    KnownService(['bitwarden'], ['bitwarden.com'], ['com.x8bit.bitwarden']),
    KnownService(['1password'], ['1password.com']),
    KnownService(['nextcloud'], ['nextcloud.com']),
    KnownService(['mega'], ['mega.nz', 'mega.io']),
    KnownService(['wise', 'transferwise'], ['wise.com'], [
      'com.transferwise.android',
    ]),
    KnownService(['revolut'], ['revolut.com'], ['com.revolut.revolut']),
    KnownService(['robinhood'], ['robinhood.com'], ['com.robinhood.android']),
    KnownService(['openai', 'chatgpt'], ['openai.com', 'chatgpt.com']),
    KnownService(['anthropic', 'claude'], ['anthropic.com', 'claude.ai']),
    KnownService(['zero-trust', 'zero trust', 'zt'], ['zerotrust.bz']),
  ];

  /// The service an account with [issuer] belongs to, or null. The issuer
  /// must be one of the names, or start with one followed by a space
  /// ("Google Workspace"), so "Xbox" is not taken for "X".
  static KnownService? find(String issuer) {
    final wanted = issuer.trim().toLowerCase();
    if (wanted.isEmpty) return null;
    for (final s in services) {
      for (final n in s.names) {
        if (wanted == n || wanted.startsWith('$n ')) return s;
      }
    }
    return null;
  }
}
