// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'Orbita';

  @override
  String get newChat => '新对话';

  @override
  String get send => '发送';

  @override
  String get messageHint => '向 Orbita 发送消息…';

  @override
  String get signIn => '登录';

  @override
  String get signOut => '退出登录';

  @override
  String usageRemaining(int remaining) {
    return '今日剩余 $remaining 条消息';
  }

  @override
  String get upgradePro => '升级到 Pro';

  @override
  String get goPro => '开通 Pro';

  @override
  String get poweredBy => '由 Orbita 驱动';

  @override
  String get freePlan => '免费';

  @override
  String get proPlan => 'Pro';

  @override
  String get freeQuotaHint => '免费：每天 60 条消息 · 每条最多 3 张图（5 MB），每天 8 张';

  @override
  String get proQuotaHint => 'Pro：每天 400 条消息 · 每条最多 8 张图（8 MB），每天 20 张';

  @override
  String messageQuotaReached(String resetsAt) {
    return '已达每日消息上限。请等到下次日重置（$resetsAt）后再继续。';
  }

  @override
  String imageQuotaReached(String resetsAt) {
    return '已达每日图片上传上限。请等到下次日重置（$resetsAt）后再上传。';
  }

  @override
  String monthlyImageAllowanceReached(String resetsAt) {
    return '您已用完本月图片额度。在 $resetsAt 之前，图片上传将暂时按免费额度（每条 3 张，每天 8 张）。文字聊天不受影响。';
  }

  @override
  String get conversations => '对话';

  @override
  String get settings => '设置';

  @override
  String get language => '语言';

  @override
  String get languagePickerHint => '选择应用显示语言';

  @override
  String get searchChats => '搜索对话';

  @override
  String get library => '资料库';

  @override
  String get tools => '工具';

  @override
  String get about => '关于';

  @override
  String get stubAuthHint => '开发版在接入 Supabase 前使用临时令牌。';

  @override
  String get emptyChat => '开始对话';

  @override
  String get streaming => '思考中…';

  @override
  String get stop => '停止';

  @override
  String get storeStubHint =>
      '仅开发环境可用的商店 stub 授权（ALLOW_STORE_STUB_GRANT）。正式版通过应用内购买。';

  @override
  String get storePurchaseHint =>
      '通过 Microsoft Store 应用内购买 Pro（开通 Pro）。支付在 Orbita 内由商店处理。';

  @override
  String get restorePurchases => '恢复购买';

  @override
  String get storeOnlyUpgradeMessage => '升级到 Pro 仅适用于从 Microsoft Store 安装的版本。';

  @override
  String get storePurchaseFailed => '无法完成购买，请稍后重试。';

  @override
  String get authSignInTitle => '登录 Orbita';

  @override
  String get authEmail => '邮箱';

  @override
  String get authPassword => '密码';

  @override
  String get authSignIn => '登录';

  @override
  String get authCreateAccount => '创建账户';

  @override
  String get authSwitchToSignUp => '新用户？创建账户';

  @override
  String get authSwitchToSignIn => '已有账户？登录';

  @override
  String get authUseEmailCode => '改用邮箱验证码登录';

  @override
  String get authUsePassword => '改用密码';

  @override
  String get authSendCode => '发送验证码';

  @override
  String get authCodeLabel => '邮件中的验证码';

  @override
  String get authVerifyCode => '验证';

  @override
  String get authCodeSent => '我们已向你的邮箱发送验证码，请在下方输入。';

  @override
  String get authConfirmEmail => '请查收邮件并确认邮箱地址，然后登录。';

  @override
  String get authFailed => '登录失败，请检查信息后重试。';

  @override
  String get authNotConfigured => '此版本未配置登录功能。';

  @override
  String get authSignOut => '退出登录';

  @override
  String get authAccount => '账户';
}
