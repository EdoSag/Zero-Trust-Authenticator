# Zero-Trust Authenticator

Sign-in codes (two-step verification) for your accounts, end-to-end
encrypted and synced across your devices (on the phone: **ZT
Authenticator**). Same account, settings and look as the other Zero-Trust
apps, built on [Zero-Trust-Core](https://github.com/EdoSag/Zero-Trust-Core).

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
- English and Hebrew.

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

## Build

```bash
# .env (not committed; CI writes its own)
SUPABASE_URL=https://<project>.supabase.co
SUPABASE_ANON_KEY=<publishable key>

flutter pub get
dart run zt_release_checks --app authenticator   # shared release checks
flutter analyze && flutter test test/
flutter run
```

Flutter 3.47.9 (3.50 deprecates `material.dart` and fails analyze).

Pushing to `main` builds a signed APK and a Play bundle and publishes them as
a GitHub Release (`.github/workflows/android-apk.yml`). It needs the
repository secrets `ANDROID_KEYSTORE_BASE64` and `ANDROID_KEYSTORE_PASSWORD`,
the same keystore as the other Zero-Trust apps: the keyboard handoff only
works between apps signed with the same key. Pull requests target `Dev`;
releases are one `Dev` → `main` pull request.

Play Store text: `fastlane/metadata/android/` (English and Hebrew).

## License

AGPL-3.0. See [LICENSE](LICENSE).
