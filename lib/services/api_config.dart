import 'package:flutter/foundation.dart';

class ApiConfig {
  static const String _envBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');
  static bool _logged = false;

  static String get baseUrl {
    String url = _envBaseUrl;
    if (url.isEmpty) {
      if (kIsWeb) {
        url = 'http://localhost:8000';
      } else {
        switch (defaultTargetPlatform) {
          case TargetPlatform.android:
            url = 'http://10.0.2.2:8000';
          default:
            url = 'http://localhost:8000';
        }
      }
    }

    // Note: 0.0.0.0 is a server bind address, not a valid client base URL.
    // We only warn here (no auto-rewrite) because:
    // - Android emulator uses 10.0.2.2 to reach the host
    // - Physical Android devices often use 127.0.0.1 with `adb reverse`
    if (url.contains('0.0.0.0')) {
      debugPrint(
        '[API] WARNING: baseUrl contains 0.0.0.0. '
        'Use 10.0.2.2 for Android emulator, 127.0.0.1 for adb reverse, or your Mac LAN IP for a physical device.',
      );
    }

    if (!_logged) {
      _logged = true;
      debugPrint('[API] baseUrl=$url');
    }

    return url;
  }
}
