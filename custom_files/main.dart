import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'hive_service.dart';
import 'alarm_service.dart';
import 'task_provider.dart';
import 'gamification_provider.dart';
import 'pomodoro_provider.dart';

// Screens
// Note: We'll place these screen widgets under their features. We'll import them here.
import 'screens/onboarding_screen.dart';
import 'screens/main_navigation_holder.dart';
import 'screens/alarm_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Local DB
  await HiveService.init();

  // Initialize Alarm & Notification systems
  await AlarmService.init();

  // Check if app was launched via an alarm notification action or click
  final notificationAppLaunchDetails =
      await AlarmService.plugin.getNotificationAppLaunchDetails();
  
  Map<String, dynamic>? initialAlarmPayload;
  if (notificationAppLaunchDetails?.didNotificationLaunchApp ?? false) {
    final payload = notificationAppLaunchDetails!.notificationResponse?.payload;
    if (payload != null) {
      initialAlarmPayload = jsonDecode(payload);
    }
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TaskProvider()),
        ChangeNotifierProvider(create: (_) => GamificationProvider()),
        ChangeNotifierProvider(create: (_) => PomodoroProvider()),
      ],
      child: StudyQuestApp(initialAlarmPayload: initialAlarmPayload),
    ),
  );
}

class StudyQuestApp extends StatefulWidget {
  final Map<String, dynamic>? initialAlarmPayload;
  
  const StudyQuestApp({Key? key, this.initialAlarmPayload}) : super(key: key);

  @override
  State<StudyQuestApp> createState() => _StudyQuestAppState();
}

class _StudyQuestAppState extends State<StudyQuestApp> {
  @override
  void initState() {
    super.initState();
    
    // Listen for alarm action responses in the running app
    AlarmService.onAlarmActionTriggered = (action, taskId) {
      _handleAlarmAction(action, taskId);
    };
  }

  void _handleAlarmAction(String action, String taskId) {
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    final gamificationProvider = Provider.of<GamificationProvider>(context, listen: false);
    
    if (action == 'complete') {
      taskProvider.toggleTaskCompletion(
        taskId,
        onComplete: (xp, coins) {
          gamificationProvider.awardRewards(xp, coins);
        },
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task marked as completed!')),
      );
    } else if (action == 'snooze') {
      // Find the task, reschedule in 10 minutes
      final task = taskProvider.tasks.firstWhere((t) => t.id == taskId);
      final snoozedTask = task.copyWith(
        startTime: TimeOfDay.fromDateTime(DateTime.now().add(const Duration(minutes: 10))).format(context),
      );
      AlarmService.scheduleAlarm(snoozedTask);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alarm snoozed for 10 minutes!')),
      );
    } else if (action == 'start_study') {
      // Open app to Pomodoro screen
      Navigator.pushNamed(context, '/pomodoro', arguments: taskId);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check if onboarding is complete
    final bool onboardingComplete = HiveService.settingsBox.get('onboarding_complete', defaultValue: false);

    Widget homeWidget;
    if (widget.initialAlarmPayload != null) {
      homeWidget = AlarmScreen(alarmPayload: widget.initialAlarmPayload!);
    } else if (!onboardingComplete) {
      homeWidget = const OnboardingScreen();
    } else {
      homeWidget = const MainNavigationHolder();
    }

    return MaterialApp(
      title: 'StudyQuest',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark, // Dark Mode Only
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF0C0C0E), // Slate dark
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF8B5CF6), // Purple / Indigo main
          secondary: Color(0xFFEC4899), // Pink / Rose accent
          tertiary: Color(0xFF3B82F6), // Blue accent
          surface: Color(0xFF16161A), // Rounded card base
          background: Color(0xFF0C0C0E),
          error: Color(0xFFEF4444),
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: Color(0xFFE2E8F0),
        ),
        textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme).copyWith(
          titleLarge: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.white),
          titleMedium: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 18),
          bodyLarge: GoogleFonts.outfit(fontSize: 16, color: const Color(0xFFCBD5E1)),
          bodyMedium: GoogleFonts.outfit(fontSize: 14, color: const Color(0xFF94A3B8)),
        ),
        cardTheme: CardTheme(
          color: const Color(0xFF16161A),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0C0C0E),
          elevation: 0,
          centerTitle: false,
        ),
      ),
      home: homeWidget,
      routes: {
        '/home': (context) => const MainNavigationHolder(),
        '/pomodoro': (context) => const MainNavigationHolder(initialTab: 3), // pomodoro on tab 3 (or whatever tab it is)
      },
    );
  }
}
