/// Location onboarding screen — shown on first launch when no location
/// is saved. Requests GPS permission; shows city picker if denied.
library location_onboarding;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:malayalam_calendar_app/providers/providers.dart';
import 'package:malayalam_calendar_app/data/repositories/location_repository.dart';
import 'package:malayalam_calendar_app/data/models/location_model.dart';
import 'package:malayalam_calendar_app/ui/theme/app_theme.dart';

class LocationOnboardingScreen extends ConsumerStatefulWidget {
  final VoidCallback onLocationSet;

  const LocationOnboardingScreen({super.key, required this.onLocationSet});

  @override
  ConsumerState<LocationOnboardingScreen> createState() =>
      _LocationOnboardingScreenState();
}

class _LocationOnboardingScreenState
    extends ConsumerState<LocationOnboardingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;

  final _searchController = TextEditingController();
  List<GeoCity> _searchResults = [];
  bool _showSearch = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Spacer(),

                  // Logo / icon area
                  Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [AppTheme.accentSaffron, AppTheme.accentGold],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.accentSaffron.withOpacity(0.4),
                            blurRadius: 24,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.calendar_month_rounded,
                        color: AppTheme.primaryDark,
                        size: 40,
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  const Text(
                    'Your location\nmatters here.',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),

                  const SizedBox(height: 16),

                  const Text(
                    'The nakshatra (star) of each day is determined '
                    'by the Moon\'s position at YOUR local sunrise — '
                    'which changes depending on where you are.',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 15,
                      height: 1.6,
                    ),
                  ),

                  const Spacer(),

                  if (!_showSearch) ...[
                    // GPS button
                    _PrimaryButton(
                      label: 'Use My Location',
                      icon: Icons.my_location,
                      isLoading: _isLoading,
                      onPressed: _requestGps,
                    ),
                    const SizedBox(height: 12),
                    _SecondaryButton(
                      label: 'Choose City Manually',
                      onPressed: () => setState(() => _showSearch = true),
                    ),
                  ] else ...[
                    // City search
                    TextField(
                      controller: _searchController,
                      autofocus: true,
                      style: const TextStyle(color: AppTheme.textPrimary),
                      onChanged: _onSearchChanged,
                      decoration: const InputDecoration(
                        hintText: 'Search for your city…',
                        prefixIcon: Icon(Icons.search, color: AppTheme.textMuted),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_searchResults.isNotEmpty)
                      Container(
                        constraints: const BoxConstraints(maxHeight: 220),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceCard,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.surfaceDivider),
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _searchResults.length,
                          itemBuilder: (_, i) {
                            final city = _searchResults[i];
                            return ListTile(
                              leading: const Icon(
                                Icons.location_on_outlined,
                                color: AppTheme.accentSaffron,
                                size: 18,
                              ),
                              title: Text(city.name,
                                  style: const TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 14,
                                  )),
                              subtitle: Text(
                                '${city.admin1}, ${city.countryCode}',
                                style: const TextStyle(
                                  color: AppTheme.textMuted,
                                  fontSize: 11,
                                ),
                              ),
                              onTap: () => _selectCity(city),
                              dense: true,
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => setState(() => _showSearch = false),
                      child: const Text(
                        '← Back',
                        style: TextStyle(color: AppTheme.textMuted),
                      ),
                    ),
                  ],

                  // Skip with Trivandrum as default
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton(
                      onPressed: () {
                        // Use Trivandrum as safe default
                        ref
                            .read(locationProvider.notifier)
                            .setLocation(LocationModel.trivandrum)
                            .then((_) => widget.onLocationSet());
                      },
                      child: const Text(
                        'Skip for now (use Thiruvananthapuram)',
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _requestGps() async {
    setState(() => _isLoading = true);
    final success =
        await ref.read(locationProvider.notifier).useGpsLocation();
    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        widget.onLocationSet();
      } else {
        setState(() => _showSearch = true);
      }
    }
  }

  Future<void> _onSearchChanged(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    final repo = ref.read(locationRepositoryProvider);
    final results = await repo.searchCities(query, limit: 8);
    if (mounted) setState(() => _searchResults = results);
  }

  Future<void> _selectCity(GeoCity city) async {
    await ref
        .read(locationProvider.notifier)
        .setLocation(city.toLocationModel());
    if (mounted) widget.onLocationSet();
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isLoading;
  final VoidCallback onPressed;

  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: isLoading ? null : onPressed,
      icon: isLoading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppTheme.primaryDark,
              ),
            )
          : Icon(icon, size: 18),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: AppTheme.accentSaffron,
        foregroundColor: AppTheme.primaryDark,
        minimumSize: const Size.fromHeight(52),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _SecondaryButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppTheme.textPrimary,
        side: const BorderSide(color: AppTheme.surfaceDivider),
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Text(label),
    );
  }
}
