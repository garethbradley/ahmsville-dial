//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <dotup_flutter_active_window/dotup_flutter_active_window_plugin.h>
#include <flutter_libserialport/flutter_libserialport_plugin.h>
#include <screen_retriever/screen_retriever_plugin.h>
#include <window_manager/window_manager_plugin.h>

void fl_register_plugins(FlPluginRegistry* registry) {
  g_autoptr(FlPluginRegistrar) dotup_flutter_active_window_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "DotupFlutterActiveWindowPlugin");
  dotup_flutter_active_window_plugin_register_with_registrar(dotup_flutter_active_window_registrar);
  g_autoptr(FlPluginRegistrar) flutter_libserialport_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "FlutterLibserialportPlugin");
  flutter_libserialport_plugin_register_with_registrar(flutter_libserialport_registrar);
  g_autoptr(FlPluginRegistrar) screen_retriever_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "ScreenRetrieverPlugin");
  screen_retriever_plugin_register_with_registrar(screen_retriever_registrar);
  g_autoptr(FlPluginRegistrar) window_manager_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "WindowManagerPlugin");
  window_manager_plugin_register_with_registrar(window_manager_registrar);
}
