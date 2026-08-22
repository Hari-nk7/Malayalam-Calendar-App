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
      duration: const Duration(milliseconds: 500),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.darkBackground : AppTheme.lightBackground;
    final surface = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final border = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textSecondary = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;
    final textMuted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;
    final accent = isDark ? AppTheme.accentAmberDark : AppTheme.accentAmber;

    return Scaffold(
      backgroundColor: bg,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(),

                // Minimalist logo icon
                Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: accent.withOpacity(0.3), width: 1.5),
                    ),
                    child: Icon(
                      Icons.location_on_rounded,
                      color: accent,
                      size: 34,
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                Text(
                  'Set Your Location',
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    height: 1.15,
                  ),
                ),

                const SizedBox(height: 12),

                Text(
                  'Each day\'s Nakshatra (star) and Sankranti allocation are referenced to your exact local sunrise time.',
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 14,
                    height: 1.55,
                  ),
                ),

                const Spacer(),

                if (!_showSearch) ...[
                  // GPS button
                  FilledButton.icon(
                    onPressed: _isLoading ? null : _requestGps,
                    icon: _isLoading
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: isDark ? Colors.black : Colors.white,
                            ),
                          )
                        : const Icon(Icons.my_location_rounded, size: 18),
                    label: const Text('Use My Current Location'),
                    style: FilledButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: isDark ? Colors.black : Colors.white,
                      minimumSize: const Size.fromHeight(50),
                      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => setState(() => _showSearch = true),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: textPrimary,
                      side: BorderSide(color: border),
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Search City Manually'),
                  ),
                ] else ...[
                  // City search
                  TextField(
                    controller: _searchController,
                    autofocus: true,
                    style: TextStyle(color: textPrimary),
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Search city (e.g. Kochi, Dubai)…',
                      prefixIcon: Icon(Icons.search_rounded, color: textMuted),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_searchResults.isNotEmpty)
                    Container(
                      constraints: const BoxConstraints(maxHeight: 220),
                      decoration: BoxDecoration(
                        color: surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: border),
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _searchResults.length,
                        itemBuilder: (_, i) {
                          final city = _searchResults[i];
                          return ListTile(
                            leading: Icon(
                              Icons.location_city_rounded,
                              color: accent,
                              size: 18,
                            ),
                            title: Text(
                              city.name,
                              style: TextStyle(
                                color: textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              '${city.admin1}, ${city.countryCode}',
                              style: TextStyle(
                                color: textMuted,
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
                    child: Text(
                      '← Back',
                      style: TextStyle(color: textMuted),
                    ),
                  ),
                ],

                // Skip with Trivandrum as default
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: () {
                      ref
                          .read(locationProvider.notifier)
                          .setLocation(LocationModel.trivandrum)
                          .then((_) => widget.onLocationSet());
                    },
                    child: Text(
                      'Skip for now (use Thiruvananthapuram)',
                      style: TextStyle(
                        color: textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),
              ],
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
