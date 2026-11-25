#ifndef RUNNER_STORE_BILLING_PLUGIN_H_
#define RUNNER_STORE_BILLING_PLUGIN_H_

#include <flutter/binary_messenger.h>

#include <windows.h>

// Registers method channel `chatai/store_billing` → WinRT StoreContext.
// |hwnd| is the top-level window used as owner for Store purchase dialogs.
void RegisterStoreBillingPlugin(flutter::BinaryMessenger* messenger, HWND hwnd);

#endif  // RUNNER_STORE_BILLING_PLUGIN_H_
