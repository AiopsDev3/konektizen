import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:konektizen/core/api/api_service.dart';
import 'package:konektizen/features/auth/user_provider.dart';
import 'package:konektizen/features/weather/weather_advisory_service.dart';
import 'package:konektizen/features/weather/weather_snack_bar.dart';

class WeatherNotificationListener extends ConsumerStatefulWidget {
  const WeatherNotificationListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<WeatherNotificationListener> createState() =>
      _WeatherNotificationListenerState();
}

class _WeatherNotificationListenerState
    extends ConsumerState<WeatherNotificationListener> {
  final _storage = const FlutterSecureStorage();
  final _service = const WeatherAdvisoryService();
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _messageSubscription;
  bool _registrationBusy = false;
  bool _advisoryCheckBusy = false;
  String? _lastRegisteredBackendToken;
  String? _lastAdvisoryCheckToken;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupForegroundMessages();
      _registerPushWhenSignedIn();
      _showLatestHighPriorityAdvisory();
    });
  }

  @override
  void dispose() {
    _tokenSubscription?.cancel();
    _messageSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _registerPushWhenSignedIn();
      _showLatestHighPriorityAdvisory();
    });
    ref.listen<UserState>(userProvider, (previous, next) {
      if (next.isAuthenticated && previous?.id != next.id) {
        _registerPushWhenSignedIn();
        _showLatestHighPriorityAdvisory();
      }
    });
    return widget.child;
  }

  void _setupForegroundMessages() {
    if (_messageSubscription != null) return;
    try {
      _messageSubscription = FirebaseMessaging.onMessage.listen((message) {
        final title =
            message.notification?.title ??
            message.data['title'] ??
            'Weather Advisory';
        final body =
            message.notification?.body ??
            message.data['body'] ??
            'C3 posted a new weather update.';
        _showSnack(title.toString(), body.toString());
      });
      _tokenSubscription = FirebaseMessaging.instance.onTokenRefresh.listen(
        (token) => _service.registerPushToken(token).catchError((_) {}),
      );
    } catch (_) {
      // Firebase may be disabled on local builds.
    }
  }

  Future<void> _registerPushWhenSignedIn() async {
    if (_registrationBusy) return;
    final token = await apiService.getToken();
    if (token == null || token.isEmpty) return;
    if (_lastRegisteredBackendToken == token) return;

    _registrationBusy = true;
    try {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      final pushToken = await FirebaseMessaging.instance.getToken();
      if (pushToken != null) {
        await _service.registerPushToken(pushToken);
        _lastRegisteredBackendToken = token;
      }
    } catch (_) {
      // Firebase may be unavailable on local debug builds; advisories still load.
    } finally {
      _registrationBusy = false;
    }
  }

  Future<void> _showLatestHighPriorityAdvisory() async {
    if (_advisoryCheckBusy) return;
    _advisoryCheckBusy = true;
    try {
      final token = await apiService.getToken();
      if (token == null || token.isEmpty) return;
      if (_lastAdvisoryCheckToken == token) return;

      final advisories = await _service.fetchAdvisories(limit: 10);
      _lastAdvisoryCheckToken = token;
      final advisory = advisories
          .where((item) => item.shouldNotify)
          .firstOrNull;
      if (advisory == null) return;

      final lastSignal = await _storage.read(key: _lastSignalKey);
      if (lastSignal == advisory.signalId) return;

      await _storage.write(key: _lastSignalKey, value: advisory.signalId);
      _showSnack(advisory.title, advisory.summary);
    } catch (_) {
      // Silent by design: app startup should not be blocked by advisory checks.
    } finally {
      _advisoryCheckBusy = false;
    }
  }

  void _showSnack(String title, String body) {
    if (!mounted) return;
    showWeatherSnackBar(context, title: title, body: body, isAlert: true);
  }
}

const _lastSignalKey = 'last_seen_weather_advisory_signal_id';

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
