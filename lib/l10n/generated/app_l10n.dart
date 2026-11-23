import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_l10n_en.dart';
import 'app_l10n_he.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppL10n
/// returned by `AppL10n.of(context)`.
///
/// Applications need to include `AppL10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_l10n.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppL10n.localizationsDelegates,
///   supportedLocales: AppL10n.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppL10n.supportedLocales
/// property.
abstract class AppL10n {
  AppL10n(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppL10n of(BuildContext context) {
    return Localizations.of<AppL10n>(context, AppL10n)!;
  }

  static const LocalizationsDelegate<AppL10n> delegate = _AppL10nDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('he'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'ZT Authenticator'**
  String get appTitle;

  /// No description provided for @accountHint.
  ///
  /// In en, this message translates to:
  /// **'you@example.com'**
  String get accountHint;

  /// No description provided for @accountLabel.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get accountLabel;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @addAccount.
  ///
  /// In en, this message translates to:
  /// **'Add account'**
  String get addAccount;

  /// No description provided for @addFromLinkTitle.
  ///
  /// In en, this message translates to:
  /// **'Add this account?'**
  String get addFromLinkTitle;

  /// No description provided for @addFromLinkOne.
  ///
  /// In en, this message translates to:
  /// **'A link asked to add {name} to ZT Authenticator. Add it only if you opened the link yourself just now.'**
  String addFromLinkOne(String name);

  /// No description provided for @addFromLinkMany.
  ///
  /// In en, this message translates to:
  /// **'A link asked to add {count} accounts to ZT Authenticator. Add them only if you opened the link yourself just now.'**
  String addFromLinkMany(int count);

  /// No description provided for @addedOne.
  ///
  /// In en, this message translates to:
  /// **'Added {name}'**
  String addedOne(String name);

  /// No description provided for @addedMany.
  ///
  /// In en, this message translates to:
  /// **'Added {count} accounts'**
  String addedMany(int count);

  /// No description provided for @addedSomeSkipped.
  ///
  /// In en, this message translates to:
  /// **'Added {added}. {skipped} were already here.'**
  String addedSomeSkipped(int added, int skipped);

  /// No description provided for @advanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get advanced;

  /// No description provided for @advancedHint.
  ///
  /// In en, this message translates to:
  /// **'Only if the service gave you other settings'**
  String get advancedHint;

  /// No description provided for @afterSeconds.
  ///
  /// In en, this message translates to:
  /// **'After {n} seconds'**
  String afterSeconds(int n);

  /// No description provided for @algorithm.
  ///
  /// In en, this message translates to:
  /// **'Algorithm'**
  String get algorithm;

  /// No description provided for @alreadyHere.
  ///
  /// In en, this message translates to:
  /// **'This account is already here'**
  String get alreadyHere;

  /// No description provided for @badKey.
  ///
  /// In en, this message translates to:
  /// **'This key can\'t make codes'**
  String get badKey;

  /// No description provided for @cameraRefused.
  ///
  /// In en, this message translates to:
  /// **'The camera isn\'t allowed. Allow it in the phone\'s settings, or pick a picture instead.'**
  String get cameraRefused;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @clearClipboard.
  ///
  /// In en, this message translates to:
  /// **'Clear a copied code'**
  String get clearClipboard;

  /// No description provided for @closeSearch.
  ///
  /// In en, this message translates to:
  /// **'Close search'**
  String get closeSearch;

  /// No description provided for @codeKind.
  ///
  /// In en, this message translates to:
  /// **'Kind of code'**
  String get codeKind;

  /// No description provided for @continueLabel.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel;

  /// No description provided for @copied.
  ///
  /// In en, this message translates to:
  /// **'Code copied'**
  String get copied;

  /// No description provided for @copiedClears.
  ///
  /// In en, this message translates to:
  /// **'Code copied. It clears in {n} seconds.'**
  String copiedClears(int n);

  /// No description provided for @couldNotLoad.
  ///
  /// In en, this message translates to:
  /// **'Your accounts couldn\'t be opened. Close the app and try again.'**
  String get couldNotLoad;

  /// No description provided for @couldNotSave.
  ///
  /// In en, this message translates to:
  /// **'That couldn\'t be saved. Try again.'**
  String get couldNotSave;

  /// No description provided for @counter.
  ///
  /// In en, this message translates to:
  /// **'Counter'**
  String get counter;

  /// No description provided for @daysLeft.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =0{Deleted today} =1{Deleted in 1 day} other{Deleted in {n} days}}'**
  String daysLeft(int n);

  /// No description provided for @deleteForever.
  ///
  /// In en, this message translates to:
  /// **'Delete forever'**
  String get deleteForever;

  /// No description provided for @deleteForeverTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete {name} forever?'**
  String deleteForeverTitle(String name);

  /// No description provided for @deleteForeverBody.
  ///
  /// In en, this message translates to:
  /// **'Its codes are gone for good, on all your devices. If the service still asks for a code, turn off two-step sign-in there first, or keep its recovery codes.'**
  String get deleteForeverBody;

  /// No description provided for @digits.
  ///
  /// In en, this message translates to:
  /// **'Digits'**
  String get digits;

  /// No description provided for @editAccount.
  ///
  /// In en, this message translates to:
  /// **'Edit account'**
  String get editAccount;

  /// No description provided for @emptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No accounts yet'**
  String get emptyTitle;

  /// No description provided for @emptyBody.
  ///
  /// In en, this message translates to:
  /// **'Turn on two-step sign-in at a service, then scan the QR code it shows. Your codes are encrypted on this phone before they sync, so only you can read them.'**
  String get emptyBody;

  /// No description provided for @exportTitle.
  ///
  /// In en, this message translates to:
  /// **'Encrypted backup file'**
  String get exportTitle;

  /// No description provided for @exportHint.
  ///
  /// In en, this message translates to:
  /// **'Every account in one file, locked with a password you pick'**
  String get exportHint;

  /// No description provided for @exportBody.
  ///
  /// In en, this message translates to:
  /// **'Pick a password for the file, at least 8 characters. Without it the file can\'t be opened, and nobody can reset it.'**
  String get exportBody;

  /// No description provided for @exportDone.
  ///
  /// In en, this message translates to:
  /// **'Backup saved'**
  String get exportDone;

  /// No description provided for @exportFailed.
  ///
  /// In en, this message translates to:
  /// **'The backup couldn\'t be saved'**
  String get exportFailed;

  /// No description provided for @filePasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'This file is locked'**
  String get filePasswordTitle;

  /// No description provided for @filePasswordBody.
  ///
  /// In en, this message translates to:
  /// **'Type the password it was saved with.'**
  String get filePasswordBody;

  /// No description provided for @hideCodes.
  ///
  /// In en, this message translates to:
  /// **'Hide codes until tapped'**
  String get hideCodes;

  /// No description provided for @hideCodesHint.
  ///
  /// In en, this message translates to:
  /// **'Codes show as dots. Tap an account to see and copy its code.'**
  String get hideCodesHint;

  /// No description provided for @howToExport.
  ///
  /// In en, this message translates to:
  /// **'How to get your accounts out of another app'**
  String get howToExport;

  /// No description provided for @howGoogle.
  ///
  /// In en, this message translates to:
  /// **'Menu, Transfer accounts, Export accounts. Scan each QR code it shows, or pick a screenshot of it.'**
  String get howGoogle;

  /// No description provided for @howAegis.
  ///
  /// In en, this message translates to:
  /// **'Settings, Import & Export, Export, Aegis (.json). Encrypted exports work too.'**
  String get howAegis;

  /// No description provided for @howTwoFas.
  ///
  /// In en, this message translates to:
  /// **'Settings, 2FAS Backup, Export. Files with a password work too.'**
  String get howTwoFas;

  /// No description provided for @howEnte.
  ///
  /// In en, this message translates to:
  /// **'Settings, Data, Export codes, Plain text.'**
  String get howEnte;

  /// No description provided for @howBitwarden.
  ///
  /// In en, this message translates to:
  /// **'Tools, Export vault, .json (not encrypted). Only the items with a code are added.'**
  String get howBitwarden;

  /// No description provided for @howOthers.
  ///
  /// In en, this message translates to:
  /// **'Export as a plain JSON file.'**
  String get howOthers;

  /// No description provided for @importTitle.
  ///
  /// In en, this message translates to:
  /// **'Import from another app'**
  String get importTitle;

  /// No description provided for @importHint.
  ///
  /// In en, this message translates to:
  /// **'Google Authenticator, Aegis, 2FAS, Ente Auth, Bitwarden and more'**
  String get importHint;

  /// No description provided for @importIntro.
  ///
  /// In en, this message translates to:
  /// **'Bring your accounts over. Nothing is uploaded: files and pictures are read on this phone.'**
  String get importIntro;

  /// No description provided for @importFile.
  ///
  /// In en, this message translates to:
  /// **'Choose a backup file'**
  String get importFile;

  /// No description provided for @importFileHint.
  ///
  /// In en, this message translates to:
  /// **'From ZT Authenticator, Aegis, 2FAS, Ente Auth, Bitwarden, andOTP or FreeOTP+'**
  String get importFileHint;

  /// No description provided for @importScanHint.
  ///
  /// In en, this message translates to:
  /// **'A service\'s setup code, or Google Authenticator\'s export codes'**
  String get importScanHint;

  /// No description provided for @keyLabel.
  ///
  /// In en, this message translates to:
  /// **'Key'**
  String get keyLabel;

  /// No description provided for @keyHelp.
  ///
  /// In en, this message translates to:
  /// **'The letters and digits the service shows under \"Can\'t scan the code?\" or \"Enter a setup key\".'**
  String get keyHelp;

  /// No description provided for @keyInvalid.
  ///
  /// In en, this message translates to:
  /// **'A key has only the letters A to Z and the digits 2 to 7'**
  String get keyInvalid;

  /// No description provided for @kindTime.
  ///
  /// In en, this message translates to:
  /// **'Time based (most services)'**
  String get kindTime;

  /// No description provided for @kindCounter.
  ///
  /// In en, this message translates to:
  /// **'Counter based'**
  String get kindCounter;

  /// No description provided for @kindSteam.
  ///
  /// In en, this message translates to:
  /// **'Steam'**
  String get kindSteam;

  /// No description provided for @mismatchTitle.
  ///
  /// In en, this message translates to:
  /// **'This doesn\'t look right'**
  String get mismatchTitle;

  /// No description provided for @mismatchBodySite.
  ///
  /// In en, this message translates to:
  /// **'{account} is saved for {home}, but the code was asked for by {target}. A fake page that asks for your code is how accounts get stolen. Send it only if you\'re sure.'**
  String mismatchBodySite(String account, String home, String target);

  /// No description provided for @mismatchBodyApp.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t used {account} in {target} before, and it isn\'t the app that normally asks for it. A fake screen that asks for your code is how accounts get stolen. Send it only if you\'re sure.'**
  String mismatchBodyApp(String account, String target);

  /// No description provided for @mismatchSendAnyway.
  ///
  /// In en, this message translates to:
  /// **'Send anyway'**
  String get mismatchSendAnyway;

  /// No description provided for @moveToTrash.
  ///
  /// In en, this message translates to:
  /// **'Move to trash'**
  String get moveToTrash;

  /// No description provided for @movedToTrash.
  ///
  /// In en, this message translates to:
  /// **'{name} moved to trash'**
  String movedToTrash(String name);

  /// No description provided for @never.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get never;

  /// No description provided for @nextCode.
  ///
  /// In en, this message translates to:
  /// **'Next code'**
  String get nextCode;

  /// No description provided for @noQrInPicture.
  ///
  /// In en, this message translates to:
  /// **'No QR code found in that picture'**
  String get noQrInPicture;

  /// No description provided for @notAccountQr.
  ///
  /// In en, this message translates to:
  /// **'That isn\'t an account code'**
  String get notAccountQr;

  /// No description provided for @note.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get note;

  /// No description provided for @nothingFound.
  ///
  /// In en, this message translates to:
  /// **'Nothing found'**
  String get nothingFound;

  /// No description provided for @nothingToAdd.
  ///
  /// In en, this message translates to:
  /// **'There were no accounts in there'**
  String get nothingToAdd;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @passwordAgain.
  ///
  /// In en, this message translates to:
  /// **'Password again'**
  String get passwordAgain;

  /// No description provided for @passwordRequired.
  ///
  /// In en, this message translates to:
  /// **'Type the password'**
  String get passwordRequired;

  /// No description provided for @passwordTooShort.
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters'**
  String get passwordTooShort;

  /// No description provided for @passwordsDiffer.
  ///
  /// In en, this message translates to:
  /// **'The two don\'t match'**
  String get passwordsDiffer;

  /// No description provided for @pasteLinks.
  ///
  /// In en, this message translates to:
  /// **'Paste links'**
  String get pasteLinks;

  /// No description provided for @pasteLinksHint.
  ///
  /// In en, this message translates to:
  /// **'otpauth://totp/…'**
  String get pasteLinksHint;

  /// No description provided for @pasteLinksSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Lines that start with otpauth://'**
  String get pasteLinksSubtitle;

  /// No description provided for @periodInvalid.
  ///
  /// In en, this message translates to:
  /// **'Between 5 and 3600 seconds'**
  String get periodInvalid;

  /// No description provided for @periodSeconds.
  ///
  /// In en, this message translates to:
  /// **'A new code every (seconds)'**
  String get periodSeconds;

  /// No description provided for @pickLikely.
  ///
  /// In en, this message translates to:
  /// **'For {target}'**
  String pickLikely(String target);

  /// No description provided for @pickNoAccounts.
  ///
  /// In en, this message translates to:
  /// **'There are no accounts yet. Open ZT Authenticator and add one first.'**
  String get pickNoAccounts;

  /// No description provided for @pickOthers.
  ///
  /// In en, this message translates to:
  /// **'All accounts'**
  String get pickOthers;

  /// No description provided for @pickPicture.
  ///
  /// In en, this message translates to:
  /// **'Pick a picture of a QR code'**
  String get pickPicture;

  /// No description provided for @pickPictureHint.
  ///
  /// In en, this message translates to:
  /// **'A screenshot or a photo, read on this phone'**
  String get pickPictureHint;

  /// No description provided for @pickTitle.
  ///
  /// In en, this message translates to:
  /// **'Which code?'**
  String get pickTitle;

  /// No description provided for @pickTitleFor.
  ///
  /// In en, this message translates to:
  /// **'Code for {target}'**
  String pickTitleFor(String target);

  /// No description provided for @pin.
  ///
  /// In en, this message translates to:
  /// **'Pin to top'**
  String get pin;

  /// No description provided for @pinned.
  ///
  /// In en, this message translates to:
  /// **'Pinned'**
  String get pinned;

  /// No description provided for @qrWarning.
  ///
  /// In en, this message translates to:
  /// **'Anyone who scans or photographs this can make this account\'s codes. Show it only to move the account to a device of your own.'**
  String get qrWarning;

  /// No description provided for @recoveryCodes.
  ///
  /// In en, this message translates to:
  /// **'Recovery codes'**
  String get recoveryCodes;

  /// No description provided for @recoveryCodesHelp.
  ///
  /// In en, this message translates to:
  /// **'The one-time codes the service gave you for when you lose this phone, one per line. Encrypted with the account.'**
  String get recoveryCodesHelp;

  /// No description provided for @rememberFor.
  ///
  /// In en, this message translates to:
  /// **'Remember my choice for {target}'**
  String rememberFor(String target);

  /// No description provided for @restore.
  ///
  /// In en, this message translates to:
  /// **'Put back'**
  String get restore;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @scanHint.
  ///
  /// In en, this message translates to:
  /// **'Point the camera at the QR code the service shows'**
  String get scanHint;

  /// No description provided for @scanQr.
  ///
  /// In en, this message translates to:
  /// **'Scan a QR code'**
  String get scanQr;

  /// No description provided for @scanQrHint.
  ///
  /// In en, this message translates to:
  /// **'The code a service shows when you turn on two-step sign-in'**
  String get scanQrHint;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @sendingCode.
  ///
  /// In en, this message translates to:
  /// **'Sending the code for {name}'**
  String sendingCode(String name);

  /// No description provided for @serviceHint.
  ///
  /// In en, this message translates to:
  /// **'GitHub'**
  String get serviceHint;

  /// No description provided for @serviceLabel.
  ///
  /// In en, this message translates to:
  /// **'Service'**
  String get serviceLabel;

  /// No description provided for @serviceRequired.
  ///
  /// In en, this message translates to:
  /// **'Type the service or the account'**
  String get serviceRequired;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @showQr.
  ///
  /// In en, this message translates to:
  /// **'Show as QR code'**
  String get showQr;

  /// No description provided for @trash.
  ///
  /// In en, this message translates to:
  /// **'Trash'**
  String get trash;

  /// No description provided for @trashCount.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{1 account} other{{n} accounts}}'**
  String trashCount(int n);

  /// No description provided for @trashEmpty.
  ///
  /// In en, this message translates to:
  /// **'The trash is empty'**
  String get trashEmpty;

  /// No description provided for @trashHint.
  ///
  /// In en, this message translates to:
  /// **'Accounts stay here for 30 days, then they are deleted for good.'**
  String get trashHint;

  /// No description provided for @typeKey.
  ///
  /// In en, this message translates to:
  /// **'Type the key'**
  String get typeKey;

  /// No description provided for @typeKeyHint.
  ///
  /// In en, this message translates to:
  /// **'When there is no QR code to scan'**
  String get typeKeyHint;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @unknownFile.
  ///
  /// In en, this message translates to:
  /// **'This isn\'t a file ZT Authenticator knows'**
  String get unknownFile;

  /// No description provided for @unnamedAccount.
  ///
  /// In en, this message translates to:
  /// **'an account'**
  String get unnamedAccount;

  /// No description provided for @unpin.
  ///
  /// In en, this message translates to:
  /// **'Unpin'**
  String get unpin;

  /// No description provided for @unreadableFile.
  ///
  /// In en, this message translates to:
  /// **'The file is damaged or can\'t be read'**
  String get unreadableFile;

  /// No description provided for @usedIn.
  ///
  /// In en, this message translates to:
  /// **'Where its code goes without asking'**
  String get usedIn;

  /// No description provided for @usedInHelp.
  ///
  /// In en, this message translates to:
  /// **'Apps and sites you gave this code to from ZT Keyboard or autofill. Remove one to be asked again there.'**
  String get usedInHelp;

  /// No description provided for @wrongPassword.
  ///
  /// In en, this message translates to:
  /// **'Wrong password'**
  String get wrongPassword;

  /// No description provided for @autofillTitle.
  ///
  /// In en, this message translates to:
  /// **'Offer codes in other apps and browsers'**
  String get autofillTitle;

  /// No description provided for @autofillOffHint.
  ///
  /// In en, this message translates to:
  /// **'Android shows \"Code from ZT Authenticator\" on a field that asks for a sign-in code. Android lets one app fill in fields at a time, so while this is on your password manager no longer fills in passwords.'**
  String get autofillOffHint;

  /// No description provided for @autofillOnHint.
  ///
  /// In en, this message translates to:
  /// **'On: ZT Authenticator is this phone\'s autofill app. To have your password manager fill in passwords again, choose it as the autofill app in Android\'s settings.'**
  String get autofillOnHint;

  /// No description provided for @autofillUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This phone doesn\'t let apps fill in fields'**
  String get autofillUnavailable;
}

class _AppL10nDelegate extends LocalizationsDelegate<AppL10n> {
  const _AppL10nDelegate();

  @override
  Future<AppL10n> load(Locale locale) {
    return SynchronousFuture<AppL10n>(lookupAppL10n(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'he'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppL10nDelegate old) => false;
}

AppL10n lookupAppL10n(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppL10nEn();
    case 'he':
      return AppL10nHe();
  }

  throw FlutterError(
    'AppL10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
