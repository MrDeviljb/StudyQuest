import 'package:flutter/material.dart';
import 'dart:ui';
import '../services/notification_service.dart';

// Tabs
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
    _selectedTab = widget.initialTab;
    // Check if an alarm is ringing natively or if a notification was clicked on startup
    NotificationService.checkRingingStateOnLaunch();
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
