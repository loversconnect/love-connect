import 'package:flutter/foundation.dart';

class ApiConfig {
  const ApiConfig._();
  static const String _productionBaseUrl = 'https://api.loversconnectmw.com';

  static String get baseUrl {
    const fromDefine = String.fromEnvironment('API_BASE_URL');
    if (fromDefine.isNotEmpty) return fromDefine;

    if (kIsWeb) return _productionBaseUrl;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return _productionBaseUrl;
    }
  }
}
