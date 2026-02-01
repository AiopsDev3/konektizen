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
  // C3 Command Center Backend (handles ALL auth, SOS, and reports)
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:5001/api', // Default to Android Emulator
  );

  static const String signalingUrl = String.fromEnvironment(
    'SIGNALING_URL',
    defaultValue: 'http://10.0.2.2:5001',
  );

  /// Request timeout duration
  static const Duration requestTimeout = Duration(seconds: 30);

  /// Enable debug logging
  static bool get isDebugMode => current == Environment.dev;
}
