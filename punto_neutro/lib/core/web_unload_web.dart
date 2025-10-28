// Web implementation to detect full tab/window close and run a callback
import 'dart:html' as html;

html.EventListener? _pagehideListener;

void registerBeforeUnload(void Function() onUnload) {
  // Use 'pagehide' instead of 'beforeunload' because pagehide fires
  // reliably on tab close/navigation and gives us a sync execution window.
  // This is more reliable than beforeunload which browsers increasingly ignore.
  _pagehideListener ??= (event) {
    try {
      print('🔴 [WEB] pagehide event fired, calling onUnload');
      onUnload();
    } catch (e) {
      print('Error in pagehide callback: $e');
    }
  };
  html.window.addEventListener('pagehide', _pagehideListener!);
}

void unregisterBeforeUnload() {
  if (_pagehideListener != null) {
    html.window.removeEventListener('pagehide', _pagehideListener!);
    _pagehideListener = null;
  }
}