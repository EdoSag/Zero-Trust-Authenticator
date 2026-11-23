// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_l10n.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppL10nEn extends AppL10n {
  AppL10nEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'ZT Authenticator';

  @override
  String get accountHint => 'you@example.com';

  @override
  String get accountLabel => 'Account';

  @override
  String get add => 'Add';

  @override
  String get addAccount => 'Add account';

  @override
  String get addFromLinkTitle => 'Add this account?';

  @override
  String addFromLinkOne(String name) {
    return 'A link asked to add $name to ZT Authenticator. Add it only if you opened the link yourself just now.';
  }

  @override
  String addFromLinkMany(int count) {
    return 'A link asked to add $count accounts to ZT Authenticator. Add them only if you opened the link yourself just now.';
  }

  @override
  String addedOne(String name) {
    return 'Added $name';
  }

  @override
  String addedMany(int count) {
    return 'Added $count accounts';
  }

  @override
  String addedSomeSkipped(int added, int skipped) {
    return 'Added $added. $skipped were already here.';
  }

  @override
  String get advanced => 'Advanced';

  @override
  String get advancedHint => 'Only if the service gave you other settings';

  @override
  String afterSeconds(int n) {
    return 'After $n seconds';
  }

  @override
  String get algorithm => 'Algorithm';

  @override
  String get alreadyHere => 'This account is already here';

  @override
  String get badKey => 'This key can\'t make codes';

  @override
  String get cameraRefused =>
      'The camera isn\'t allowed. Allow it in the phone\'s settings, or pick a picture instead.';

  @override
  String get cancel => 'Cancel';

  @override
  String get clearClipboard => 'Clear a copied code';

  @override
  String get closeSearch => 'Close search';

  @override
  String get codeKind => 'Kind of code';

  @override
  String get continueLabel => 'Continue';

  @override
  String get copied => 'Code copied';

  @override
  String copiedClears(int n) {
    return 'Code copied. It clears in $n seconds.';
  }

  @override
  String get couldNotLoad =>
      'Your accounts couldn\'t be opened. Close the app and try again.';

  @override
  String get couldNotSave => 'That couldn\'t be saved. Try again.';

  @override
  String get counter => 'Counter';

  @override
  String daysLeft(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Deleted in $n days',
      one: 'Deleted in 1 day',
      zero: 'Deleted today',
    );
    return '$_temp0';
  }

  @override
  String get deleteForever => 'Delete forever';

  @override
  String deleteForeverTitle(String name) {
    return 'Delete $name forever?';
  }

  @override
  String get deleteForeverBody =>
      'Its codes are gone for good, on all your devices. If the service still asks for a code, turn off two-step sign-in there first, or keep its recovery codes.';

  @override
  String get digits => 'Digits';

  @override
  String get editAccount => 'Edit account';

  @override
  String get emptyTitle => 'No accounts yet';

  @override
  String get emptyBody =>
      'Turn on two-step sign-in at a service, then scan the QR code it shows. Your codes are encrypted on this phone before they sync, so only you can read them.';

  @override
  String get exportTitle => 'Encrypted backup file';

  @override
  String get exportHint =>
      'Every account in one file, locked with a password you pick';

  @override
  String get exportBody =>
      'Pick a password for the file, at least 8 characters. Without it the file can\'t be opened, and nobody can reset it.';

  @override
  String get exportDone => 'Backup saved';

  @override
  String get exportFailed => 'The backup couldn\'t be saved';

  @override
  String get filePasswordTitle => 'This file is locked';

  @override
  String get filePasswordBody => 'Type the password it was saved with.';

  @override
  String get hideCodes => 'Hide codes until tapped';

  @override
  String get hideCodesHint =>
      'Codes show as dots. Tap an account to see and copy its code.';

  @override
  String get howToExport => 'How to get your accounts out of another app';

  @override
  String get howGoogle =>
      'Menu, Transfer accounts, Export accounts. Scan each QR code it shows, or pick a screenshot of it.';

  @override
  String get howAegis =>
      'Settings, Import & Export, Export, Aegis (.json). Encrypted exports work too.';

  @override
  String get howTwoFas =>
      'Settings, 2FAS Backup, Export. Files with a password work too.';

  @override
  String get howEnte => 'Settings, Data, Export codes, Plain text.';

  @override
  String get howBitwarden =>
      'Tools, Export vault, .json (not encrypted). Only the items with a code are added.';

  @override
  String get howOthers => 'Export as a plain JSON file.';

  @override
  String get importTitle => 'Import from another app';

  @override
  String get importHint =>
      'Google Authenticator, Aegis, 2FAS, Ente Auth, Bitwarden and more';

  @override
  String get importIntro =>
      'Bring your accounts over. Nothing is uploaded: files and pictures are read on this phone.';

  @override
  String get importFile => 'Choose a backup file';

  @override
  String get importFileHint =>
      'From ZT Authenticator, Aegis, 2FAS, Ente Auth, Bitwarden, andOTP or FreeOTP+';

  @override
  String get importScanHint =>
      'A service\'s setup code, or Google Authenticator\'s export codes';

  @override
  String get keyLabel => 'Key';

  @override
  String get keyHelp =>
      'The letters and digits the service shows under \"Can\'t scan the code?\" or \"Enter a setup key\".';

  @override
  String get keyInvalid =>
      'A key has only the letters A to Z and the digits 2 to 7';

  @override
  String get kindTime => 'Time based (most services)';

  @override
  String get kindCounter => 'Counter based';

  @override
  String get kindSteam => 'Steam';

  @override
  String get mismatchTitle => 'This doesn\'t look right';

  @override
  String mismatchBodySite(String account, String home, String target) {
    return '$account is saved for $home, but the code was asked for by $target. A fake page that asks for your code is how accounts get stolen. Send it only if you\'re sure.';
  }

  @override
  String mismatchBodyApp(String account, String target) {
    return 'You haven\'t used $account in $target before, and it isn\'t the app that normally asks for it. A fake screen that asks for your code is how accounts get stolen. Send it only if you\'re sure.';
  }

  @override
  String get mismatchSendAnyway => 'Send anyway';

  @override
  String get moveToTrash => 'Move to trash';

  @override
  String movedToTrash(String name) {
    return '$name moved to trash';
  }

  @override
  String get never => 'Never';

  @override
  String get nextCode => 'Next code';

  @override
  String get noQrInPicture => 'No QR code found in that picture';

  @override
  String get notAccountQr => 'That isn\'t an account code';

  @override
  String get note => 'Note';

  @override
  String get nothingFound => 'Nothing found';

  @override
  String get nothingToAdd => 'There were no accounts in there';

  @override
  String get password => 'Password';

  @override
  String get passwordAgain => 'Password again';

  @override
  String get passwordRequired => 'Type the password';

  @override
  String get passwordTooShort => 'At least 8 characters';

  @override
  String get passwordsDiffer => 'The two don\'t match';

  @override
  String get pasteLinks => 'Paste links';

  @override
  String get pasteLinksHint => 'otpauth://totp/…';

  @override
  String get pasteLinksSubtitle => 'Lines that start with otpauth://';

  @override
  String get periodInvalid => 'Between 5 and 3600 seconds';

  @override
  String get periodSeconds => 'A new code every (seconds)';

  @override
  String pickLikely(String target) {
    return 'For $target';
  }

  @override
  String get pickNoAccounts =>
      'There are no accounts yet. Open ZT Authenticator and add one first.';

  @override
  String get pickOthers => 'All accounts';

  @override
  String get pickPicture => 'Pick a picture of a QR code';

  @override
  String get pickPictureHint => 'A screenshot or a photo, read on this phone';

  @override
  String get pickTitle => 'Which code?';

  @override
  String pickTitleFor(String target) {
    return 'Code for $target';
  }

  @override
  String get pin => 'Pin to top';

  @override
  String get pinned => 'Pinned';

  @override
  String get qrWarning =>
      'Anyone who scans or photographs this can make this account\'s codes. Show it only to move the account to a device of your own.';

  @override
  String get recoveryCodes => 'Recovery codes';

  @override
  String get recoveryCodesHelp =>
      'The one-time codes the service gave you for when you lose this phone, one per line. Encrypted with the account.';

  @override
  String rememberFor(String target) {
    return 'Remember my choice for $target';
  }

  @override
  String get restore => 'Put back';

  @override
  String get save => 'Save';

  @override
  String get scanHint => 'Point the camera at the QR code the service shows';

  @override
  String get scanQr => 'Scan a QR code';

  @override
  String get scanQrHint =>
      'The code a service shows when you turn on two-step sign-in';

  @override
  String get search => 'Search';

  @override
  String sendingCode(String name) {
    return 'Sending the code for $name';
  }

  @override
  String get serviceHint => 'GitHub';

  @override
  String get serviceLabel => 'Service';

  @override
  String get serviceRequired => 'Type the service or the account';

  @override
  String get settings => 'Settings';

  @override
  String get showQr => 'Show as QR code';

  @override
  String get trash => 'Trash';

  @override
  String trashCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n accounts',
      one: '1 account',
    );
    return '$_temp0';
  }

  @override
  String get trashEmpty => 'The trash is empty';

  @override
  String get trashHint =>
      'Accounts stay here for 30 days, then they are deleted for good.';

  @override
  String get typeKey => 'Type the key';

  @override
  String get typeKeyHint => 'When there is no QR code to scan';

  @override
  String get undo => 'Undo';

  @override
  String get unknownFile => 'This isn\'t a file ZT Authenticator knows';

  @override
  String get unnamedAccount => 'an account';

  @override
  String get unpin => 'Unpin';

  @override
  String get unreadableFile => 'The file is damaged or can\'t be read';

  @override
  String get usedIn => 'Where its code goes without asking';

  @override
  String get usedInHelp =>
      'Apps and sites you gave this code to from ZT Keyboard or autofill. Remove one to be asked again there.';

  @override
  String get wrongPassword => 'Wrong password';

  @override
  String get autofillTitle => 'Offer codes in other apps and browsers';

  @override
  String get autofillOffHint =>
      'Android shows \"Code from ZT Authenticator\" on a field that asks for a sign-in code. Android lets one app fill in fields at a time, so while this is on your password manager no longer fills in passwords.';

  @override
  String get autofillOnHint =>
      'On: ZT Authenticator is this phone\'s autofill app. To have your password manager fill in passwords again, choose it as the autofill app in Android\'s settings.';

  @override
  String get autofillUnavailable =>
      'This phone doesn\'t let apps fill in fields';

  @override
  String get groups => 'Groups';

  @override
  String get groupsHint => 'Keep work, personal and other accounts apart';

  @override
  String groupsCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n groups',
      one: '1 group',
    );
    return '$_temp0';
  }

  @override
  String get groupsEmpty =>
      'No groups yet. Add one, then press and hold an account to move it in.';

  @override
  String get newGroup => 'New group';

  @override
  String get groupName => 'Group name';

  @override
  String get renameGroup => 'Rename';

  @override
  String get deleteGroup => 'Delete group';

  @override
  String deleteGroupTitle(String name) {
    return 'Delete $name?';
  }

  @override
  String get deleteGroupBody =>
      'Its accounts stay in ZT Authenticator, without a group.';

  @override
  String groupAccounts(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n accounts',
      one: '1 account',
      zero: 'No accounts',
    );
    return '$_temp0';
  }

  @override
  String get allAccounts => 'All';

  @override
  String get moveToGroup => 'Move to group';

  @override
  String get noGroup => 'No group';

  @override
  String get groupEmpty => 'No accounts in this group yet';

  @override
  String get editGroups => 'Edit groups';

  @override
  String get groupNameTaken => 'There is already a group with this name';

  @override
  String nextCodeIs(String code) {
    return 'Next: $code';
  }

  @override
  String get checkClock => 'Check this phone\'s clock';

  @override
  String get checkClockHint =>
      'Codes depend on the time. When the clock is off, services refuse them.';

  @override
  String get clockRight => 'The clock is right';

  @override
  String clockOff(int seconds) {
    return 'This phone\'s clock is $seconds seconds off, so services may refuse your codes. Turn on automatic date and time in Android\'s settings.';
  }

  @override
  String get clockUnknown =>
      'Couldn\'t check the clock. Check your connection and try again.';

  @override
  String get ok => 'OK';
}
