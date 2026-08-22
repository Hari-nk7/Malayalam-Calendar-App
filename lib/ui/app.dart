/// Root application widget.
library app;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:malayalam_calendar_app/providers/providers.dart';
import 'package:malayalam_calendar_app/ui/theme/app_theme.dart';
import 'package:malayalam_calendar_app/ui/calendar_grid/calendar_screen.dart';
import 'package:malayalam_calendar_app/ui/settings/settings_screen.dart';
import 'package:malayalam_calendar_app/ui/onboarding/location_onboarding_screen.dart';

class MalayalamCalendarApp extends ConsumerWidget {
  const MalayalamCalendarApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'Malayalam Calendar',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      initialRoute: '/',
      routes: {
        '/': (ctx) => const _RootGate(),
        '/settings': (ctx) => const SettingsScreen(),
      },
    );
  }
}

/// Gate that shows initialisation splash → onboarding (if needed) → calendar.
class _RootGate extends ConsumerWidget {
  const _RootGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final initAsync = ref.watch(appInitProvider);

    return initAsync.when(
      loading: () => const _SplashScreen(),
      error: (e, _) => _ErrorScreen(error: e.toString()),
      data: (_) {
        final locationRepo = ref.read(locationRepositoryProvider);
        if (!locationRepo.hasSavedLocation()) {
          return LocationOnboardingScreen(
            onLocationSet: () {
              Navigator.of(context).pushReplacementNamed('/');
            },
          );
        }
        return const CalendarScreen();
      },
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.darkBackground : AppTheme.lightBackground;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textMuted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;

    return Scaffold(
      backgroundColor: bg,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppTheme.accentAmber.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppTheme.accentAmber.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: const Icon(
                Icons.calendar_month_rounded,
                color: AppTheme.accentAmber,
                size: 36,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Malayalam Calendar',
              style: TextStyle(
                color: textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Nithya Panchangam • Kollavarsham',
              style: TextStyle(
                color: textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 36),
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                valueColor: AlwaysStoppedAnimation(AppTheme.accentAmber),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Initialising astronomical data…',
              style: TextStyle(
                color: textMuted,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  final String error;
  const _ErrorScreen({required this.error});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.darkBackground : AppTheme.lightBackground;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textSecondary = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;

    return Scaffold(
      backgroundColor: bg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 48),
              const SizedBox(height: 16),
              Text(
                'Initialisation failed',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                error,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
