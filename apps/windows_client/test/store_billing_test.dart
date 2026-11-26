import 'package:chatai/l10n/app_localizations.dart';
import 'package:chatai/services/api_client.dart';
import 'package:chatai/services/store_billing.dart';
import 'dart:ui' show Locale;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('chatai/store_billing');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('unpackaged build maps to storeUnavailable without raw banner text',
      () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      return <String, dynamic>{
        'bridgeLinked': true,
        'stub': false,
        'packaged': false,
        'status': call.method == 'ping' ? 'ok' : 'store_unavailable',
        'licenseActive': false,
        'message': 'technical detail',
      };
    });

    final service = StoreBillingService(
      api: ApiClient(getToken: () async => 'stub:user_demo:free'),
      channel: channel,
    );
    final result = await service.purchasePro();
    expect(result.ok, isFalse);
    expect(result.storeUnavailable, isTrue);
  });

  test('every UI language ships the friendly Store-only upgrade message', () {
    for (final locale in AppLocalizations.supportedLocales) {
      final loc = lookupAppLocalizations(locale);
      expect(loc.storeOnlyUpgradeMessage, isNotEmpty, reason: '$locale');
      expect(loc.storePurchaseFailed, isNotEmpty, reason: '$locale');
      expect(loc.storeOnlyUpgradeMessage.contains('Partner Center'), isFalse);
    }
    expect(
      lookupAppLocalizations(const Locale('en')).storeOnlyUpgradeMessage,
      'Upgrading to Pro is only available in the version installed from '
      'Microsoft Store.',
    );
  });
}
