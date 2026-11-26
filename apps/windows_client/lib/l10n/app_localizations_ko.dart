// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get appTitle => 'Orbita';

  @override
  String get newChat => '새 채팅';

  @override
  String get send => '보내기';

  @override
  String get messageHint => 'Orbita에 메시지…';

  @override
  String get signIn => '로그인';

  @override
  String get signOut => '로그아웃';

  @override
  String usageRemaining(int remaining) {
    return '오늘 메시지 $remaining개 남음';
  }

  @override
  String get upgradePro => 'Pro로 업그레이드';

  @override
  String get goPro => 'Go Pro';

  @override
  String get poweredBy => 'Powered by Orbita';

  @override
  String get freePlan => '무료';

  @override
  String get proPlan => 'Pro';

  @override
  String get freeQuotaHint => '무료: 하루 60메시지 · 메시지당 최대 3이미지(5 MB), 하루 8장';

  @override
  String get proQuotaHint => 'Pro: 하루 400메시지 · 메시지당 최대 8이미지(8 MB), 하루 20장';

  @override
  String messageQuotaReached(String resetsAt) {
    return '일일 메시지 한도에 도달했습니다. 다음 초기화($resetsAt)까지 기다려 주세요.';
  }

  @override
  String imageQuotaReached(String resetsAt) {
    return '일일 이미지 업로드 한도에 도달했습니다. 다음 초기화($resetsAt)까지 기다려 주세요.';
  }

  @override
  String monthlyImageAllowanceReached(String resetsAt) {
    return '이번 달 이미지 한도에 도달했습니다. $resetsAt까지 이미지는 무료 한도(메시지당 3장, 하루 8장)를 사용합니다. 텍스트 채팅은 영향 없습니다.';
  }

  @override
  String get conversations => '대화';

  @override
  String get settings => '설정';

  @override
  String get language => '언어';

  @override
  String get languagePickerHint => '앱 표시 언어 선택';

  @override
  String get searchChats => '채팅 검색';

  @override
  String get library => '라이브러리';

  @override
  String get tools => '도구';

  @override
  String get about => '정보';

  @override
  String get stubAuthHint => 'Supabase 연동 전까지 개발용 스텁 토큰을 사용합니다.';

  @override
  String get emptyChat => '대화를 시작하세요';

  @override
  String get streaming => '생각 중…';

  @override
  String get stop => '중지';

  @override
  String get storeStubHint =>
      '개발 전용 Store stub(ALLOW_STORE_STUB_GRANT). 일반 빌드는 인앱 구매를 사용합니다.';

  @override
  String get storePurchaseHint =>
      'Microsoft Store 인앱 구매로 Pro를 구매하세요(Go Pro). 결제는 Orbita 내에서 처리됩니다.';

  @override
  String get restorePurchases => '구매 복원';

  @override
  String get storeOnlyUpgradeMessage =>
      'Pro 업그레이드는 Microsoft Store에서 설치한 버전에서만 사용할 수 있습니다.';

  @override
  String get storePurchaseFailed => '구매를 완료하지 못했습니다. 나중에 다시 시도해 주세요.';

  @override
  String get authSignInTitle => 'Orbita 로그인';

  @override
  String get authEmail => '이메일';

  @override
  String get authPassword => '비밀번호';

  @override
  String get authSignIn => '로그인';

  @override
  String get authCreateAccount => '계정 만들기';

  @override
  String get authSwitchToSignUp => '처음이신가요? 계정 만들기';

  @override
  String get authSwitchToSignIn => '이미 계정이 있나요? 로그인';

  @override
  String get authUseEmailCode => '이메일로 로그인 코드 받기';

  @override
  String get authUsePassword => '비밀번호 사용';

  @override
  String get authSendCode => '코드 보내기';

  @override
  String get authCodeLabel => '이메일로 받은 코드';

  @override
  String get authVerifyCode => '확인';

  @override
  String get authCodeSent => '이메일로 코드를 보냈습니다. 아래에 입력하세요.';

  @override
  String get authConfirmEmail => '이메일을 확인해 주소를 인증한 다음 로그인하세요.';

  @override
  String get authFailed => '로그인에 실패했습니다. 입력한 정보를 확인하고 다시 시도하세요.';

  @override
  String get authNotConfigured => '이 빌드에는 로그인이 구성되어 있지 않습니다.';

  @override
  String get authSignOut => '로그아웃';

  @override
  String get authAccount => '계정';
}
