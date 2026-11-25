import 'package:chatai/services/locale_preference.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ships exactly 10 UI languages', () {
    expect(kAppLanguages.map((l) => l.code).toList(), [
      'en',
      'vi',
      'zh',
      'ja',
      'ko',
      'es',
      'fr',
      'de',
      'pt-BR',
      'hi',
    ]);
  });

  test('resolve accepts aliases for zh and pt', () {
    expect(LocalePreference.resolve('zh-Hans').code, 'zh');
    expect(LocalePreference.resolve('zh_CN').code, 'zh');
    expect(LocalePreference.resolve('pt').code, 'pt-BR');
    expect(LocalePreference.resolve('pt_BR').code, 'pt-BR');
    expect(LocalePreference.resolve('unknown').code, 'en');
  });

  test('persists locale preference', () async {
    SharedPreferences.setMockInitialValues({});
    final pref = LocalePreference();
    await pref.load();
    expect(pref.code, 'en');
    await pref.setCode('ja');
    expect(pref.code, 'ja');

    final again = LocalePreference();
    await again.load();
    expect(again.code, 'ja');
  });
}
