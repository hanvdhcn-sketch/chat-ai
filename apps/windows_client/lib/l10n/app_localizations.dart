import 'package:flutter/widgets.dart';

/// Hand-maintained stubs mirroring `app_en.arb` / `app_vi.arb`.
/// When Flutter SDK is available, prefer `flutter gen-l10n` and swap imports.
class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static const supportedLocales = [Locale('en'), Locale('vi')];

  static AppLocalizations of(BuildContext context) {
    final loc = Localizations.of<AppLocalizations>(context, AppLocalizations);
    assert(loc != null, 'AppLocalizations not found in context');
    return loc!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  bool get isVi => locale.languageCode == 'vi';

  String get appTitle => 'ChatAI';
  String get newChat => isVi ? 'Hội thoại mới' : 'New chat';
  String get send => isVi ? 'Gửi' : 'Send';
  String get messageHint => isVi ? 'Nhắn ChatAI…' : 'Message ChatAI…';
  String get signIn => isVi ? 'Đăng nhập' : 'Sign in';
  String get signOut => isVi ? 'Đăng xuất' : 'Sign out';
  String usageRemaining(int remaining) => isVi
      ? 'Còn $remaining tin nhắn hôm nay'
      : '$remaining messages left today';
  String get upgradePro => isVi ? 'Nâng cấp Pro' : 'Upgrade to Pro';
  String get poweredBy => 'Powered by ChatAI';
  String get freePlan => isVi ? 'Miễn phí' : 'Free';
  String get proPlan => 'Pro';
  String get conversations => isVi ? 'Hội thoại' : 'Conversations';
  String get settings => isVi ? 'Cài đặt' : 'Settings';
  String get language => isVi ? 'Ngôn ngữ' : 'Language';
  String get stubAuthHint => isVi
      ? 'Auth tạm dùng stub token cho đến khi gắn Supabase.'
      : 'Dev auth uses stub tokens until Supabase is wired.';
  String get emptyChat => isVi ? 'Bắt đầu hội thoại' : 'Start a conversation';
  String get streaming => isVi ? 'Đang suy nghĩ…' : 'Thinking…';
  String get stop => isVi ? 'Dừng' : 'Stop';
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      ['en', 'vi'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
