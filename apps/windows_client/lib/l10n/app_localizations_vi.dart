// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Vietnamese (`vi`).
class AppLocalizationsVi extends AppLocalizations {
  AppLocalizationsVi([String locale = 'vi']) : super(locale);

  @override
  String get appTitle => 'ChatAI';

  @override
  String get newChat => 'Hội thoại mới';

  @override
  String get send => 'Gửi';

  @override
  String get messageHint => 'Nhắn ChatAI…';

  @override
  String get signIn => 'Đăng nhập';

  @override
  String get signOut => 'Đăng xuất';

  @override
  String usageRemaining(int remaining) {
    return 'Còn $remaining tin nhắn hôm nay';
  }

  @override
  String get upgradePro => 'Nâng cấp Pro';

  @override
  String get poweredBy => 'Powered by ChatAI';

  @override
  String get freePlan => 'Miễn phí';

  @override
  String get proPlan => 'Pro';

  @override
  String get conversations => 'Hội thoại';

  @override
  String get settings => 'Cài đặt';

  @override
  String get language => 'Ngôn ngữ';

  @override
  String get stubAuthHint =>
      'Auth tạm dùng stub token cho đến khi gắn Supabase.';

  @override
  String get emptyChat => 'Bắt đầu hội thoại';

  @override
  String get streaming => 'Đang suy nghĩ…';

  @override
  String get stop => 'Dừng';

  @override
  String get storeStubHint =>
      'Mua Store đang stub ngoài gói MS Store — Pro được cấp qua API stub.';

  @override
  String get storePurchaseHint =>
      'Mua Pro qua Microsoft Store. Ngoài gói Store sẽ dùng stub rõ ràng.';

  @override
  String get restorePurchases => 'Khôi phục giao dịch';
}
