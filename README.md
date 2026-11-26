# Zero-Trust Authenticator

Sign-in codes (two-step verification) for your accounts, end-to-end
encrypted and synced across your devices. On the phone it is called **ZT
Authenticator**; in stores and on release pages, **Zero-Trust
Authenticator**. Same account, settings and look as the other Zero-Trust
apps, built on [Zero-Trust-Core](https://github.com/EdoSag/Zero-Trust-Core).
Part of the [Zero-Trust suite](https://zerotrust.bz).

## What it does

- **Codes:** time based (TOTP, RFC 6238), counter based (HOTP, RFC 4226) and
  Steam Guard. SHA-1, SHA-256 and SHA-512, 6 to 8 digits, any period.
- **Adding:** scan the QR code a service shows, pick a picture of one (read
  on the phone), type the key, or open an `otpauth://` link (the app asks
  before adding).
- **Import** from Google Authenticator (its export QR codes), Aegis and 2FAS
  (plain and password-protected files), Ente Auth, Bitwarden, andOTP and
  FreeOTP+. The format is recognised from the file.
- **Encrypted backup file** (`.ztauth`): every account in one file, locked
  with a password (PBKDF2-HMAC-SHA256, 600,000 rounds, AES-256-GCM). The
  format is described in `lib/transfer/backup_file.dart`.
- **Codes typed for you:** on a field that asks for a code, ZT Keyboard
  shows a chip that opens this app; the code of the account that belongs to
  that app or site goes back and is typed. The first time you pick the
  account, after that it answers on its own. See "Entering codes" below.
- **Warning before a code goes to the wrong place:** an account saved for
  `github.com` asked for by another site gets a warning first. A fake page
  that asks for your code is how these accounts are stolen.
- **Private by default:** screenshots and the recent-apps preview are
  blocked, a copied code is marked sensitive and cleared after 30 seconds
  (15, 60 or never), codes can be hidden until tapped, and the app locks
  after one minute away.
- **Groups:** put accounts in groups ("Work", "Games") from an account's
  menu, filter the list by group, and rename, reorder or delete groups in
  Settings. Deleting a group keeps its accounts.
- **Next code:** in a code's last five seconds the one that follows is
  shown under it.
- **Clock check** (Settings): codes are made from the time, so a phone
  whose clock is off makes codes that services refuse. The check compares
  the phone's clock with the Zero-Trust server's and says by how much it
  is off.
- **Quick ways in** (Android): a Quick Settings tile that opens the app
  from any screen, a home screen widget (open the codes, or the scanner),
  and "Scan QR code" when you press and hold the app's icon. None of them
  shows a code, an account or how many there are: codes show in the app,
  after unlocking.
- Search, pin to top, notes, the service's recovery codes kept beside the
  account, a trash that keeps deleted accounts for 30 days, show an account
  as a QR code to move it to another device.

## Privacy

Like every Zero-Trust app, it is zero-knowledge: your data is encrypted on
your device, with keys made from your password, before anything is sent.
The server stores only ciphertext and your password itself is never
sent, so neither we nor anyone who breaks into the server can read your
data. The recovery key shown at sign-up is the only way back in if you
forget the password. How the keys work:
[Zero-Trust-Core](https://github.com/EdoSag/Zero-Trust-Core#key-hierarchy) and
[zerotrust.bz/security](https://zerotrust.bz/security/).

- The server only ever holds ciphertext; it cannot make a code. Codes are
  worked out on the phone and nothing is sent anywhere to make or show one.
- Service logos are never downloaded: fetching one would tell a server
  which services you use.
- Screenshots and the recent-apps preview are blocked, and a copied code is
  marked sensitive and cleared.
- The `.ztauth` backup file is encrypted with the password you give it.

## One account, one core

One Zero-Trust account opens every app in the suite. Sign-in, unlock
(fingerprint or face, auto-lock), the recovery key, settings, the look,
sync and languages come from
[Zero-Trust-Core](https://github.com/EdoSag/Zero-Trust-Core), so they work
the same in every app. Accounts made before the core still sign in and
see their data.

## Install

Android: get the latest signed APK from this repository's
[Releases](https://github.com/EdoSag/Zero-Trust-Authenticator/releases/latest),
or from [zerotrust.bz/install](https://zerotrust.bz/install/#authenticator),
which also shows each file's SHA-256, the signing fingerprint and an
Obtainium link. GitHub Releases are the main way the apps are published.

Builds from GitHub check for a newer release themselves (Settings > About,
one anonymous request a day, can be turned off). Every Zero-Trust app is signed
with the same key, and Android only installs an update signed with it.

## Languages

English and Hebrew, with right-to-left layout. Choose under
Settings > Appearance > Language.

## How it is built

- Accounts are items in the shared `vault_items` table, sealed on the phone
  with the Authenticator's own key (`app = 'authenticator'`): kinds
  `account` and `group`. No database change was needed. The server only
  ever holds ciphertext; it cannot make a code.
- Codes are worked out on the phone (`lib/otp/`), checked against the RFC
  test values. Nothing is sent anywhere to make or show a code.
- Service icons are letters drawn in the app. Logos are never downloaded:
  fetching one would tell a server which services you use.
- The built-in list of services (`lib/links/service_directory.dart`) only
  suggests which account a site or app wants and powers the warning. A code
  goes back without asking only for an account you picked for that place
  before.

## Entering codes (ZT Keyboard)

`MainActivity` answers `bz.zerotrust.action.PICK_TEXT` with the category
`bz.zerotrust.category.ONE_TIME_CODE`:

- Only for a caller signed with this app's own key (`CodePick.kt`), and only
  when it opened the screen for an answer (never from `onNewIntent`).
- Asked with `bz.zerotrust.extra.FOR_PACKAGE` (the app being typed into) and,
  when known, `bz.zerotrust.extra.FOR_DOMAIN` (the site).
- Answers `bz.zerotrust.extra.TEXT` (digits only) and
  `bz.zerotrust.extra.VALID_UNTIL` (milliseconds since 1970; absent for
  counter-based codes). A code with less than 3 seconds left is not sent:
  the app waits for the next one.
- The vault is unlocked as usual first. The key never leaves the app.
- A browser without a site says nothing about where the code goes, so a
  pick made there is not remembered.

## Entering codes (Android autofill)

Optional, off until turned on in Settings ("Offer codes in other apps and
browsers"), which opens Android's own screen for choosing the autofill app.

- `CodeAutofillService` looks for a field that asks for a one-time code
  (`CodeFields.kt`: the page's or app's own hint such as
  `autocomplete="one-time-code"`, or a field name that says so) and offers
  one suggestion, "Code from ZT Authenticator", under the field or in the
  keyboard's suggestion row. It holds no keys and makes no codes.
- Tapping it opens `AutofillCodeActivity` (not exported): unlock as usual,
  pick the account (or the one already given to that site answers on its
  own), and Android fills the code in. Split boxes get one character each.
- In a browser the browser names the site, so a pick is remembered for the
  site and the wrong-place warning works there. A site named by any other
  app is not believed (`CodeRequest.fromDevice`); that app is treated as
  itself.
- Android lets one app be the autofill app. While it is ZT Authenticator, a
  password manager no longer fills in passwords through autofill. The
  keyboard chip above has no such cost.
- Chrome and Vanadium only ask the phone's autofill app when their own
  setting allows it: Settings, Autofill services (or Passwords and
  autofill), "Autofill using another service".
- It fills codes only and never saves anything from other apps.

## Build from source

Flutter 3.47.9, the version CI pins (3.50 deprecates `material.dart` and
fails analyze).

First create a file named `.env` in the project folder. It is not committed
(CI writes its own) and it is bundled into the APK, so it holds public client
values only, never a service-role key:

```
SUPABASE_URL=https://<project>.supabase.co
SUPABASE_ANON_KEY=<publishable key>
```

Then:

```bash
flutter pub get
dart run zt_release_checks --app authenticator   # shared release checks
flutter analyze && flutter test test/
flutter run
```

Never add `cryptography_flutter`: it breaks the core's key derivation and
sign-in fails.

## Branches and releases

Work happens on `Dev`: pull requests target `Dev`, never `main`, and get a
test build. A release is one `Dev` → `main` pull request. Every push to
`main` runs the suite's release checks, builds a signed APK and a Google Play bundle
and publishes them as a GitHub Release named "Zero-Trust Authenticator"
(`.github/workflows/android-apk.yml`). The workflow needs the repository
secrets `ANDROID_KEYSTORE_BASE64` and `ANDROID_KEYSTORE_PASSWORD`, the
keystore shared by all Zero-Trust apps.

The keyboard handoff only works between apps signed with the same key. Play
Store text: `fastlane/metadata/android/` (English and Hebrew).

## Support and security

- Help centre: [zerotrust.bz/help](https://zerotrust.bz/help/). Questions and
  account deletion: support@zerotrust.bz.
- Security problems: please report them privately to cyber@zerotrust.bz. What
  the encryption does and doesn't protect against is on
  [zerotrust.bz/security](https://zerotrust.bz/security/).
- [Privacy policy](https://zerotrust.bz/privacy/) and
  [terms](https://zerotrust.bz/terms/).

## License

Copyright (C) 2026 Edo Sagron (https://zerotrust.bz)

Zero-Trust is open source under the [GNU Affero General Public License v3.0](LICENSE)
(AGPL-3.0-only), the same licence Signal uses.

- You may use, study, change and share the code, including in your own projects.
- If you share a changed version, or run it for other people over a network, you must
  publish your full source code under the same licence.
- This program comes with no warranty; see the licence for details.

Third-party libraries keep their own licences; the app lists them under
Settings > Open-source licences.

### Name and logo

The AGPL covers the code, not the brand. "Zero-Trust", "ZT", the app names and icons are
reserved. If you publish a fork, give it a different name and icon so nobody mistakes it
for an official Zero-Trust app.

### Servers

The official apps use the Zero-Trust servers. A fork must use its own backend (for
example its own Supabase project) and must not connect to the official servers.

### Contributing

Pull requests are welcome. By sending one you agree that your contribution is licensed
under the AGPL-3.0 and that the copyright holder may also license it under other terms,
including commercially. This keeps the project able to offer paid plans and other licences.
