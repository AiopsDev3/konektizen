import 'package:flutter/foundation.dart';

enum Environment { dev, staging, prod }

class EnvironmentConfig {
  static Environment get current {
    const env = String.fromEnvironment('APP_ENV');
    switch (env) {
      case 'prod':
        return Environment.prod;
      case 'staging':
        return Environment.staging;
      case 'dev':
        return Environment.dev;
    }
    return Environment.prod;
  }

  /// Get the API base URL for the current environment
  // CHANGE THIS to your PC's LAN IP if testing on real device over WiFi
  static const String apiBaseUrl = 'http://172.16.0.101:3000/api';

  /// Request timeout duration
  static const Duration requestTimeout = Duration(seconds: 30);

  /// Enable debug logging
  static bool get isDebugMode => current == Environment.dev;
}
