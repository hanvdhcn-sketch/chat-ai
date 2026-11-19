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
  });

  final bool ok;
  final String status;
  final String? planTier;
  final String? message;
  final bool stub;
}

/// Microsoft Store IAP / subscription for Flutter Windows.
///
/// **Approach:** WinRT `Windows.Services.Store.StoreContext` via a method
/// channel (`chatai/store_billing`). Do **not** use the `in_app_purchase`
/// plugin as the primary path — it targets iOS/Android, not MS Store.
///
/// Until the Windows runner ships a real StoreContext plugin / C++ bridge,
/// this service returns a clear **stub** so UI and API verify can be exercised
/// locally (`stubGrantPro` on the API in non-production).
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

  /// Whether we believe we are on a Windows Store-capable host.
  bool get isWindowsDesktop {
    if (kIsWeb) return false;
    try {
      return Platform.isWindows;
    } catch (_) {
      return false;
    }
  }

  /// Purchase Pro via Store dialog, then verify entitlement with the API.
  Future<StoreBillingResult> purchasePro() async {
    final native = await _invokeNative('purchase', {
      'storeProductId': storeProductId,
    });

    if (native['status'] == 'cancelled') {
      return const StoreBillingResult(
        ok: false,
        status: 'cancelled',
        message: 'Purchase cancelled',
      );
    }

    if (native['status'] == 'unavailable' || native['stub'] == true) {
      // Sideload / missing WinRT bridge — exercise API stub verify in dev.
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
            'StoreContext not wired — used API stub grant (dev only).',
        stub: true,
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
    );
  }

  /// Restore / re-check Store licenses and sync plan with the API.
  Future<StoreBillingResult> restorePurchases() async {
    final native = await _invokeNative('restore', {
      'storeProductId': storeProductId,
    });

    if (native['status'] == 'unavailable' || native['stub'] == true) {
      final verified = await _api.verifyStoreEntitlement(
        storeProductId: storeProductId,
        userStoreId: native['userStoreId'] as String? ?? 'stub-user-store-id',
        clientLicenseActive: native['licenseActive'] == true,
        stubGrantPro: native['licenseActive'] == true,
      );
      return StoreBillingResult(
        ok: true,
        status: 'stub_restore',
        planTier: verified.planTier,
        message: native['message'] as String? ??
            'StoreContext not wired — restore used API stub.',
        stub: true,
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
    );
  }

  Future<Map<String, dynamic>> _invokeNative(
    String method,
    Map<String, dynamic> args,
  ) async {
    if (!isWindowsDesktop) {
      return {
        'status': 'unavailable',
        'stub': true,
        'message':
            'Microsoft Store billing requires the Windows Store app package.',
      };
    }

    try {
      final raw = await _channel.invokeMethod<dynamic>(method, args);
      if (raw is Map) {
        return Map<String, dynamic>.from(raw);
      }
      return {
        'status': 'unavailable',
        'stub': true,
        'message':
            'StoreContext method channel returned no data (plugin not installed).',
      };
    } on MissingPluginException {
      return {
        'status': 'unavailable',
        'stub': true,
        'message':
            'WinRT StoreContext bridge not linked yet '
            '(channel chatai/store_billing). '
            'Using API stub verify in development. '
            'Product id: $storeProductId',
      };
    } on PlatformException catch (e) {
      return {
        'status': 'error',
        'stub': true,
        'message': e.message ?? e.code,
      };
    }
  }
}
