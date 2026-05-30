import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:konektizen/core/config/server_connection_config.dart';
import 'package:konektizen/core/router/router.dart';
import 'package:konektizen/features/auth/user_provider.dart';
import 'package:konektizen/features/weather/weather_notification_listener.dart';
import 'package:konektizen/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ServerConnectionConfig.instance.load();

  // Initialize Firebase (will work once google-services.json is added)
  try {
    await Firebase.initializeApp();
    debugPrint('Firebase initialized successfully');
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
    // Continue anyway - app will work without Firebase until configured
  }

  runApp(const ProviderScope(child: KonektizenApp()));
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
    return MaterialApp.router(
      title: 'KONEKTIZEN',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: router,
      builder: (context, child) {
        return WeatherNotificationListener(
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
