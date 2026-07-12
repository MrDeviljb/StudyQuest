import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../gamification_provider.dart';
import '../task_provider.dart';

class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final gamificationProvider = Provider.of<GamificationProvider>(context);
    final taskProvider = Provider.of<TaskProvider>(context);
    final profile = gamificationProvider.profile;

    // Calculate Completion %
    final completedCount = taskProvider.tasks.where((t) => t.completed).length;
    final totalCount = taskProvider.tasks.length;
    final double completionPercent = totalCount > 0 ? (completedCount / totalCount) * 100 : 0.0;

    // Calculate Subject breakdowns for chart
    final Map<String, double> subjectStudyTimes = {};
    for (var task in taskProvider.tasks) {
      if (task.completed) {
        // let's say each completed task is roughly 30 minutes of study, or we map actual focus minutes
        final sub = task.subject.isEmpty ? 'General' : task.subject;
        subjectStudyTimes[sub] = (subjectStudyTimes[sub] ?? 0) + 30.0; // 30 mins per completed task as a base metric
      }
    }

    // Add actual focus sessions if we have them
    // For this demonstration, we'll display the subjects list in a bar chart format
    final chartGroups = _buildBarGroups(context, subjectStudyTimes);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                'Quest Statistics',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 28),
              ),
              const SizedBox(height: 20),

              // Gamification Summary Cards Grid
              _buildStatsGrid(context, profile, completionPercent, completedCount, totalCount),
              const SizedBox(height: 24),

              // Subject-wise Study breakdown Bar Chart
              const Text(
                'Subject Breakdown (Minutes)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
              ),
              const SizedBox(height: 12),
              if (subjectStudyTimes.isEmpty)
                _buildEmptyChartCard()
              else
                _buildChartContainer(context, chartGroups, subjectStudyTimes.keys.toList()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsGrid(BuildContext context, dynamic profile, double completionPercent, int completed, int total) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        // Today Focus time
        _buildStatCard(
          context,
          'Today\'s Focus',
          '${profile.todayStudyTimeMinutes} mins',
          '🎯 Goal: 60m',
          const Color(0xFFEF4444),
        ),
        // Total Focus hours
        _buildStatCard(
          context,
          'Total Focus',
          '${profile.totalFocusHours.toStringAsFixed(1)} hrs',
          '🧠 Deep work logs',
          const Color(0xFF8B5CF6),
        ),
        // Completion rate
        _buildStatCard(
          context,
          'Completion',
          '${completionPercent.toInt()}%',
          '🏆 $completed of $total tasks',
          const Color(0xFF10B981),
        ),
        // Streak Card
        _buildStatCard(
          context,
          'Longest Streak',
          '${profile.longestStreak} days',
          '🔥 Current: ${profile.currentStreak}d',
          const Color(0xFFF59E0B),
        ),
      ],
    ).animate().fade(duration: 400.ms);
  }

  Widget _buildStatCard(BuildContext context, String label, String value, String subtext, Color accentColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16161A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.02)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.bold),
          ),
          Text(
            value,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: accentColor),
          ),
          Text(
            subtext,
            style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyChartCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFF16161A),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        children: [
          Text('📊', style: TextStyle(fontSize: 32)),
          SizedBox(height: 12),
          Text(
            'No study logs recorded yet.',
            style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  List<BarChartGroupData> _buildBarGroups(BuildContext context, Map<String, double> data) {
    final List<BarChartGroupData> groups = [];
    int index = 0;
    
    data.forEach((subject, minutes) {
      groups.add(
        BarChartGroupData(
          x: index,
          barRods: [
            BarChartRodData(
              toY: minutes,
              color: Theme.of(context).colorScheme.primary,
              width: 16,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(6),
                topRight: Radius.circular(6),
              ),
            ),
          ],
        ),
      );
      index++;
    });

    return groups;
  }

  Widget _buildChartContainer(BuildContext context, List<BarChartGroupData> chartGroups, List<String> subjects) {
    return Container(
      height: 240,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF16161A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.02)),
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: chartGroups.map((g) => g.barRods.first.toY).reduce((a, b) => a > b ? a : b) + 20,
          barTouchData: BarTouchData(enabled: true),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (double value, TitleMeta meta) {
                  final idx = value.toInt();
                  if (idx >= 0 && idx < subjects.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        subjects[idx].take(5),
                        style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.bold),
                      ),
                    );
                  }
                  return const SizedBox();
                },
              ),
            ),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barGroups: chartGroups,
        ),
      ),
    ).animate().fade(delay: 200.ms);
  }
}
