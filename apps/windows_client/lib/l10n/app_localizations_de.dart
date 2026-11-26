// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'Orbita';

  @override
  String get newChat => 'Neuer Chat';

  @override
  String get send => 'Senden';

  @override
  String get messageHint => 'Nachricht an Orbita…';

  @override
  String get signIn => 'Anmelden';

  @override
  String get signOut => 'Abmelden';

  @override
  String usageRemaining(int remaining) {
    return 'Heute noch $remaining Nachrichten';
  }

  @override
  String get upgradePro => 'Auf Pro upgraden';

  @override
  String get goPro => 'Go Pro';

  @override
  String get poweredBy => 'Powered by Orbita';

  @override
  String get freePlan => 'Kostenlos';

  @override
  String get proPlan => 'Pro';

  @override
  String get freeQuotaHint =>
      'Kostenlos: 60 Nachrichten/Tag · bis zu 3 Bilder/Nachricht (5 MB), 8/Tag';

  @override
  String get proQuotaHint =>
      'Pro: 400 Nachrichten/Tag · bis zu 8 Bilder/Nachricht (8 MB), 20/Tag';

  @override
  String messageQuotaReached(String resetsAt) {
    return 'Tageslimit für Nachrichten erreicht. Bitte bis zum nächsten Reset ($resetsAt) warten.';
  }

  @override
  String imageQuotaReached(String resetsAt) {
    return 'Tageslimit für Bild-Uploads erreicht. Bitte bis zum nächsten Reset ($resetsAt) warten.';
  }

  @override
  String monthlyImageAllowanceReached(String resetsAt) {
    return 'Monatliches Bildkontingent erreicht. Bis $resetsAt gelten die Free-Limits (3 pro Nachricht, 8 pro Tag). Text-Chat ist nicht betroffen.';
  }

  @override
  String get conversations => 'Unterhaltungen';

  @override
  String get settings => 'Einstellungen';

  @override
  String get language => 'Sprache';

  @override
  String get languagePickerHint => 'Anzeigesprache der App wählen';

  @override
  String get searchChats => 'Chats suchen';

  @override
  String get library => 'Bibliothek';

  @override
  String get tools => 'Werkzeuge';

  @override
  String get about => 'Info';

  @override
  String get stubAuthHint =>
      'Dev-Auth nutzt Stub-Tokens, bis Supabase angebunden ist.';

  @override
  String get emptyChat => 'Unterhaltung starten';

  @override
  String get streaming => 'Denke nach…';

  @override
  String get stop => 'Stopp';

  @override
  String get storeStubHint =>
      'Nur-Dev Store-Stub-Freigabe (ALLOW_STORE_STUB_GRANT). Normale Builds nutzen In-App-Kauf.';

  @override
  String get storePurchaseHint =>
      'Pro in der App über den Microsoft Store kaufen (Go Pro). Der Store verarbeitet die Zahlung in Orbita.';

  @override
  String get restorePurchases => 'Käufe wiederherstellen';

  @override
  String get storeOnlyUpgradeMessage =>
      'Das Upgrade auf Pro ist nur in der aus dem Microsoft Store installierten Version verfügbar.';

  @override
  String get storePurchaseFailed =>
      'Der Kauf konnte nicht abgeschlossen werden. Bitte versuche es später erneut.';

  @override
  String get authSignInTitle => 'Bei Orbita anmelden';

  @override
  String get authEmail => 'E-Mail';

  @override
  String get authPassword => 'Passwort';

  @override
  String get authSignIn => 'Anmelden';

  @override
  String get authCreateAccount => 'Konto erstellen';

  @override
  String get authSwitchToSignUp => 'Neu hier? Konto erstellen';

  @override
  String get authSwitchToSignIn => 'Schon ein Konto? Anmelden';

  @override
  String get authUseEmailCode => 'Stattdessen Anmeldecode per E-Mail senden';

  @override
  String get authUsePassword => 'Passwort verwenden';

  @override
  String get authSendCode => 'Code senden';

  @override
  String get authCodeLabel => 'Code aus deiner E-Mail';

  @override
  String get authVerifyCode => 'Bestätigen';

  @override
  String get authCodeSent =>
      'Wir haben einen Code an deine E-Mail gesendet. Gib ihn unten ein.';

  @override
  String get authConfirmEmail =>
      'Bestätige deine Adresse über die E-Mail und melde dich dann an.';

  @override
  String get authFailed =>
      'Anmeldung fehlgeschlagen. Prüfe deine Angaben und versuche es erneut.';

  @override
  String get authNotConfigured =>
      'Die Anmeldung ist in diesem Build nicht konfiguriert.';

  @override
  String get authSignOut => 'Abmelden';

  @override
  String get authAccount => 'Konto';
}
