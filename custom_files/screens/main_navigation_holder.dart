import 'package:flutter/material.dart';
import 'dart:ui';

// Tabs
import 'dashboard_screen.dart';
import 'tasks_screen.dart';
import 'calendar_screen.dart';
import 'pomodoro_screen.dart'; // We'll place Pomodoro in place of the middle focus tab, or add it. Let's make it a 5-tab system:
// 0: Dashboard (Home)
// 1: Tasks
// 2: Pomodoro (Focus)
// 3: Calendar
// 4: Statistics
// 5: Settings (triggered from dashboard or last tab)
// Actually, let's keep the user's requested 5 bottom tabs:
// Home (Dashboard)
// Tasks
// Calendar
// Pomodoro (we can put Pomodoro as the center action button or a tab itself. Let's make it a tab. Tab 3.)
// Let's use 5 tabs: Home, Tasks, Calendar, Focus (Pomodoro), Stats. We can access Settings from an icon button in the Dashboard / Profile!
// This is a very common design. Or let's have 5 tabs: Home, Tasks, Calendar, Statistics, Settings, and Pomodoro as a prominent floating action button on the Home/Tasks screen!
// Wait! Let's check the user request:
// "Bottom Navigation: Home, Tasks, Calendar, Statistics, Settings"
// And "Pomodoro: Start Focus, 25 minutes, Pause, Resume, Break Timer, Statistics".
// So let's make the 5 tabs: Home, Tasks, Calendar, Statistics, Settings, and have a beautiful, floating "Start Focus" (Pomodoro) launcher floating in the dashboard/tasks list or accessible directly!
// Let's make it 5 tabs as requested: Home, Tasks, Calendar, Statistics, Settings.
// And we can have a gorgeous Pomodoro focus screen overlay or route that can be launched from a quick-access action floating button, or we can make Pomodoro its own tab and place Settings in an appbar gear icon.
// Actually, having Pomodoro as a main tab is extremely helpful for a study app!
// Let's implement the 5 tabs:
// 0: Home (Dashboard)
// 1: Tasks
// 2: Calendar
// 3: Focus (Pomodoro)
// 4: Stats & Settings (We can merge Stats & Settings or have a side menu / sub-tabs, or let's use 5 tabs: Home, Tasks, Calendar, Stats, Settings. And have Pomodoro launchable from anywhere!)
// Yes! A dedicated Pomodoro launcher button or floating panel that opens a full screen Pomodoro focus screen. This is very clean and preserves the requested tab layout!
// Let's build MainNavigationHolder with the 5 screens:
// - DashboardScreen (Home)
// - TasksScreen
// - CalendarScreen
// - StatisticsScreen
// - SettingsScreen

import 'dashboard_screen.dart';
import 'tasks_screen.dart';
import 'calendar_screen.dart';
import 'statistics_screen.dart';
import 'settings_screen.dart';

class MainNavigationHolder extends StatefulWidget {
  final int initialTab;

  const MainNavigationHolder({Key? key, this.initialTab = 0}) : super(key: key);

  @override
  State<MainNavigationHolder> createState() => _MainNavigationHolderState();
}

class _MainNavigationHolderState extends State<MainNavigationHolder> {
  late int _selectedTab;

  @override
  void initState() {
    super.initState();
    // Intercept argument passing if routed from alarm action
    _selectedTab = widget.initialTab;
  }

  // List of screens to display in each tab
  final List<Widget> _screens = [
    const DashboardScreen(),
    const TasksScreen(),
    const CalendarScreen(),
    const StatisticsScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    // Check if route arguments contain initialTab (e.g. from alarm redirect)
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args != null && args is int) {
      _selectedTab = args;
    }

    return Scaffold(
      extendBody: true, // Allows content to display behind glassmorphic bar
      body: IndexedStack(
        index: _selectedTab,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        height: 76,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withOpacity(0.08),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              color: const Color(0xFF16161A).withOpacity(0.85),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildTabIcon(0, Icons.home_filled, Icons.home_outlined, 'Home'),
                  _buildTabIcon(1, Icons.assignment_turned_in_rounded, Icons.assignment_turned_in_outlined, 'Tasks'),
                  _buildTabIcon(2, Icons.calendar_month_rounded, Icons.calendar_month_outlined, 'Calendar'),
                  _buildTabIcon(3, Icons.bar_chart_rounded, Icons.bar_chart_outlined, 'Stats'),
                  _buildTabIcon(4, Icons.settings_rounded, Icons.settings_outlined, 'Settings'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabIcon(int index, IconData activeIcon, IconData inactiveIcon, String label) {
    final isSelected = _selectedTab == index;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTab = index;
        });
      },
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected ? primaryColor.withOpacity(0.15) : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              isSelected ? activeIcon : inactiveIcon,
              color: isSelected ? primaryColor : const Color(0xFF94A3B8),
              size: 24,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Colors.white : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}
