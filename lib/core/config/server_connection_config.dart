import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ServerConnectionConfig extends ChangeNotifier {
  static const String defaultOrigin = 'https://c3.aitelligenz.com';
  static const String _legacyMontalbanOrigin =
      'http://montalban.c3.aitelligenz.com:5175';
  static const String _storageKey = 'c3_server_origin';
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static final ServerConnectionConfig instance = ServerConnectionConfig._();

  ServerConnectionConfig._();

  String _origin = defaultOrigin;

  String get origin => _origin;
  String get apiBaseUrl => '$_origin/api';
  String get signalingUrl => _origin;
  String get videoApiBaseUrl {
    const override = String.fromEnvironment('VIDEO_CONFERENCE_API_URL');
    if (override.trim().isNotEmpty) {
      return _trimTrailingSlash(override.trim());
    }

    final parsed = Uri.parse(_origin);
    final scheme = parsed.scheme.isEmpty ? 'http' : parsed.scheme;
    if (scheme == 'https') {
      final uri = Uri(
        scheme: scheme,
        host: parsed.host,
        port: parsed.hasPort ? parsed.port : null,
        path: 'video-api',
      );
      return _trimTrailingSlash(uri.toString());
    }

    final uri = Uri(
      scheme: scheme,
      host: parsed.host,
      port: 3000,
    );
    return _trimTrailingSlash(uri.toString());
  }

  Future<void> load() async {
    final saved = await _storage.read(key: _storageKey);
    if (saved == null || saved.trim().isEmpty) return;
    try {
      final next = normalizeOrigin(saved);
      _origin = next == _legacyMontalbanOrigin ? defaultOrigin : next;
    } catch (_) {
      _origin = defaultOrigin;
    }
  }

  Future<void> save(String value) async {
    final next = normalizeOrigin(value);
    await _storage.write(key: _storageKey, value: next);
    if (_origin == next) return;
    _origin = next;
    notifyListeners();
  }

  Future<void> reset() async {
    await _storage.delete(key: _storageKey);
    if (_origin == defaultOrigin) return;
    _origin = defaultOrigin;
    notifyListeners();
  }

  static String normalizeOrigin(String value) {
    var raw = value.trim();
    if (raw.isEmpty) {
      throw const FormatException('Server address is required.');
    }

    if (!raw.startsWith('http://') && !raw.startsWith('https://')) {
      raw = 'http://$raw';
    }

    final parsed = Uri.tryParse(raw);
    if (parsed == null || parsed.host.trim().isEmpty) {
      throw const FormatException('Enter a valid domain or IP address.');
    }

    var path = parsed.path;
    if (path == '/api' || path == '/api/') {
      path = '';
    }
    if (path.isNotEmpty && path != '/') {
      throw const FormatException('Use only the server domain/IP and port.');
    }

    final normalized = parsed.replace(path: '', query: null, fragment: null);
    final text = normalized.toString();
    return text.endsWith('/') ? text.substring(0, text.length - 1) : text;
  }

  static String _trimTrailingSlash(String value) {
    return value.endsWith('/') ? value.substring(0, value.length - 1) : value;
  }
}
