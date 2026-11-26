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
  String get goPro => 'Go Pro';

  @override
  String get poweredBy => 'Powered by Orbita';

  @override
  String get freePlan => 'Free';

  @override
  String get proPlan => 'Pro';

  @override
  String get freeQuotaHint =>
      'Free: 60 messages/day · up to 3 images/message (5 MB), 8/day';

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
    return 'You\'ve reached this month\'s image allowance. Image uploads temporarily use Free limits (3 per message, 8 per day) until $resetsAt. Text chat is unaffected.';
  }

  @override
  String get conversations => 'Conversations';

  @override
  String get settings => 'Settings';

  @override
  String get language => 'Language';

  @override
  String get languagePickerHint => 'Choose the app display language';

  @override
  String get searchChats => 'Search Chats';

  @override
  String get library => 'Library';

  @override
  String get tools => 'Tools';

  @override
  String get about => 'About';

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
      'Dev-only Store stub grant (ALLOW_STORE_STUB_GRANT). Normal builds use in-app Store purchase.';

  @override
  String get storePurchaseHint =>
      'Buy Pro in-app via Microsoft Store (Go Pro). Store processes payment inside Orbita.';

  @override
  String get restorePurchases => 'Restore purchases';

  @override
  String get storeOnlyUpgradeMessage =>
      'Upgrading to Pro is only available in the version installed from Microsoft Store.';

  @override
  String get storePurchaseFailed =>
      'We couldn\'t complete the purchase. Please try again later.';

  @override
  String get authSignInTitle => 'Sign in to Orbita';

  @override
  String get authEmail => 'Email';

  @override
  String get authPassword => 'Password';

  @override
  String get authSignIn => 'Sign in';

  @override
  String get authCreateAccount => 'Create account';

  @override
  String get authSwitchToSignUp => 'New here? Create an account';

  @override
  String get authSwitchToSignIn => 'Already have an account? Sign in';

  @override
  String get authUseEmailCode => 'Email me a sign-in code instead';

  @override
  String get authUsePassword => 'Use a password instead';

  @override
  String get authSendCode => 'Send code';

  @override
  String get authCodeLabel => 'Code from your email';

  @override
  String get authVerifyCode => 'Verify';

  @override
  String get authCodeSent => 'We sent a code to your email. Enter it below.';

  @override
  String get authConfirmEmail =>
      'Check your email to confirm your address, then sign in.';

  @override
  String get authFailed => 'Sign-in failed. Check your details and try again.';

  @override
  String get authNotConfigured => 'Sign-in is not configured in this build.';

  @override
  String get authSignOut => 'Sign out';

  @override
  String get authAccount => 'Account';
}
