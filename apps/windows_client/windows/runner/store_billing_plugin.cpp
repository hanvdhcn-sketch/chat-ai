#include "store_billing_plugin.h"

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <appmodel.h>
#include <shobjidl.h>

#include <winrt/Windows.Foundation.Collections.h>
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Services.Store.h>

#include <memory>
#include <string>
#include <string_view>

namespace {

using flutter::EncodableMap;
using flutter::EncodableValue;
using winrt::Windows::Foundation::IAsyncOperation;
using winrt::Windows::Services::Store::StoreAppLicense;
using winrt::Windows::Services::Store::StoreContext;
using winrt::Windows::Services::Store::StoreLicense;
using winrt::Windows::Services::Store::StoreProduct;
using winrt::Windows::Services::Store::StorePurchaseResult;
using winrt::Windows::Services::Store::StorePurchaseStatus;

bool IsRunningPackaged() {
  UINT32 length = 0;
  LONG rc = GetCurrentPackageFullName(&length, nullptr);
  return rc != APPMODEL_ERROR_NO_PACKAGE;
}

std::string WideToUtf8(std::wstring_view value) {
  if (value.empty()) {
    return {};
  }
  int size = WideCharToMultiByte(CP_UTF8, 0, value.data(),
                                 static_cast<int>(value.size()), nullptr, 0,
                                 nullptr, nullptr);
  if (size <= 0) {
    return {};
  }
  std::string out(static_cast<size_t>(size), '\0');
  WideCharToMultiByte(CP_UTF8, 0, value.data(), static_cast<int>(value.size()),
                      out.data(), size, nullptr, nullptr);
  return out;
}

std::wstring Utf8ToWide(std::string_view value) {
  if (value.empty()) {
    return {};
  }
  int size = MultiByteToWideChar(CP_UTF8, 0, value.data(),
                                 static_cast<int>(value.size()), nullptr, 0);
  if (size <= 0) {
    return {};
  }
  std::wstring out(static_cast<size_t>(size), L'\0');
  MultiByteToWideChar(CP_UTF8, 0, value.data(), static_cast<int>(value.size()),
                      out.data(), size);
  return out;
}

void LogStoreDebug(std::string const& line) {
  std::string out = "[chatai/store_billing] " + line + "\n";
  OutputDebugStringA(out.c_str());
}

EncodableMap BaseResponse() {
  EncodableMap map;
  map[EncodableValue("bridgeLinked")] = EncodableValue(true);
  map[EncodableValue("stub")] = EncodableValue(false);
  map[EncodableValue("packaged")] = EncodableValue(IsRunningPackaged());
  return map;
}

void ReplyMap(std::unique_ptr<flutter::MethodResult<EncodableValue>> result,
              EncodableMap map) {
  result->Success(EncodableValue(std::move(map)));
}

StoreContext GetStoreContext(HWND hwnd) {
  StoreContext context = StoreContext::GetDefault();
  if (hwnd != nullptr) {
    auto init = context.as<::IInitializeWithWindow>();
    init->Initialize(hwnd);
  }
  return context;
}

bool LicenseMatchesProduct(StoreLicense const& license,
                           winrt::hstring const& key,
                           std::wstring const& product_id) {
  if (!license.IsActive()) {
    return false;
  }
  auto sku = std::wstring(license.SkuStoreId().c_str());
  auto key_w = std::wstring(key.c_str());
  auto offer = std::wstring(license.InAppOfferToken().c_str());
  if (_wcsicmp(offer.c_str(), product_id.c_str()) == 0 ||
      _wcsicmp(sku.c_str(), product_id.c_str()) == 0 ||
      _wcsicmp(key_w.c_str(), product_id.c_str()) == 0) {
    return true;
  }
  // Soft match for local SKUs that embed the offer token (e.g. "...pro_monthly").
  if (!product_id.empty() &&
      (key_w.find(product_id) != std::wstring::npos ||
       sku.find(product_id) != std::wstring::npos)) {
    return true;
  }
  return false;
}

bool HasActiveAddOn(StoreAppLicense const& app_license,
                    std::wstring const& product_id) {
  for (auto const& pair : app_license.AddOnLicenses()) {
    if (LicenseMatchesProduct(pair.Value(), pair.Key(), product_id)) {
      return true;
    }
  }
  return false;
}

winrt::Windows::Foundation::IAsyncOperation<bool> QueryLicenseActiveAsync(
    StoreContext context,
    std::wstring product_id) {
  StoreAppLicense license = co_await context.GetAppLicenseAsync();
  co_return HasActiveAddOn(license, product_id);
}

winrt::Windows::Foundation::IAsyncOperation<StoreProduct> FindStoreProductAsync(
    StoreContext context,
    std::wstring product_id) {
  auto kinds = winrt::single_threaded_vector<winrt::hstring>(
      {L"Durable", L"Subscription"});
  auto query = co_await context.GetAssociatedStoreProductsAsync(kinds.GetView());
  if (query.ExtendedError().value != S_OK) {
    LogStoreDebug("GetAssociatedStoreProductsAsync failed: hr=0x" +
                  std::to_string(static_cast<unsigned int>(
                      query.ExtendedError().value)));
  }
  for (auto const& pair : query.Products()) {
    StoreProduct product = pair.Value();
    auto offer = std::wstring(product.InAppOfferToken().c_str());
    auto store_id = std::wstring(product.StoreId().c_str());
    if (_wcsicmp(offer.c_str(), product_id.c_str()) == 0 ||
        _wcsicmp(store_id.c_str(), product_id.c_str()) == 0) {
      co_return product;
    }
  }
  co_return nullptr;
}

std::wstring ReadProductId(EncodableMap const* args) {
  if (args == nullptr) {
    return L"pro_monthly";
  }
  auto it = args->find(EncodableValue("storeProductId"));
  if (it == args->end() || !std::holds_alternative<std::string>(it->second)) {
    return L"pro_monthly";
  }
  auto utf8 = std::get<std::string>(it->second);
  auto wide = Utf8ToWide(utf8);
  return wide.empty() ? L"pro_monthly" : wide;
}

std::string ReadOptionalString(EncodableMap const* args, char const* key) {
  if (args == nullptr) {
    return {};
  }
  auto it = args->find(EncodableValue(key));
  if (it == args->end() || !std::holds_alternative<std::string>(it->second)) {
    return {};
  }
  return std::get<std::string>(it->second);
}

// Best-effort: exchange the API-issued AAD token for the User Store ID key the
// backend needs to query the Collections API. Never fails the purchase/restore.
winrt::Windows::Foundation::IAsyncOperation<winrt::hstring>
TryGetCollectionsIdAsync(StoreContext context,
                         std::string service_access_token,
                         std::string publisher_user_id) {
  if (service_access_token.empty()) {
    co_return winrt::hstring{};
  }
  try {
    co_return co_await context.GetCustomerCollectionsIdAsync(
        winrt::to_hstring(service_access_token),
        winrt::to_hstring(publisher_user_id));
  } catch (winrt::hresult_error const& ex) {
    LogStoreDebug("GetCustomerCollectionsIdAsync failed: " +
                  WideToUtf8(ex.message().c_str()));
  } catch (...) {
  }
  co_return winrt::hstring{};
}

winrt::fire_and_forget HandlePurchaseAsync(
    HWND hwnd,
    std::wstring product_id,
    std::string service_access_token,
    std::string publisher_user_id,
    std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
  auto reply = BaseResponse();
  try {
    if (!IsRunningPackaged()) {
      LogStoreDebug("purchase: not packaged (no package identity).");
      reply[EncodableValue("status")] = EncodableValue("store_unavailable");
      reply[EncodableValue("licenseActive")] = EncodableValue(false);
      reply[EncodableValue("message")] = EncodableValue(
          "Microsoft Store purchase requires an MSIX package associated with "
          "Partner Center. Unpackaged builds cannot open the Store purchase UI.");
      ReplyMap(std::move(result), std::move(reply));
      co_return;
    }

    StoreContext context = GetStoreContext(hwnd);
    StoreProduct product = co_await FindStoreProductAsync(context, product_id);
    if (!product) {
      LogStoreDebug("purchase: add-on not found for product id " +
                    WideToUtf8(product_id));
      reply[EncodableValue("status")] = EncodableValue("product_not_found");
      reply[EncodableValue("licenseActive")] = EncodableValue(false);
      reply[EncodableValue("message")] = EncodableValue(
          "Store add-on '" + WideToUtf8(product_id) +
          "' was not found for this app (is it published in Partner Center "
          "and is the package Store-associated?).");
      ReplyMap(std::move(result), std::move(reply));
      co_return;
    }

    StorePurchaseResult purchase = co_await product.RequestPurchaseAsync();

    switch (purchase.Status()) {
      case StorePurchaseStatus::Succeeded:
      case StorePurchaseStatus::AlreadyPurchased: {
        // The purchase result is authoritative; the cached app license can lag
        // briefly, so the license query is informational only.
        bool active = co_await QueryLicenseActiveAsync(context, product_id);
        LogStoreDebug(std::string("purchase succeeded; license cache active=") +
                      (active ? "true" : "false"));
        reply[EncodableValue("status")] = EncodableValue(
            purchase.Status() == StorePurchaseStatus::AlreadyPurchased
                ? "already_purchased"
                : "purchased");
        reply[EncodableValue("licenseActive")] = EncodableValue(true);
        reply[EncodableValue("message")] =
            EncodableValue("Store purchase completed.");
        auto collections_id = co_await TryGetCollectionsIdAsync(
            context, service_access_token, publisher_user_id);
        if (!collections_id.empty()) {
          reply[EncodableValue("userStoreId")] =
              EncodableValue(WideToUtf8(collections_id.c_str()));
        }
        break;
      }
      case StorePurchaseStatus::NotPurchased:
        reply[EncodableValue("status")] = EncodableValue("cancelled");
        reply[EncodableValue("licenseActive")] = EncodableValue(false);
        reply[EncodableValue("message")] =
            EncodableValue("Purchase cancelled.");
        break;
      case StorePurchaseStatus::NetworkError:
        reply[EncodableValue("status")] = EncodableValue("error");
        reply[EncodableValue("licenseActive")] = EncodableValue(false);
        reply[EncodableValue("message")] =
            EncodableValue("Store network error during purchase.");
        break;
      case StorePurchaseStatus::ServerError:
        reply[EncodableValue("status")] = EncodableValue("error");
        reply[EncodableValue("licenseActive")] = EncodableValue(false);
        reply[EncodableValue("message")] =
            EncodableValue("Store server error during purchase.");
        break;
      default: {
        std::string detail = "Store purchase failed.";
        winrt::hresult const hr = purchase.ExtendedError();
        if (hr != S_OK) {
          detail.push_back(' ');
          detail += WideToUtf8(
              winrt::hresult_error(hr).message().c_str());
        }
        reply[EncodableValue("status")] = EncodableValue("error");
        reply[EncodableValue("licenseActive")] = EncodableValue(false);
        reply[EncodableValue("message")] = EncodableValue(detail);
        break;
      }
    }
  } catch (winrt::hresult_error const& ex) {
    reply[EncodableValue("status")] = EncodableValue("error");
    reply[EncodableValue("licenseActive")] = EncodableValue(false);
    reply[EncodableValue("message")] =
        EncodableValue(WideToUtf8(ex.message().c_str()));
  } catch (...) {
    reply[EncodableValue("status")] = EncodableValue("error");
    reply[EncodableValue("licenseActive")] = EncodableValue(false);
    reply[EncodableValue("message")] =
        EncodableValue("Unexpected Store purchase failure.");
  }
  ReplyMap(std::move(result), std::move(reply));
}

winrt::fire_and_forget HandleRestoreAsync(
    HWND hwnd,
    std::wstring product_id,
    std::string service_access_token,
    std::string publisher_user_id,
    std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
  auto reply = BaseResponse();
  try {
    if (!IsRunningPackaged()) {
      reply[EncodableValue("status")] = EncodableValue("store_unavailable");
      reply[EncodableValue("licenseActive")] = EncodableValue(false);
      reply[EncodableValue("message")] = EncodableValue(
          "Restore requires an MSIX package associated with Partner Center.");
      ReplyMap(std::move(result), std::move(reply));
      co_return;
    }

    StoreContext context = GetStoreContext(hwnd);
    bool active = co_await QueryLicenseActiveAsync(context, product_id);
    reply[EncodableValue("licenseActive")] = EncodableValue(active);
    reply[EncodableValue("status")] =
        EncodableValue(active ? "restored" : "no_entitlement");
    reply[EncodableValue("message")] = EncodableValue(
        active ? "Active Pro license found in Store."
               : "No active Pro Store license for this account.");

    // Optional Collections identity when the API supplied a service access token.
    auto collections_id = co_await TryGetCollectionsIdAsync(
        context, service_access_token, publisher_user_id);
    if (!collections_id.empty()) {
      reply[EncodableValue("userStoreId")] =
          EncodableValue(WideToUtf8(collections_id.c_str()));
    }
  } catch (winrt::hresult_error const& ex) {
    reply[EncodableValue("status")] = EncodableValue("error");
    reply[EncodableValue("licenseActive")] = EncodableValue(false);
    reply[EncodableValue("message")] =
        EncodableValue(WideToUtf8(ex.message().c_str()));
  } catch (...) {
    reply[EncodableValue("status")] = EncodableValue("error");
    reply[EncodableValue("licenseActive")] = EncodableValue(false);
    reply[EncodableValue("message")] =
        EncodableValue("Unexpected Store restore failure.");
  }
  ReplyMap(std::move(result), std::move(reply));
}

class StoreBillingHandler {
 public:
  explicit StoreBillingHandler(HWND hwnd) : hwnd_(hwnd) {}

  void HandleMethodCall(
      flutter::MethodCall<EncodableValue> const& call,
      std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
    EncodableMap const* args = nullptr;
    if (auto* map = std::get_if<EncodableMap>(call.arguments())) {
      args = map;
    }

    if (call.method_name() == "ping") {
      auto reply = BaseResponse();
      reply[EncodableValue("status")] = EncodableValue("ok");
      ReplyMap(std::move(result), std::move(reply));
      return;
    }

    if (call.method_name() == "purchase") {
      HandlePurchaseAsync(hwnd_, ReadProductId(args),
                          ReadOptionalString(args, "serviceAccessToken"),
                          ReadOptionalString(args, "publisherUserId"),
                          std::move(result));
      return;
    }

    if (call.method_name() == "restore") {
      HandleRestoreAsync(hwnd_, ReadProductId(args),
                         ReadOptionalString(args, "serviceAccessToken"),
                         ReadOptionalString(args, "publisherUserId"),
                         std::move(result));
      return;
    }

    result->NotImplemented();
  }

 private:
  HWND hwnd_;
};

}  // namespace

void RegisterStoreBillingPlugin(flutter::BinaryMessenger* messenger, HWND hwnd) {
  auto channel =
      std::make_unique<flutter::MethodChannel<EncodableValue>>(
          messenger, "chatai/store_billing",
          &flutter::StandardMethodCodec::GetInstance());

  auto handler = std::make_shared<StoreBillingHandler>(hwnd);
  channel->SetMethodCallHandler(
      [handler](flutter::MethodCall<EncodableValue> const& call,
                std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
        handler->HandleMethodCall(call, std::move(result));
      });

  // Keep the channel alive for the process lifetime.
  static auto retained_channel = std::move(channel);
  static auto retained_handler = handler;
}
