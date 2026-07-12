import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'database/hive_service.dart';
import 'services/alarm_service.dart';
import 'services/notification_service.dart';
import 'services/permission_manager.dart';
import 'providers/task_provider.dart';
import 'providers/gamification_provider.dart';
import 'providers/pomodoro_provider.dart';
import 'screens/onboarding_screen.dart';
import 'screens/main_navigation_holder.dart';
import 'screens/alarm_screen.dart';

// Global navigator key to launch AlarmScreen from background triggers
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  // 1. Ensure Flutter binding is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Initialize Hive local storage boxes
  try {
    await HiveService.init();
  } catch (e) {
    debugPrint("Hive initialization error: $e");
  }

  // 3. Initialize Alarm Service (Notification timezone, settings, etc.)
  try {
    await AlarmService.init();
  } catch (e) {
    debugPrint("Alarm Service initialization error: $e");
  }

  // 4. Request exact alarm and notification permissions
  try {
    await PermissionManager.requestAlarmPermissions();
  } catch (e) {
    debugPrint("Alarm permission request error: $e");
  }

  // 5. Restore scheduled alarms automatically (Handles Boot recovery)
  try {
    final tasks = HiveService.getAllTasks();
    for (var task in tasks) {
      if (!task.completed) {
        // Run asynchronously so database scheduling doesn't block startup UI
        AlarmService.scheduleAlarm(task);
      }
    }
  } catch (e) {
    debugPrint("Alarm rescheduling error: $e");
  }

  // 6. Check if user completed onboarding
  bool onboardingComplete = false;
  try {
    if (HiveService.settingsBox.isOpen) {
      onboardingComplete =
          HiveService.settingsBox.get('onboarding_complete', defaultValue: false) as bool;
    }
  } catch (e) {
    debugPrint("Onboarding setting read error: $e");
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TaskProvider()),
        ChangeNotifierProvider(create: (_) => GamificationProvider()),
        ChangeNotifierProvider(create: (_) => PomodoroProvider()),
      ],
      child: MyApp(onboardingComplete: onboardingComplete),
    ),
  );
}

class MyApp extends StatefulWidget {
  final bool onboardingComplete;
  const MyApp({Key? key, required this.onboardingComplete}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();

    // 1. Listen to active triggers when notification callbacks occur
    NotificationService.onNotificationTriggered.listen((String payload) {
      _handleNotificationPayload(payload);
    });

    // 2. Handle cold launch cases when app starts from clicked notification
    NotificationService.getLaunchDetails().then((details) {
      if (details != null &&
          details.didNotificationLaunchApp &&
          details.notificationResponse?.payload != null) {
        _handleNotificationPayload(details.notificationResponse!.payload!);
      }
    });
  }

  void _handleNotificationPayload(String payload) {
    try {
      final Map<String, dynamic> data = jsonDecode(payload);
      if (data['isAlarmTrigger'] == true) {
        navigatorKey.currentState?.pushNamed('/alarm', arguments: data);
      }
    } catch (e) {
      // ignore
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'StudyQuest',
      debugShowCheckedModeBanner: false,
      
      // High-Fidelity Custom Dark Theme
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF8B5CF6), // Vibrant Purple
          secondary: Color(0xFFEC4899), // Neon Pink
          tertiary: Color(0xFF10B981), // Emerald Accent
          background: Color(0xFF09090B), // Deep Zinc
          surface: Color(0xFF16161A), // Dark Card Surface
          error: Color(0xFFEF4444), // Intense Red
        ),
        scaffoldBackgroundColor: const Color(0xFF09090B),
        
        // Premium Typography
        textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme).copyWith(
          titleLarge: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 22,
          ),
          bodyMedium: GoogleFonts.outfit(
            color: const Color(0xFFE2E8F0),
            fontSize: 14,
            height: 1.4,
          ),
        ),
        
        // Chip Styling
        chipTheme: ChipThemeData(
          backgroundColor: const Color(0xFF16161A),
          side: BorderSide(color: Colors.white.withOpacity(0.04)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        
        // Dialog styling
        dialogTheme: DialogThemeData(
          backgroundColor: const Color(0xFF16161A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
      ),
      
      // Routing table
      initialRoute: widget.onboardingComplete ? '/home' : '/onboarding',
      routes: {
        '/onboarding': (context) => const OnboardingScreen(),
        '/home': (context) => const MainNavigationHolder(),
        '/pomodoro': (context) => const MainNavigationHolder(initialTab: 0),
      },
      
      // Dynamic route generation for full-screen alarm intents
      onGenerateRoute: (settings) {
        if (settings.name == '/alarm') {
          final payload = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (context) => AlarmScreen(alarmPayload: payload),
          );
        }
        return null;
      },
    );
  }
}
