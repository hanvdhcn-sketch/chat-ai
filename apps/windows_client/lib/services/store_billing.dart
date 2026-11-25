import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'api_client.dart';

/// Outcome of a Store purchase / restore attempt.
class StoreBillingResult {
  const StoreBillingResult({
    required this.ok,
    required this.status,
    this.planTier,
    this.message,
    this.stub = false,
    this.bridgeLinked = false,
  });

  final bool ok;
  final String status;
  final String? planTier;
  final String? message;
  final bool stub;
  final bool bridgeLinked;
}

/// Microsoft Store IAP / subscription for Flutter Windows.
///
/// **Approach:** WinRT `Windows.Services.Store.StoreContext` via method channel
/// `chatai/store_billing` (registered in the Windows runner). Do **not** use the
/// `in_app_purchase` plugin as the primary path — it targets iOS/Android.
///
/// When the native bridge is linked, Go Pro opens the in-app Store purchase UI.
/// API stub grants are only used when intentionally stubbing (debug + explicit
/// native `stub: true`), never as a silent stand-in for a missing bridge in
/// Release.
class StoreBillingService {
  StoreBillingService({
    required ApiClient api,
    MethodChannel? channel,
  })  : _api = api,
        _channel = channel ?? const MethodChannel('chatai/store_billing');

  final ApiClient _api;
  final MethodChannel _channel;

  static const storeProductId = String.fromEnvironment(
    'MS_STORE_PRO_PRODUCT_ID',
    defaultValue: 'pro_monthly',
  );

  /// Opt-in local stub grant when the Store package is unavailable.
  /// Release builds ignore this unless the native layer also returns stub:true.
  static const allowDevStubGrant = bool.fromEnvironment(
    'ALLOW_STORE_STUB_GRANT',
    defaultValue: false,
  );

  /// Whether we believe we are on a Windows Store-capable host.
  bool get isWindowsDesktop {
    if (kIsWeb) return false;
    try {
      return Platform.isWindows;
    } catch (_) {
      return false;
    }
  }

  /// Purchase Pro via in-app Store dialog, then verify entitlement with the API.
  Future<StoreBillingResult> purchasePro() async {
    final native = await _invokeNative('purchase', {
      'storeProductId': storeProductId,
    });

    if (native['status'] == 'cancelled') {
      return StoreBillingResult(
        ok: false,
        status: 'cancelled',
        message: 'Purchase cancelled',
        bridgeLinked: native['bridgeLinked'] == true,
      );
    }

    if (_shouldUseDevStub(native)) {
      final verified = await _api.verifyStoreEntitlement(
        storeProductId: storeProductId,
        userStoreId: native['userStoreId'] as String? ?? 'stub-user-store-id',
        clientLicenseActive: true,
        stubGrantPro: true,
      );
      return StoreBillingResult(
        ok: verified.planTier == 'pro',
        status: native['status'] as String? ?? 'stub_purchase',
        planTier: verified.planTier,
        message: native['message'] as String? ??
            'Dev stub grant (ALLOW_STORE_STUB_GRANT).',
        stub: true,
        bridgeLinked: native['bridgeLinked'] == true,
      );
    }

    if (_isNativeFailure(native)) {
      return StoreBillingResult(
        ok: false,
        status: native['status'] as String? ?? 'error',
        message: native['message'] as String? ??
            'Store purchase failed. Use Go Pro in the app once the MSIX is '
                'associated with Partner Center (product id: $storeProductId).',
        bridgeLinked: native['bridgeLinked'] == true,
      );
    }

    final verified = await _api.verifyStoreEntitlement(
      storeProductId: storeProductId,
      userStoreId: native['userStoreId'] as String?,
      clientLicenseActive: native['licenseActive'] == true,
    );

    return StoreBillingResult(
      ok: verified.planTier == 'pro',
      status: verified.planTier == 'pro' ? 'purchased' : 'verify_failed',
      planTier: verified.planTier,
      message: verified.reason,
      stub: verified.stub,
      bridgeLinked: native['bridgeLinked'] == true,
    );
  }

  /// Restore / re-check Store licenses and sync plan with the API.
  Future<StoreBillingResult> restorePurchases() async {
    final native = await _invokeNative('restore', {
      'storeProductId': storeProductId,
    });

    if (_shouldUseDevStub(native)) {
      final verified = await _api.verifyStoreEntitlement(
        storeProductId: storeProductId,
        userStoreId: native['userStoreId'] as String? ?? 'stub-user-store-id',
        clientLicenseActive: native['licenseActive'] == true,
        stubGrantPro: native['licenseActive'] == true || allowDevStubGrant,
      );
      return StoreBillingResult(
        ok: true,
        status: 'stub_restore',
        planTier: verified.planTier,
        message: native['message'] as String? ??
            'Dev stub restore (ALLOW_STORE_STUB_GRANT).',
        stub: true,
        bridgeLinked: native['bridgeLinked'] == true,
      );
    }

    if (_isNativeFailure(native) && native['licenseActive'] != true) {
      return StoreBillingResult(
        ok: false,
        status: native['status'] as String? ?? 'error',
        message: native['message'] as String? ?? 'Store restore failed.',
        bridgeLinked: native['bridgeLinked'] == true,
      );
    }

    final verified = await _api.verifyStoreEntitlement(
      storeProductId: storeProductId,
      userStoreId: native['userStoreId'] as String?,
      clientLicenseActive: native['licenseActive'] == true,
    );

    return StoreBillingResult(
      ok: verified.verified,
      status: verified.planTier == 'pro' ? 'restored' : 'no_entitlement',
      planTier: verified.planTier,
      message: verified.reason,
      stub: verified.stub,
      bridgeLinked: native['bridgeLinked'] == true,
    );
  }

  bool _shouldUseDevStub(Map<String, dynamic> native) {
    if (native['stub'] == true && allowDevStubGrant) return true;
    if (native['bridgeLinked'] == true) return false;
    // Missing-plugin / non-Windows: only stub in debug when explicitly allowed.
    return !kReleaseMode && allowDevStubGrant;
  }

  bool _isNativeFailure(Map<String, dynamic> native) {
    final status = native['status'] as String? ?? '';
    return status == 'unavailable' ||
        status == 'store_unavailable' ||
        status == 'error' ||
        native['stub'] == true;
  }

  Future<Map<String, dynamic>> _invokeNative(
    String method,
    Map<String, dynamic> args,
  ) async {
    if (!isWindowsDesktop) {
      return {
        'status': 'unavailable',
        'stub': true,
        'bridgeLinked': false,
        'message':
            'Microsoft Store billing requires the Windows Store app package.',
      };
    }

    try {
      final raw = await _channel.invokeMethod<dynamic>(method, args);
      if (raw is Map) {
        final map = Map<String, dynamic>.from(raw);
        map.putIfAbsent('bridgeLinked', () => true);
        map.putIfAbsent('stub', () => false);
        return map;
      }
      return {
        'status': 'unavailable',
        'stub': true,
        'bridgeLinked': false,
        'message':
            'StoreContext method channel returned no data (plugin not installed).',
      };
    } on MissingPluginException {
      return {
        'status': 'unavailable',
        'stub': true,
        'bridgeLinked': false,
        'message':
            'WinRT StoreContext bridge not linked yet '
            '(channel chatai/store_billing). '
            'Rebuild the Windows runner. Product id: $storeProductId',
      };
    } on PlatformException catch (e) {
      return {
        'status': 'error',
        'stub': false,
        'bridgeLinked': true,
        'message': e.message ?? e.code,
      };
    }
  }
}
