// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Orbita';

  @override
  String get newChat => 'Nouveau chat';

  @override
  String get send => 'Envoyer';

  @override
  String get messageHint => 'Écrire à Orbita…';

  @override
  String get signIn => 'Connexion';

  @override
  String get signOut => 'Déconnexion';

  @override
  String usageRemaining(int remaining) {
    return '$remaining messages restants aujourd’hui';
  }

  @override
  String get upgradePro => 'Passer à Pro';

  @override
  String get goPro => 'Go Pro';

  @override
  String get poweredBy => 'Powered by Orbita';

  @override
  String get freePlan => 'Gratuit';

  @override
  String get proPlan => 'Pro';

  @override
  String get freeQuotaHint =>
      'Gratuit : 60 messages/jour · jusqu’à 3 images/message (5 Mo), 8/jour';

  @override
  String get proQuotaHint =>
      'Pro : 400 messages/jour · jusqu’à 8 images/message (8 Mo), 20/jour';

  @override
  String messageQuotaReached(String resetsAt) {
    return 'Limite quotidienne de messages atteinte. Attendez la prochaine réinitialisation ($resetsAt) pour continuer.';
  }

  @override
  String imageQuotaReached(String resetsAt) {
    return 'Limite quotidienne d’images atteinte. Attendez la prochaine réinitialisation ($resetsAt) pour en envoyer davantage.';
  }

  @override
  String monthlyImageAllowanceReached(String resetsAt) {
    return 'Vous avez atteint le quota d’images du mois. Jusqu’à $resetsAt, les envois utilisent les limites Gratuites (3 par message, 8 par jour). Le chat texte n’est pas affecté.';
  }

  @override
  String get conversations => 'Conversations';

  @override
  String get settings => 'Paramètres';

  @override
  String get language => 'Langue';

  @override
  String get languagePickerHint => 'Choisir la langue d’affichage';

  @override
  String get searchChats => 'Rechercher des chats';

  @override
  String get library => 'Bibliothèque';

  @override
  String get tools => 'Outils';

  @override
  String get about => 'À propos';

  @override
  String get stubAuthHint =>
      'L’auth de développement utilise des jetons stub jusqu’à la connexion Supabase.';

  @override
  String get emptyChat => 'Démarrer une conversation';

  @override
  String get streaming => 'Réflexion…';

  @override
  String get stop => 'Arrêter';

  @override
  String get storeStubHint =>
      'Octroi stub Store réservé au développement (ALLOW_STORE_STUB_GRANT). Les builds normales utilisent l’achat in-app.';

  @override
  String get storePurchaseHint =>
      'Achetez Pro dans l’app via le Microsoft Store (Go Pro). Le Store traite le paiement dans Orbita.';

  @override
  String get restorePurchases => 'Restaurer les achats';
}
