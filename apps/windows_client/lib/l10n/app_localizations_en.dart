// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Orbita';

  @override
  String get newChat => 'New chat';

  @override
  String get send => 'Send';

  @override
  String get messageHint => 'Message Orbita…';

  @override
  String get signIn => 'Sign in';

  @override
  String get signOut => 'Sign out';

  @override
  String usageRemaining(int remaining) {
    return '$remaining messages left today';
  }

  @override
  String get upgradePro => 'Upgrade to Pro';

  @override
  String get poweredBy => 'Powered by Orbita';

  @override
  String get freePlan => 'Free';

  @override
  String get proPlan => 'Pro';

  @override
  String get freeQuotaHint =>
      'Free: 100 messages/day · up to 3 images/message (8 MB), 20/day';

  @override
  String get proQuotaHint =>
      'Pro: 400 messages/day · up to 8 images/message (8 MB), 20/day';

  @override
  String messageQuotaReached(String resetsAt) {
    return 'Daily message limit reached. Wait until the next day reset ($resetsAt) to continue.';
  }

  @override
  String imageQuotaReached(String resetsAt) {
    return 'Daily image upload limit reached. Wait until the next day reset ($resetsAt) to upload more.';
  }

  @override
  String monthlyImageAllowanceReached(String resetsAt) {
    return "You've reached this month's image allowance. Image uploads temporarily use Free limits (3 per message, 20 per day) until $resetsAt. Text chat is unaffected.";
  }

  @override
  String get conversations => 'Conversations';

  @override
  String get settings => 'Settings';

  @override
  String get language => 'Language';

  @override
  String get stubAuthHint =>
      'Dev auth uses stub tokens until Supabase is wired.';

  @override
  String get emptyChat => 'Start a conversation';

  @override
  String get streaming => 'Thinking…';

  @override
  String get stop => 'Stop';

  @override
  String get storeStubHint =>
      'Store purchase stubbed outside an MS Store package — Pro granted via API stub.';

  @override
  String get storePurchaseHint =>
      'Buy Pro via Microsoft Store. Outside Store packaging this uses a clear stub.';

  @override
  String get restorePurchases => 'Restore purchases';
}
