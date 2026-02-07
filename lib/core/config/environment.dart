// AUTO-GENERATED from c3_config.yaml
// DO NOT EDIT MANUALLY - Run: python generate_dart_config.py

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

  /// API base URL (Generated from c3_config.yaml)
  static const String apiBaseUrl = 'http://192.168.100.166:5001/api';
  
  /// Signaling URL (Generated from c3_config.yaml)
  static const String signalingUrl = 'http://192.168.100.166:5001';

  /// Request timeout duration
  static const Duration requestTimeout = Duration(seconds: 30);

  /// Enable debug logging
  static bool get isDebugMode => current == Environment.dev;
}
