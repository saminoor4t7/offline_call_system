import 'package:flutter/foundation.dart';

void logd(String tag, String message) {
  if (kDebugMode) debugPrint('[AirCall/$tag] $message');
}

void loge(String tag, Object error, [StackTrace? st]) {
  debugPrint('[AirCall/$tag] ERROR: $error');
  if (kDebugMode && st != null) debugPrint('$st');
}
