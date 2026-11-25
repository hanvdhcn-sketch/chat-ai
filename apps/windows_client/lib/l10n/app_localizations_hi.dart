// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get appTitle => 'Orbita';

  @override
  String get newChat => 'नई चैट';

  @override
  String get send => 'भेजें';

  @override
  String get messageHint => 'Orbita को संदेश…';

  @override
  String get signIn => 'साइन इन';

  @override
  String get signOut => 'साइन आउट';

  @override
  String usageRemaining(int remaining) {
    return 'आज $remaining संदेश शेष';
  }

  @override
  String get upgradePro => 'Pro में अपग्रेड करें';

  @override
  String get goPro => 'Go Pro';

  @override
  String get poweredBy => 'Powered by Orbita';

  @override
  String get freePlan => 'मुफ़्त';

  @override
  String get proPlan => 'Pro';

  @override
  String get freeQuotaHint =>
      'मुफ़्त: 60 संदेश/दिन · प्रति संदेश अधिकतम 3 छवियाँ (5 MB), 8/दिन';

  @override
  String get proQuotaHint =>
      'Pro: 400 संदेश/दिन · प्रति संदेश अधिकतम 8 छवियाँ (8 MB), 20/दिन';

  @override
  String messageQuotaReached(String resetsAt) {
    return 'दैनिक संदेश सीमा पूरी हो गई। जारी रखने के लिए अगले रीसेट ($resetsAt) तक प्रतीक्षा करें।';
  }

  @override
  String imageQuotaReached(String resetsAt) {
    return 'दैनिक छवि अपलोड सीमा पूरी हो गई। और अपलोड करने के लिए अगले रीसेट ($resetsAt) तक प्रतीक्षा करें।';
  }

  @override
  String monthlyImageAllowanceReached(String resetsAt) {
    return 'आपने इस महीने की छवि सीमा पूरी कर ली है। $resetsAt तक अपलोड मुफ़्त सीमा (प्रति संदेश 3, प्रति दिन 8) का उपयोग करेंगे। टेक्स्ट चैट प्रभावित नहीं होगी।';
  }

  @override
  String get conversations => 'बातचीत';

  @override
  String get settings => 'सेटिंग्स';

  @override
  String get language => 'भाषा';

  @override
  String get languagePickerHint => 'ऐप प्रदर्शन भाषा चुनें';

  @override
  String get searchChats => 'चैट खोजें';

  @override
  String get library => 'लाइब्रेरी';

  @override
  String get tools => 'टूल्स';

  @override
  String get about => 'परिचय';

  @override
  String get stubAuthHint =>
      'Supabase जुड़ने तक डेव ऑथ स्टब टोकन उपयोग करता है।';

  @override
  String get emptyChat => 'बातचीत शुरू करें';

  @override
  String get streaming => 'सोच रहा है…';

  @override
  String get stop => 'रोकें';

  @override
  String get storeStubHint =>
      'केवल डेव Store stub अनुदान (ALLOW_STORE_STUB_GRANT)। सामान्य बिल्ड इन-ऐप खरीद उपयोग करते हैं।';

  @override
  String get storePurchaseHint =>
      'Microsoft Store के ज़रिए ऐप में Pro खरीदें (Go Pro)। Store भुगतान Orbita में प्रोसेस करता है।';

  @override
  String get restorePurchases => 'खरीदारी पुनर्स्थापित करें';
}
