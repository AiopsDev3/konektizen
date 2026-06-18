import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ServerConnectionConfig extends ChangeNotifier {
  static const String defaultOrigin = 'https://c3.aitelligenz.com';
  static const String _legacyMontalbanOrigin =
      'http://montalban.c3.aitelligenz.com:5175';
  static const String _storageKey = 'c3_server_origin';
  static const String _videoApiStorageKey = 'c3_video_api_url';
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static final ServerConnectionConfig instance = ServerConnectionConfig._();

  ServerConnectionConfig._();

  String _origin = defaultOrigin;
  String? _videoApiOverride;

  String get origin => _origin;
  String get apiBaseUrl => '$_origin/api';
  String get signalingUrl => _origin;
  String? get videoApiOverride => _videoApiOverride;
  String get videoApiBaseUrl {
    const override = String.fromEnvironment('VIDEO_CONFERENCE_API_URL');
    if (override.trim().isNotEmpty) {
      return _trimTrailingSlash(override.trim());
    }
    final savedOverride = _videoApiOverride?.trim();
    if (savedOverride != null && savedOverride.isNotEmpty) {
      return savedOverride;
    }

    return '$apiBaseUrl/livekit';
  }

  Future<void> load() async {
    final saved = await _storage.read(key: _storageKey);
    final savedVideoApi = await _storage.read(key: _videoApiStorageKey);
    if (savedVideoApi != null && savedVideoApi.trim().isNotEmpty) {
      try {
        _videoApiOverride = normalizeVideoApiUrl(savedVideoApi);
      } catch (_) {
        _videoApiOverride = null;
      }
    }
    if (saved == null || saved.trim().isEmpty) return;
    try {
      final next = normalizeOrigin(saved);
      _origin = next == _legacyMontalbanOrigin ? defaultOrigin : next;
    } catch (_) {
      _origin = defaultOrigin;
    }
  }

  Future<void> save(String value, {String? videoApiUrl}) async {
    final next = normalizeOrigin(value);
    await _storage.write(key: _storageKey, value: next);
    final nextVideoApi = normalizeOptionalVideoApiUrl(videoApiUrl);
    if (nextVideoApi == null) {
      await _storage.delete(key: _videoApiStorageKey);
    } else {
      await _storage.write(key: _videoApiStorageKey, value: nextVideoApi);
    }
    if (_origin == next && _videoApiOverride == nextVideoApi) return;
    _origin = next;
    _videoApiOverride = nextVideoApi;
    notifyListeners();
  }

  Future<void> reset() async {
    await _storage.delete(key: _storageKey);
    await _storage.delete(key: _videoApiStorageKey);
    if (_origin == defaultOrigin && _videoApiOverride == null) return;
    _origin = defaultOrigin;
    _videoApiOverride = null;
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

  static String? normalizeOptionalVideoApiUrl(String? value) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) return null;
    return normalizeVideoApiUrl(raw);
  }

  static String normalizeVideoApiUrl(String value) {
    var raw = value.trim();
    if (raw.isEmpty) {
      throw const FormatException('Video API URL is required.');
    }

    if (!raw.startsWith('http://') && !raw.startsWith('https://')) {
      raw = 'http://$raw';
    }

    final parsed = Uri.tryParse(raw);
    if (parsed == null || parsed.host.trim().isEmpty) {
      throw const FormatException('Enter a valid video API URL.');
    }

    final normalized = parsed.replace(query: null, fragment: null);
    return _trimTrailingSlash(normalized.toString());
  }

  static String _trimTrailingSlash(String value) {
    return value.endsWith('/') ? value.substring(0, value.length - 1) : value;
  }
}
