import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../hive_service.dart';
import '../gamification_provider.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({Key? key}) : super(key: key);

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final TextEditingController _nameController = TextEditingController(text: 'Dev');

  final List<Map<String, String>> _slides = [
    {
      'title': 'Level Up Your Grades',
      'subtitle': 'Welcome to StudyQuest! Turn your studies into a gamified quest. Complete tasks to earn XP and Coins, level up, and unlock achievements.',
      'icon': '🎮',
      'gradient': 'purple',
    },
    {
      'title': 'Unbreakable Focus & Alarms',
      'subtitle': 'Use the built-in Pomodoro focus timer to study efficiently. Set real alarms that ring with vibration and loud custom sounds even when the app is closed.',
      'icon': '⏰',
      'gradient': 'rose',
    },
    {
      'title': 'Timetable Import in Seconds',
      'subtitle': 'Upload your university Excel or CSV schedules. Our local AI parser detects subjects, days, and times to generate recurring weekly tasks automatically.',
      'icon': '📅',
      'gradient': 'blue',
    },
  ];

  void _onFinish() async {
    final name = _nameController.text.trim().isEmpty ? 'Dev' : _nameController.text.trim();
    
    // Save to Hive
    final gamificationProvider = Provider.of<GamificationProvider>(context, listen: false);
    final updatedProfile = gamificationProvider.profile.copyWith(name: name);
    await HiveService.saveUserProfile(updatedProfile);
    
    await HiveService.settingsBox.put('onboarding_complete', true);
    
    // Refresh local profile state in provider
    gamificationProvider.loadProfile();

    // Navigate to home screen
    Navigator.pushReplacementNamed(context, '/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'StudyQuest',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                  if (_currentPage < _slides.length)
                    TextButton(
                      onPressed: () {
                        _pageController.animateToPage(
                          _slides.length,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      child: const Text('Skip'),
                    ),
                ],
              ),
              const SizedBox(height: 24),

              // Page content
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (idx) {
                    setState(() {
                      _currentPage = idx;
                    });
                  },
                  itemCount: _slides.length + 1,
                  itemBuilder: (context, idx) {
                    if (idx == _slides.length) {
                      // Profile Input Slide
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  Theme.of(context).colorScheme.primary,
                                  Theme.of(context).colorScheme.secondary,
                                ],
                              ),
                            ),
                            child: const Text(
                              '👑',
                              style: TextStyle(fontSize: 64),
                            ),
                          ).animate().scale(delay: 100.ms, duration: 400.ms, curve: Curves.backOut),
                          const SizedBox(height: 32),
                          Text(
                            "What's your name, Hero?",
                            style: Theme.of(context).textTheme.titleLarge,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            "We will personalize your statistics and level-ups.",
                            style: Theme.of(context).textTheme.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 32),
                          TextField(
                            controller: _nameController,
                            style: const TextStyle(fontSize: 18),
                            decoration: InputDecoration(
                              labelText: 'Your Name',
                              hintText: 'Dev',
                              filled: true,
                              fillColor: const Color(0xFF16161A),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              prefixIcon: const Icon(Icons.person_rounded),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: Theme.of(context).colorScheme.primary,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }

                    final slide = _slides[idx];
                    final isPurple = slide['gradient'] == 'purple';
                    final isRose = slide['gradient'] == 'rose';

                    final colors = isPurple
                        ? [const Color(0xFF8B5CF6), const Color(0xFF6D28D9)]
                        : isRose
                            ? [const Color(0xFFEC4899), const Color(0xFFBE185D)]
                            : [const Color(0xFF3B82F6), const Color(0xFF1D4ED8)];

                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: colors,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: colors[0].withOpacity(0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              )
                            ],
                          ),
                          child: Text(
                            slide['icon']!,
                            style: const TextStyle(fontSize: 72),
                          ),
                        ).animate().scale(duration: 400.ms, curve: Curves.backOut),
                        const SizedBox(height: 48),
                        Text(
                          slide['title']!,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 24),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          slide['subtitle']!,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: const Color(0xFF94A3B8),
                                height: 1.5,
                              ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    );
                  },
                ),
              ),

              // Bottom control
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Page Indicators
                  Row(
                    children: List.generate(_slides.length + 1, (index) {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(right: 6),
                        height: 8,
                        width: _currentPage == index ? 24 : 8,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: _currentPage == index
                              ? Theme.of(context).colorScheme.primary
                              : const Color(0xFF334155),
                        ),
                      );
                    }),
                  ),

                  // Actions button
                  ElevatedButton(
                    onPressed: () {
                      if (_currentPage < _slides.length) {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      } else {
                        _onFinish();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      _currentPage == _slides.length ? 'Get Started' : 'Next',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
