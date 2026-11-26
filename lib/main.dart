import 'features/maternal_child_health/services/maternal_web_monitor.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/constants/app_constants.dart';
import 'core/routing/app_router.dart';
import 'core/services/notification_service.dart';
import 'core/services/reminder_monitor_service.dart';
import 'core/theme/app_theme.dart';

import 'features/maternal_child_health/services/maternal_notification_service.dart';
import 'features/maternal_child_health/services/maternal_notification_sync.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Supabase
  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    anonKey: AppConstants.supabaseAnonKey,
  );

  // Existing notifications
  await NotificationService.initialize();
  await NotificationService.requestPermission();

  ReminderMonitorService.instance.initialize(
    AppRouter.rootNavigatorKey,
  );

  NotificationService.syncSchedulesFromDatabase();

  // Objective 5: Maternal notifications
  try {
    await MaternalNotificationService.initialize();

    Supabase.instance.client.auth.onAuthStateChange.listen(
      (data) {
        if (data.event == AuthChangeEvent.signedIn ||
            data.event == AuthChangeEvent.signedOut ||
            data.event == AuthChangeEvent.initialSession) {
          unawaited(
            MaternalNotificationSync.synchronize(),
          );
        }
      },
      onError: (Object error) {
        debugPrint('Maternal auth listener error.');
      },
    );

    unawaited(
      MaternalNotificationSync.synchronize(),
    );
  } catch (_) {
    debugPrint(
      'Maternal notification initialization failed.',
    );
  }

  MaternalWebMonitor.initialize();

  runApp(const MedmateApp());
}

class MedmateApp extends StatelessWidget {
  const MedmateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      routerConfig: AppRouter.router,
    );
  }
}
