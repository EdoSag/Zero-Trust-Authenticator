// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_l10n.dart';

// ignore_for_file: type=lint

/// The translations for Hebrew (`he`).
class AppL10nHe extends AppL10n {
  AppL10nHe([String locale = 'he']) : super(locale);

  @override
  String get appTitle => 'ZT Authenticator';

  @override
  String get accountHint => 'you@example.com';

  @override
  String get accountLabel => 'חשבון';

  @override
  String get add => 'הוספה';

  @override
  String get addAccount => 'הוספת חשבון';

  @override
  String get addFromLinkTitle => 'להוסיף את החשבון הזה?';

  @override
  String addFromLinkOne(String name) {
    return 'קישור ביקש להוסיף את $name אל ZT Authenticator. כדאי להוסיף רק אם פתחת את הקישור בעצמך ממש עכשיו.';
  }

  @override
  String addFromLinkMany(int count) {
    return 'קישור ביקש להוסיף $count חשבונות אל ZT Authenticator. כדאי להוסיף רק אם פתחת את הקישור בעצמך ממש עכשיו.';
  }

  @override
  String addedOne(String name) {
    return '$name נוסף';
  }

  @override
  String addedMany(int count) {
    return 'נוספו $count חשבונות';
  }

  @override
  String addedSomeSkipped(int added, int skipped) {
    return 'נוספו $added. $skipped כבר היו כאן.';
  }

  @override
  String get advanced => 'מתקדם';

  @override
  String get advancedHint => 'רק אם השירות נתן הגדרות אחרות';

  @override
  String afterSeconds(int n) {
    return 'אחרי $n שניות';
  }

  @override
  String get algorithm => 'אלגוריתם';

  @override
  String get alreadyHere => 'החשבון הזה כבר נמצא כאן';

  @override
  String get badKey => 'אי אפשר ליצור קודים מהמפתח הזה';

  @override
  String get cameraRefused =>
      'אין הרשאה למצלמה. אפשר לאשר אותה בהגדרות הטלפון, או לבחור תמונה במקום.';

  @override
  String get cancel => 'ביטול';

  @override
  String get clearClipboard => 'ניקוי קוד שהועתק';

  @override
  String get closeSearch => 'סגירת החיפוש';

  @override
  String get codeKind => 'סוג הקוד';

  @override
  String get continueLabel => 'המשך';

  @override
  String get copied => 'הקוד הועתק';

  @override
  String copiedClears(int n) {
    return 'הקוד הועתק. הוא יימחק בעוד $n שניות.';
  }

  @override
  String get couldNotLoad =>
      'לא הצלחנו לפתוח את החשבונות. כדאי לסגור את האפליקציה ולנסות שוב.';

  @override
  String get couldNotSave => 'השמירה נכשלה. אפשר לנסות שוב.';

  @override
  String get counter => 'מונה';

  @override
  String daysLeft(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'יימחק בעוד $n ימים',
      two: 'יימחק בעוד יומיים',
      one: 'יימחק בעוד יום',
      zero: 'יימחק היום',
    );
    return '$_temp0';
  }

  @override
  String get deleteForever => 'מחיקה לצמיתות';

  @override
  String deleteForeverTitle(String name) {
    return 'למחוק את $name לצמיתות?';
  }

  @override
  String get deleteForeverBody =>
      'הקודים שלו יימחקו לתמיד, בכל המכשירים שלך. אם השירות עדיין מבקש קוד, כדאי קודם לכבות שם את האימות הדו-שלבי, או לשמור את קודי השחזור.';

  @override
  String get digits => 'ספרות';

  @override
  String get editAccount => 'עריכת חשבון';

  @override
  String get emptyTitle => 'אין עדיין חשבונות';

  @override
  String get emptyBody =>
      'מפעילים אימות דו-שלבי בשירות, וסורקים את קוד ה-QR שהוא מציג. הקודים מוצפנים בטלפון הזה לפני הסנכרון, כך שרק לך יש גישה אליהם.';

  @override
  String get exportTitle => 'קובץ גיבוי מוצפן';

  @override
  String get exportHint => 'כל החשבונות בקובץ אחד, נעול בסיסמה שבחרת';

  @override
  String get exportBody =>
      'בוחרים סיסמה לקובץ, לפחות 8 תווים. בלעדיה אי אפשר לפתוח את הקובץ, ואף אחד לא יכול לאפס אותה.';

  @override
  String get exportDone => 'הגיבוי נשמר';

  @override
  String get exportFailed => 'שמירת הגיבוי נכשלה';

  @override
  String get filePasswordTitle => 'הקובץ נעול';

  @override
  String get filePasswordBody => 'יש להקליד את הסיסמה שאיתה הוא נשמר.';

  @override
  String get hideCodes => 'הסתרת הקודים עד להקשה';

  @override
  String get hideCodesHint =>
      'הקודים מוצגים כנקודות. הקשה על חשבון מציגה ומעתיקה את הקוד שלו.';

  @override
  String get howToExport => 'איך מוציאים את החשבונות מאפליקציה אחרת';

  @override
  String get howGoogle =>
      'תפריט, העברת חשבונות, ייצוא חשבונות. סורקים כל קוד QR שמוצג, או בוחרים צילום מסך שלו.';

  @override
  String get howAegis =>
      'הגדרות, ייבוא וייצוא, ייצוא, בפורמט Aegis ‏(‎.json). גם ייצוא מוצפן נתמך.';

  @override
  String get howTwoFas =>
      'הגדרות, גיבוי 2FAS, ייצוא. גם קבצים עם סיסמה נתמכים.';

  @override
  String get howEnte => 'הגדרות, נתונים, ייצוא קודים, טקסט רגיל.';

  @override
  String get howBitwarden =>
      'כלים, ייצוא כספת, ‎.json (לא מוצפן). יתווספו רק הפריטים שיש להם קוד.';

  @override
  String get howOthers => 'מייצאים כקובץ JSON רגיל.';

  @override
  String get importTitle => 'ייבוא מאפליקציה אחרת';

  @override
  String get importHint =>
      'Google Authenticator, Aegis, 2FAS, Ente Auth, Bitwarden ועוד';

  @override
  String get importIntro =>
      'מעבירים את החשבונות לכאן. שום דבר לא מועלה: הקבצים והתמונות נקראים בטלפון הזה.';

  @override
  String get importFile => 'בחירת קובץ גיבוי';

  @override
  String get importFileHint =>
      'של ZT Authenticator, Aegis, 2FAS, Ente Auth, Bitwarden, andOTP או FreeOTP+';

  @override
  String get importScanHint =>
      'קוד ההגדרה של שירות, או קודי הייצוא של Google Authenticator';

  @override
  String get keyLabel => 'מפתח';

  @override
  String get keyHelp =>
      'האותיות והספרות שהשירות מציג תחת \"לא מצליחים לסרוק?\" או \"הזנת מפתח הגדרה\".';

  @override
  String get keyInvalid => 'מפתח מכיל רק את האותיות A עד Z ואת הספרות 2 עד 7';

  @override
  String get kindTime => 'מבוסס זמן (רוב השירותים)';

  @override
  String get kindCounter => 'מבוסס מונה';

  @override
  String get kindSteam => 'Steam';

  @override
  String get mismatchTitle => 'משהו כאן לא מסתדר';

  @override
  String mismatchBodySite(String account, String home, String target) {
    return '$account שמור עבור $home, אבל הקוד התבקש על ידי $target. דף מזויף שמבקש קוד הוא הדרך שבה חשבונות נגנבים. כדאי לשלוח רק אם אין לך ספק.';
  }

  @override
  String mismatchBodyApp(String account, String target) {
    return 'עוד לא השתמשת ב-$account בתוך $target, וזו לא האפליקציה שבדרך כלל מבקשת אותו. מסך מזויף שמבקש קוד הוא הדרך שבה חשבונות נגנבים. כדאי לשלוח רק אם אין לך ספק.';
  }

  @override
  String get mismatchSendAnyway => 'לשלוח בכל זאת';

  @override
  String get moveToTrash => 'העברה לאשפה';

  @override
  String movedToTrash(String name) {
    return '$name הועבר לאשפה';
  }

  @override
  String get never => 'אף פעם';

  @override
  String get nextCode => 'הקוד הבא';

  @override
  String get noQrInPicture => 'לא נמצא קוד QR בתמונה';

  @override
  String get notAccountQr => 'זה לא קוד של חשבון';

  @override
  String get note => 'הערה';

  @override
  String get nothingFound => 'לא נמצא דבר';

  @override
  String get nothingToAdd => 'לא נמצאו שם חשבונות';

  @override
  String get password => 'סיסמה';

  @override
  String get passwordAgain => 'הסיסמה שוב';

  @override
  String get passwordRequired => 'יש להקליד סיסמה';

  @override
  String get passwordTooShort => 'לפחות 8 תווים';

  @override
  String get passwordsDiffer => 'הסיסמאות לא זהות';

  @override
  String get pasteLinks => 'הדבקת קישורים';

  @override
  String get pasteLinksHint => 'otpauth://totp/…';

  @override
  String get pasteLinksSubtitle => 'שורות שמתחילות ב-otpauth://';

  @override
  String get periodInvalid => 'בין 5 ל-3600 שניות';

  @override
  String get periodSeconds => 'קוד חדש כל (שניות)';

  @override
  String pickLikely(String target) {
    return 'עבור $target';
  }

  @override
  String get pickNoAccounts =>
      'אין עדיין חשבונות. יש לפתוח את ZT Authenticator ולהוסיף חשבון קודם.';

  @override
  String get pickOthers => 'כל החשבונות';

  @override
  String get pickPicture => 'בחירת תמונה של קוד QR';

  @override
  String get pickPictureHint => 'צילום מסך או תמונה, נקראים בטלפון הזה';

  @override
  String get pickTitle => 'איזה קוד?';

  @override
  String pickTitleFor(String target) {
    return 'קוד עבור $target';
  }

  @override
  String get pin => 'הצמדה לראש הרשימה';

  @override
  String get pinned => 'מוצמד';

  @override
  String get qrWarning =>
      'כל מי שסורק או מצלם את זה יכול ליצור את הקודים של החשבון. כדאי להציג רק כדי להעביר את החשבון למכשיר שלך.';

  @override
  String get recoveryCodes => 'קודי שחזור';

  @override
  String get recoveryCodesHelp =>
      'הקודים החד-פעמיים שהשירות נתן למקרה שהטלפון יאבד, אחד בכל שורה. מוצפנים יחד עם החשבון.';

  @override
  String rememberFor(String target) {
    return 'לזכור את הבחירה עבור $target';
  }

  @override
  String get restore => 'שחזור';

  @override
  String get save => 'שמירה';

  @override
  String get scanHint => 'מכוונים את המצלמה אל קוד ה-QR שהשירות מציג';

  @override
  String get scanQr => 'סריקת קוד QR';

  @override
  String get scanQrHint => 'הקוד שהשירות מציג כשמפעילים אימות דו-שלבי';

  @override
  String get search => 'חיפוש';

  @override
  String sendingCode(String name) {
    return 'שולח את הקוד של $name';
  }

  @override
  String get serviceHint => 'GitHub';

  @override
  String get serviceLabel => 'שירות';

  @override
  String get serviceRequired => 'יש להקליד שירות או חשבון';

  @override
  String get settings => 'הגדרות';

  @override
  String get showQr => 'הצגה כקוד QR';

  @override
  String get trash => 'אשפה';

  @override
  String trashCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n חשבונות',
      one: 'חשבון אחד',
    );
    return '$_temp0';
  }

  @override
  String get trashEmpty => 'האשפה ריקה';

  @override
  String get trashHint => 'חשבונות נשארים כאן 30 יום, ואז נמחקים לצמיתות.';

  @override
  String get typeKey => 'הקלדת המפתח';

  @override
  String get typeKeyHint => 'כשאין קוד QR לסרוק';

  @override
  String get undo => 'ביטול הפעולה';

  @override
  String get unknownFile => 'ZT Authenticator לא מכיר את סוג הקובץ הזה';

  @override
  String get unnamedAccount => 'חשבון';

  @override
  String get unpin => 'ביטול ההצמדה';

  @override
  String get unreadableFile => 'הקובץ פגום או שלא ניתן לקרוא אותו';

  @override
  String get usedIn => 'לאן הקוד נשלח בלי לשאול';

  @override
  String get usedInHelp =>
      'אפליקציות ואתרים שקיבלו את הקוד הזה מ-ZT Keyboard או ממילוי אוטומטי. הסרה של אחד מהם תגרום לשאלה חוזרת שם.';

  @override
  String get wrongPassword => 'סיסמה שגויה';

  @override
  String get autofillTitle => 'הצעת קודים באפליקציות ובדפדפנים אחרים';

  @override
  String get autofillOffHint =>
      'Android מציג \"קוד מ-ZT Authenticator\" בשדה שמבקש קוד כניסה. Android מאפשר רק לאפליקציה אחת למלא שדות, ולכן כשזה פועל מנהל הסיסמאות שלך לא ימלא סיסמאות.';

  @override
  String get autofillOnHint =>
      'פועל: ZT Authenticator היא אפליקציית המילוי האוטומטי בטלפון הזה. כדי שמנהל הסיסמאות ימלא שוב סיסמאות, יש לבחור בו כאפליקציית המילוי האוטומטי בהגדרות Android.';

  @override
  String get autofillUnavailable => 'הטלפון הזה לא מאפשר לאפליקציות למלא שדות';
}
