// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Vietnamese (`vi`).
class AppLocalizationsVi extends AppLocalizations {
  AppLocalizationsVi([String locale = 'vi']) : super(locale);

  @override
  String get appTitle => 'Orbita';

  @override
  String get newChat => 'Hội thoại mới';

  @override
  String get send => 'Gửi';

  @override
  String get messageHint => 'Nhắn Orbita…';

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
  String get goPro => 'Go Pro';

  @override
  String get poweredBy => 'Powered by Orbita';

  @override
  String get freePlan => 'Miễn phí';

  @override
  String get proPlan => 'Pro';

  @override
  String get freeQuotaHint =>
      'Miễn phí: 60 tin/ngày · tối đa 3 ảnh/tin (5 MB), 8 ảnh/ngày';

  @override
  String get proQuotaHint =>
      'Pro: 400 tin/ngày · tối đa 8 ảnh/tin (8 MB), 20 ảnh/ngày';

  @override
  String messageQuotaReached(String resetsAt) {
    return 'Đã hết hạn mức tin nhắn trong ngày. Vui lòng đợi đến lần đặt lại ngày tiếp theo ($resetsAt) để tiếp tục.';
  }

  @override
  String imageQuotaReached(String resetsAt) {
    return 'Đã hết hạn mức tải ảnh trong ngày. Vui lòng đợi đến lần đặt lại ngày tiếp theo ($resetsAt) để tải thêm.';
  }

  @override
  String monthlyImageAllowanceReached(String resetsAt) {
    return 'Bạn đã hết hạn mức ảnh trong tháng. Tải ảnh tạm thời theo hạn mức Miễn phí (3 ảnh/tin, 8 ảnh/ngày) đến $resetsAt. Chat văn bản không bị ảnh hưởng.';
  }

  @override
  String get conversations => 'Hội thoại';

  @override
  String get settings => 'Cài đặt';

  @override
  String get language => 'Ngôn ngữ';

  @override
  String get languagePickerHint => 'Chọn ngôn ngữ hiển thị của ứng dụng';

  @override
  String get searchChats => 'Tìm hội thoại';

  @override
  String get library => 'Thư viện';

  @override
  String get tools => 'Công cụ';

  @override
  String get about => 'Giới thiệu';

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
      'Stub cấp Pro chỉ khi bật ALLOW_STORE_STUB_GRANT (dev). Bản thường mua in-app qua Store.';

  @override
  String get storePurchaseHint =>
      'Mua Pro ngay trong app qua Microsoft Store (Go Pro). Store xử lý thanh toán trong Orbita.';

  @override
  String get restorePurchases => 'Khôi phục giao dịch';

  @override
  String get storeOnlyUpgradeMessage =>
      'Nâng cấp lên Pro chỉ khả dụng trong phiên bản cài đặt từ Microsoft Store.';

  @override
  String get storePurchaseFailed =>
      'Không thể hoàn tất giao dịch. Vui lòng thử lại sau.';

  @override
  String get authSignInTitle => 'Đăng nhập Orbita';

  @override
  String get authEmail => 'Email';

  @override
  String get authPassword => 'Mật khẩu';

  @override
  String get authSignIn => 'Đăng nhập';

  @override
  String get authCreateAccount => 'Tạo tài khoản';

  @override
  String get authSwitchToSignUp => 'Chưa có tài khoản? Tạo tài khoản';

  @override
  String get authSwitchToSignIn => 'Đã có tài khoản? Đăng nhập';

  @override
  String get authUseEmailCode => 'Gửi mã đăng nhập qua email';

  @override
  String get authUsePassword => 'Dùng mật khẩu';

  @override
  String get authSendCode => 'Gửi mã';

  @override
  String get authCodeLabel => 'Mã trong email của bạn';

  @override
  String get authVerifyCode => 'Xác minh';

  @override
  String get authCodeSent =>
      'Chúng tôi đã gửi mã đến email của bạn. Nhập mã bên dưới.';

  @override
  String get authConfirmEmail =>
      'Kiểm tra email để xác nhận địa chỉ, sau đó đăng nhập.';

  @override
  String get authFailed =>
      'Đăng nhập thất bại. Hãy kiểm tra thông tin và thử lại.';

  @override
  String get authNotConfigured => 'Bản dựng này chưa được cấu hình đăng nhập.';

  @override
  String get authSignOut => 'Đăng xuất';

  @override
  String get authAccount => 'Tài khoản';
}
