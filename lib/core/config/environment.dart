// AUTO-GENERATED from c3_config.yaml
// DO NOT EDIT MANUALLY - Run: python generate_dart_config.py

import 'package:konektizen/core/config/server_connection_config.dart';

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
  static String get apiBaseUrl => ServerConnectionConfig.instance.apiBaseUrl;

  /// Signaling URL (Generated from c3_config.yaml)
  static String get signalingUrl =>
      ServerConnectionConfig.instance.signalingUrl;

  /// Request timeout duration
  static const Duration requestTimeout = Duration(seconds: 30);

  /// Enable debug logging
  static bool get isDebugMode => current == Environment.dev;
}
