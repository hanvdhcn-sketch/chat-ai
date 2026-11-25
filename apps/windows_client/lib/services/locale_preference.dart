import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One of the 10 UI languages Orbita ships with.
class AppLanguage {
  const AppLanguage({
    required this.code,
    required this.locale,
    required this.nativeLabel,
    required this.englishLabel,
  });

  /// Stable preference / BCP-47-ish tag (e.g. `pt-BR`, `zh`).
  final String code;
  final Locale locale;
  final String nativeLabel;
  final String englishLabel;

  String get pickerLabel =>
      nativeLabel == englishLabel ? nativeLabel : '$nativeLabel · $englishLabel';
}

/// Supported UI languages (Settings picker order).
const kAppLanguages = <AppLanguage>[
  AppLanguage(
    code: 'en',
    locale: Locale('en'),
    nativeLabel: 'English',
    englishLabel: 'English',
  ),
  AppLanguage(
    code: 'vi',
    locale: Locale('vi'),
    nativeLabel: 'Tiếng Việt',
    englishLabel: 'Vietnamese',
  ),
  AppLanguage(
    code: 'zh',
    locale: Locale('zh'),
    nativeLabel: '简体中文',
    englishLabel: 'Chinese (Simplified)',
  ),
  AppLanguage(
    code: 'ja',
    locale: Locale('ja'),
    nativeLabel: '日本語',
    englishLabel: 'Japanese',
  ),
  AppLanguage(
    code: 'ko',
    locale: Locale('ko'),
    nativeLabel: '한국어',
    englishLabel: 'Korean',
  ),
  AppLanguage(
    code: 'es',
    locale: Locale('es'),
    nativeLabel: 'Español',
    englishLabel: 'Spanish',
  ),
  AppLanguage(
    code: 'fr',
    locale: Locale('fr'),
    nativeLabel: 'Français',
    englishLabel: 'French',
  ),
  AppLanguage(
    code: 'de',
    locale: Locale('de'),
    nativeLabel: 'Deutsch',
    englishLabel: 'German',
  ),
  AppLanguage(
    code: 'pt-BR',
    locale: Locale('pt', 'BR'),
    nativeLabel: 'Português (Brasil)',
    englishLabel: 'Portuguese (Brazil)',
  ),
  AppLanguage(
    code: 'hi',
    locale: Locale('hi'),
    nativeLabel: 'हिन्दी',
    englishLabel: 'Hindi',
  ),
];

/// Persists and exposes the user-selected UI locale.
class LocalePreference extends ChangeNotifier {
  static const prefsKey = 'orbita_ui_locale';

  LocalePreference();

  AppLanguage _language = kAppLanguages.first;
  bool _loaded = false;

  AppLanguage get language => _language;
  Locale get locale => _language.locale;
  String get code => _language.code;
  bool get loaded => _loaded;

  static AppLanguage resolve(String? raw) {
    if (raw == null || raw.isEmpty) return kAppLanguages.first;
    final normalized = raw.trim().replaceAll('_', '-');
    for (final lang in kAppLanguages) {
      if (lang.code.toLowerCase() == normalized.toLowerCase()) return lang;
    }
    // Accept zh-Hans / zh-CN → zh, pt → pt-BR.
    final lower = normalized.toLowerCase();
    if (lower.startsWith('zh')) {
      return kAppLanguages.firstWhere((l) => l.code == 'zh');
    }
    if (lower == 'pt' || lower.startsWith('pt-')) {
      return kAppLanguages.firstWhere((l) => l.code == 'pt-BR');
    }
    final langOnly = lower.split('-').first;
    for (final lang in kAppLanguages) {
      if (lang.locale.languageCode == langOnly) return lang;
    }
    return kAppLanguages.first;
  }

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _language = resolve(prefs.getString(prefsKey));
    } catch (_) {
      _language = kAppLanguages.first;
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }

  Future<void> setCode(String code) async {
    final next = resolve(code);
    if (next.code == _language.code && _loaded) return;
    _language = next;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefsKey, next.code);
    } catch (_) {
      // Preference write failed — UI still updated for this session.
    }
  }
}
