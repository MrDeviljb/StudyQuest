import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/gamification_provider.dart';
import '../providers/task_provider.dart';

class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final gamificationProvider = Provider.of<GamificationProvider>(context);
    final taskProvider = Provider.of<TaskProvider>(context);
    final profile = gamificationProvider.profile;

    final primaryColor = Theme.of(context).colorScheme.primary;

    // Calculate analytics metrics
    final totalTasks = taskProvider.tasks.length;
    final completedTasks = taskProvider.tasks.where((t) => t.completed).length;
    final completionRate = totalTasks > 0 ? (completedTasks / totalTasks) * 100 : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quest Statistics / Analytics', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row cards statistics
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    context,
                    'Focus Hours',
                    '${profile.totalFocusHours.toStringAsFixed(1)} H',
                    '🧠',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    context,
                    'Completion Rate',
                    '${completionRate.toStringAsFixed(0)}%',
                    '📈',
                  ),
                ),
              ],
            ).animate().fade(),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    context,
                    'Longest Streak',
                    '${profile.longestStreak} Days',
                    '🔥',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    context,
                    'Tasks Conquered',
                    '$completedTasks / $totalTasks',
                    '🛡️',
                  ),
                ),
              ],
            ).animate().fade(delay: 100.ms),

            const SizedBox(height: 28),

            // Bar chart statistics weekly study hours
            const Text('Focus Hours Weekly Progress', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 16),
            Container(
              height: 240,
              padding: const EdgeInsets.fromLTRB(16, 24, 24, 16),
              decoration: BoxDecoration(
                color: const Color(0xFF16161A),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.02)),
              ),
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: 6,
                  barTouchData: BarTouchData(enabled: false),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          const style = TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold, fontSize: 11);
                          Widget text;
                          switch (value.toInt()) {
                            case 0:
                              text = const Text('M', style: style);
                              break;
                            case 1:
                              text = const Text('T', style: style);
                              break;
                            case 2:
                              text = const Text('W', style: style);
                              break;
                            case 3:
                              text = const Text('T', style: style);
                              break;
                            case 4:
                              text = const Text('F', style: style);
                              break;
                            case 5:
                              text = const Text('S', style: style);
                              break;
                            case 6:
                              text = const Text('S', style: style);
                              break;
                            default:
                              text = const Text('', style: style);
                              break;
                          }
                          return SideTitleWidget(axisSide: meta.axisSide, child: text);
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          return Text(
                            '${value.toInt()}h',
                            style: const TextStyle(color: Color(0xFF64748B), fontSize: 10),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barGroups: [
                    _buildBarGroup(0, 2.5, primaryColor),
                    _buildBarGroup(1, 4.0, primaryColor),
                    _buildBarGroup(2, 1.5, primaryColor),
                    _buildBarGroup(3, 5.0, primaryColor),
                    _buildBarGroup(4, 3.0, primaryColor),
                    _buildBarGroup(5, 0.0, primaryColor),
                    _buildBarGroup(6, 2.0, primaryColor),
                  ],
                ),
              ),
            ).animate().fade(delay: 200.ms).scale(duration: 400.ms, curve: Curves.easeOutBack),

            const SizedBox(height: 28),

            // Badges Achievements unlocked section
            const Text('Unlocked Achievements', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 16),
            if (profile.unlockedBadges.isEmpty)
              _buildEmptyBadgesCard()
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.4,
                ),
                itemCount: profile.unlockedBadges.length,
                itemBuilder: (context, idx) {
                  final badgeId = profile.unlockedBadges[idx];
                  final details = GamificationProvider.getBadgeDetails(badgeId);
                  return _buildBadgeCard(context, details);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(BuildContext context, String label, String value, String emoji) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16161A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.02)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w500)),
              Text(emoji, style: const TextStyle(fontSize: 18)),
            ],
          ),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.white)),
        ],
      ),
    );
  }

  BarChartGroupData _buildBarGroup(int x, double y, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: color,
          width: 14,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
          backDrawRodData: BackgroundBarChartRodData(
            show: true,
            toY: 6,
            color: const Color(0xFF26262E),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyBadgesCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFF16161A),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        children: [
          Text('🏆', style: TextStyle(fontSize: 36)),
          SizedBox(height: 12),
          Text(
            'Achievements are waiting for you!',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
          ),
          SizedBox(height: 4),
          Text(
            'Complete study goals to unlock unique badges.',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeCard(BuildContext context, Map<String, String> details) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF16161A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Text(details['icon']!, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  details['title']!,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            details['description']!,
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 10, height: 1.3),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    ).animate().scale(duration: 300.ms, curve: Curves.easeOutBack);
  }
}
