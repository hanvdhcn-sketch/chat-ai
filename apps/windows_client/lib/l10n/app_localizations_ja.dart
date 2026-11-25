// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'Orbita';

  @override
  String get newChat => '新しいチャット';

  @override
  String get send => '送信';

  @override
  String get messageHint => 'Orbita にメッセージ…';

  @override
  String get signIn => 'サインイン';

  @override
  String get signOut => 'サインアウト';

  @override
  String usageRemaining(int remaining) {
    return '本日あと $remaining メッセージ';
  }

  @override
  String get upgradePro => 'Pro にアップグレード';

  @override
  String get goPro => 'Go Pro';

  @override
  String get poweredBy => 'Powered by Orbita';

  @override
  String get freePlan => '無料';

  @override
  String get proPlan => 'Pro';

  @override
  String get freeQuotaHint => '無料: 1日60メッセージ · 1通あたり最大3画像（5 MB）、1日8枚';

  @override
  String get proQuotaHint => 'Pro: 1日400メッセージ · 1通あたり最大8画像（8 MB）、1日20枚';

  @override
  String messageQuotaReached(String resetsAt) {
    return '1日のメッセージ上限に達しました。次のリセット（$resetsAt）までお待ちください。';
  }

  @override
  String imageQuotaReached(String resetsAt) {
    return '1日の画像アップロード上限に達しました。次のリセット（$resetsAt）までお待ちください。';
  }

  @override
  String monthlyImageAllowanceReached(String resetsAt) {
    return '今月の画像枠に達しました。$resetsAt まで画像は無料枠（1通3枚、1日8枚）になります。テキストチャットは影響しません。';
  }

  @override
  String get conversations => '会話';

  @override
  String get settings => '設定';

  @override
  String get language => '言語';

  @override
  String get languagePickerHint => 'アプリの表示言語を選択';

  @override
  String get searchChats => 'チャットを検索';

  @override
  String get library => 'ライブラリ';

  @override
  String get tools => 'ツール';

  @override
  String get about => '情報';

  @override
  String get stubAuthHint => 'Supabase 連携まで開発用スタブトークンを使用します。';

  @override
  String get emptyChat => '会話を始める';

  @override
  String get streaming => '考え中…';

  @override
  String get stop => '停止';

  @override
  String get storeStubHint =>
      '開発専用の Store stub（ALLOW_STORE_STUB_GRANT）。通常ビルドはアプリ内購入を使用します。';

  @override
  String get storePurchaseHint =>
      'Microsoft Store のアプリ内購入で Pro を購入（Go Pro）。支払いは Orbita 内で処理されます。';

  @override
  String get restorePurchases => '購入を復元';
}
