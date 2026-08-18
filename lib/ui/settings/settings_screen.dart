/// Settings screen — location management, attribution, version info.
library settings_screen;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:malayalam_calendar_app/data/repositories/location_repository.dart';
import 'package:malayalam_calendar_app/providers/providers.dart';
import 'package:malayalam_calendar_app/ui/theme/app_theme.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _searchController = TextEditingController();
  List<GeoCity>? _searchResults;
  bool _isSearching = false;
  bool _isGpsLoading = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final location = ref.watch(locationProvider);

    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          children: [
            // ----------------------------------------------------------------
            // Current location
            // ----------------------------------------------------------------
            _SectionHeader('Current Location'),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.surfaceDivider),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.location_on,
                    color: AppTheme.accentSaffron,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          location.cityName,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (location.regionName != null)
                          Text(
                            '${location.regionName}, ${location.countryCode}',
                            style: const TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        Text(
                          '${location.latitude.toStringAsFixed(4)}°, '
                          '${location.longitude.toStringAsFixed(4)}°',
                          style: const TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (location.isGps)
                    const Icon(Icons.gps_fixed,
                        size: 16, color: AppTheme.accentSaffron),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ----------------------------------------------------------------
            // GPS button
            // ----------------------------------------------------------------
            FilledButton.icon(
              onPressed: _isGpsLoading ? null : _requestGps,
              icon: _isGpsLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.primaryDark,
                      ),
                    )
                  : const Icon(Icons.my_location, size: 18),
              label: const Text('Use GPS Location'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.accentSaffron,
                foregroundColor: AppTheme.primaryDark,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ----------------------------------------------------------------
            // City search
            // ----------------------------------------------------------------
            _SectionHeader('Search City'),
            TextField(
              controller: _searchController,
              style: const TextStyle(color: AppTheme.textPrimary),
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Type a city name…',
                prefixIcon:
                    const Icon(Icons.search, color: AppTheme.textMuted, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear,
                            color: AppTheme.textMuted, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchResults = null);
                        },
                      )
                    : null,
              ),
            ),

            if (_isSearching)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.accentSaffron,
                    ),
                  ),
                ),
              ),

            if (_searchResults != null && !_isSearching)
              ..._buildCityResults(),

            const SizedBox(height: 24),

            // ----------------------------------------------------------------
            // Attribution
            // ----------------------------------------------------------------
            _SectionHeader('About & Attribution'),
            _AttributionTile(
              icon: Icons.star_border,
              title: 'Swiss Ephemeris',
              subtitle: 'Astronomical calculations — AGPL-3.0\n'
                  '© Astrodienst AG, astro.com',
            ),
            _AttributionTile(
              icon: Icons.map_outlined,
              title: 'GeoNames',
              subtitle: 'City database — CC BY 4.0\n'
                  '© GeoNames, geonames.org',
            ),
            _AttributionTile(
              icon: Icons.calendar_month_outlined,
              title: 'Kollavarsham Calendar',
              subtitle: 'Malayalam solar sidereal calendar system.\n'
                  'Month-start determined by the Aparahna rule '
                  'with Lahiri ayanamsa.',
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                'Malayalam Calendar App\nVersion 1.0.0',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildCityResults() {
    final results = _searchResults!;
    if (results.isEmpty) {
      return [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Center(
            child: Text(
              'No cities found. Try a different spelling.',
              style: TextStyle(color: AppTheme.textMuted),
            ),
          ),
        ),
      ];
    }

    return results
        .map((city) => _CityTile(
              city: city,
              onTap: () => _selectCity(city),
            ))
        .toList();
  }

  Future<void> _onSearchChanged(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _searchResults = null);
      return;
    }
    setState(() => _isSearching = true);

    final repo = ref.read(locationRepositoryProvider);
    final results = await repo.searchCities(query);

    if (mounted) {
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    }
  }

  Future<void> _requestGps() async {
    setState(() => _isGpsLoading = true);
    final notifier = ref.read(locationProvider.notifier);
    final success = await notifier.useGpsLocation();
    if (mounted) {
      setState(() => _isGpsLoading = false);
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'GPS unavailable. Please enable location permission in Settings '
              'or search for your city manually.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _selectCity(GeoCity city) async {
    final notifier = ref.read(locationProvider.notifier);
    await notifier.setLocation(city.toLocationModel());
    if (mounted) {
      _searchController.clear();
      setState(() => _searchResults = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Location set to ${city.name}')),
      );
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: AppTheme.textMuted,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _CityTile extends StatelessWidget {
  final GeoCity city;
  final VoidCallback onTap;

  const _CityTile({required this.city, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceCardDim,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.surfaceDivider, width: 0.5),
        ),
        child: Row(
          children: [
            const Icon(Icons.location_city_outlined,
                size: 16, color: AppTheme.textMuted),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(city.name,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      )),
                  Text(
                    '${city.admin1}, ${city.countryCode}',
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                size: 16, color: AppTheme.textMuted),
          ],
        ),
      ),
    );
  }
}

class _AttributionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _AttributionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCardDim,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.surfaceDivider, width: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppTheme.accentGold),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    )),
                const SizedBox(height: 3),
                Text(subtitle,
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 11,
                      height: 1.5,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
