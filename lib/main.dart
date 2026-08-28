import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:konektizen/core/config/app_edition.dart';
import 'package:konektizen/core/config/server_connection_config.dart';
import 'package:konektizen/core/router/router.dart';
import 'package:konektizen/core/update/mobile_update_gate.dart';
import 'package:konektizen/features/auth/user_provider.dart';
import 'package:konektizen/features/weather/weather_notification_listener.dart';
import 'package:konektizen/features/profile/accessibility_provider.dart';
import 'package:konektizen/theme/app_theme.dart';

Future<void> main() => bootstrap(AppEdition.standard);

Future<void> bootstrap(AppEdition edition) async {
  WidgetsFlutterBinding.ensureInitialized();
  AppFeatures.configure(edition);
  _configureLowDeviceDefaults();
  await ServerConnectionConfig.instance.load();

  // Initialize Firebase (will work once google-services.json is added)
  try {
    await Firebase.initializeApp();
    debugPrint('Firebase initialized successfully');
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
    // Continue anyway - app will work without Firebase until configured
  }

  runZonedGuarded(
    () => runApp(const ProviderScope(child: KonektizenApp())),
    (error, stack) {
      if (!kReleaseMode) debugPrint('Uncaught app error: $error');
    },
    zoneSpecification: kReleaseMode
        ? ZoneSpecification(print: (self, parent, zone, line) {})
        : null,
  );
}

void _configureLowDeviceDefaults() {
  final imageCache = PaintingBinding.instance.imageCache;
  imageCache.maximumSize = 80;
  imageCache.maximumSizeBytes = 40 << 20;

  if (kReleaseMode) {
    debugPrint = (String? message, {int? wrapWidth}) {};
  }
}

class KonektizenApp extends ConsumerStatefulWidget {
  const KonektizenApp({super.key});

  @override
  ConsumerState<KonektizenApp> createState() => _KonektizenAppState();
}

class _KonektizenAppState extends ConsumerState<KonektizenApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() => ref.read(userProvider.notifier).loadCurrentUser());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      Future.microtask(() => ref.read(userProvider.notifier).loadCurrentUser());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accessibility = ref.watch(accessibilityProvider);
    return MaterialApp.router(
      title: AppFeatures.isLaoag ? 'KONEKTIZEN LAOAG' : 'KONEKTIZEN',
      debugShowCheckedModeBanner: false,
      theme: accessibility.highContrast
          ? AppTheme.highContrastTheme
          : AppTheme.lightTheme,
      routerConfig: router,
      builder: (context, child) {
        final app = WeatherNotificationListener(
          child: child ?? const SizedBox.shrink(),
        );
        if (AppFeatures.isLaoag) return app;
        return MobileUpdateGate(navigatorKey: rootNavigatorKey, child: app);
      },
    );
  }
}
