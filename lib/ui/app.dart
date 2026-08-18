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
    return MaterialApp(
      title: 'Malayalam Calendar',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
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
    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Lamp icon
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [AppTheme.accentSaffron, AppTheme.accentGold],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accentSaffron.withOpacity(0.5),
                      blurRadius: 32,
                      spreadRadius: 8,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.calendar_month_rounded,
                  color: AppTheme.primaryDark,
                  size: 44,
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'Malayalam Calendar',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Kollavarsham • Nirayana • Lahiri',
                style: TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 12,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 40),
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(AppTheme.accentSaffron),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Initialising ephemeris…',
                style: TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
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
    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: AppTheme.skipColor, size: 56),
              const SizedBox(height: 16),
              const Text(
                'Initialisation failed',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                error,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
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
