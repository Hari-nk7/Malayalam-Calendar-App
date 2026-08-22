/// Settings screen — theme selection, location management, attribution, version info.
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
    final themeMode = ref.watch(themeModeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bg = isDark ? AppTheme.darkBackground : AppTheme.lightBackground;
    final surfaceCard = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final border = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textMuted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;
    final accent = isDark ? AppTheme.accentAmberDark : AppTheme.accentAmber;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        children: [
          // ----------------------------------------------------------------
          // Appearance / Theme selection
          // ----------------------------------------------------------------
          const _SectionHeader('Appearance'),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurfaceSubtle : AppTheme.lightSurfaceSubtle,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: border, width: 1.0),
            ),
            child: Row(
              children: [
                _ThemeSegmentOption(
                  label: 'System',
                  icon: Icons.brightness_auto_outlined,
                  selected: themeMode == ThemeMode.system,
                  onTap: () => ref
                      .read(themeModeProvider.notifier)
                      .setThemeMode(ThemeMode.system),
                ),
                _ThemeSegmentOption(
                  label: 'Light',
                  icon: Icons.light_mode_outlined,
                  selected: themeMode == ThemeMode.light,
                  onTap: () => ref
                      .read(themeModeProvider.notifier)
                      .setThemeMode(ThemeMode.light),
                ),
                _ThemeSegmentOption(
                  label: 'Dark',
                  icon: Icons.dark_mode_outlined,
                  selected: themeMode == ThemeMode.dark,
                  onTap: () => ref
                      .read(themeModeProvider.notifier)
                      .setThemeMode(ThemeMode.dark),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ----------------------------------------------------------------
          // Current location
          // ----------------------------------------------------------------
          const _SectionHeader('Current Location'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: surfaceCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: border, width: 1.0),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.location_on_rounded,
                    color: accent,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        location.cityName,
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (location.regionName != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          '${location.regionName}, ${location.countryCode}',
                          style: TextStyle(
                            color: textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                      const SizedBox(height: 2),
                      Text(
                        '${location.latitude.toStringAsFixed(4)}°, '
                        '${location.longitude.toStringAsFixed(4)}°',
                        style: TextStyle(
                          color: textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                if (location.isGps)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.gps_fixed, size: 12, color: accent),
                        const SizedBox(width: 4),
                        Text(
                          'GPS',
                          style: TextStyle(
                            color: accent,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ----------------------------------------------------------------
          // GPS button
          // ----------------------------------------------------------------
          FilledButton.icon(
            onPressed: _isGpsLoading ? null : _requestGps,
            icon: _isGpsLoading
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: isDark ? Colors.black : Colors.white,
                    ),
                  )
                : const Icon(Icons.my_location_rounded, size: 18),
            label: const Text('Update via GPS'),
            style: FilledButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: isDark ? Colors.black : Colors.white,
              minimumSize: const Size.fromHeight(46),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ----------------------------------------------------------------
          // City search
          // ----------------------------------------------------------------
          const _SectionHeader('Search City'),
          TextField(
            controller: _searchController,
            style: TextStyle(color: textPrimary),
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Type a city name (e.g. Kozhikode, Dubai)…',
              prefixIcon: Icon(Icons.search_rounded, color: textMuted, size: 20),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear_rounded, color: textMuted, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchResults = null);
                      },
                    )
                  : null,
            ),
          ),

          if (_isSearching)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: accent,
                  ),
                ),
              ),
            ),

          if (_searchResults != null && !_isSearching)
            ..._buildCityResults(surfaceCard, border, textPrimary, textMuted),

          const SizedBox(height: 24),

          // ----------------------------------------------------------------
          // Attribution
          // ----------------------------------------------------------------
          const _SectionHeader('About & Engine'),
          _AttributionTile(
            icon: Icons.auto_awesome_rounded,
            title: 'Swiss Ephemeris',
            subtitle: 'High precision planetary & lunar algorithms (AGPL-3.0).\n'
                '© Astrodienst AG',
            surface: surfaceCard,
            border: border,
            textPrimary: textPrimary,
            textMuted: textMuted,
            accent: accent,
          ),
          _AttributionTile(
            icon: Icons.map_outlined,
            title: 'GeoNames Offline Database',
            subtitle: 'Curated offline city coordinates database.\n'
                '© GeoNames (CC BY 4.0)',
            surface: surfaceCard,
            border: border,
            textPrimary: textPrimary,
            textMuted: textMuted,
            accent: accent,
          ),
          _AttributionTile(
            icon: Icons.wb_sunny_outlined,
            title: 'Kollavarsham Astronomy',
            subtitle: 'Sidereal solar calendar with Lahiri ayanamsa (Chitra Paksha) '
                'and Kerala Aparahna Sankranti allocation.',
            surface: surfaceCard,
            border: border,
            textPrimary: textPrimary,
            textMuted: textMuted,
            accent: accent,
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'Malayalam Calendar • Nithya Panchangam\nVersion 1.0.0',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textMuted,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  List<Widget> _buildCityResults(
    Color surfaceCard,
    Color border,
    Color textPrimary,
    Color textMuted,
  ) {
    final results = _searchResults!;
    if (results.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Center(
            child: Text(
              'No matching cities found.',
              style: TextStyle(color: textMuted),
            ),
          ),
        ),
      ];
    }

    return results
        .map((city) => _CityTile(
              city: city,
              surface: surfaceCard,
              border: border,
              textPrimary: textPrimary,
              textMuted: textMuted,
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
              'GPS unavailable. Please enable location permission or search manually.',
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textMuted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: textMuted,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

class _ThemeSegmentOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeSegmentOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textMuted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;
    final activeBg = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final border = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? activeBg : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: selected ? Border.all(color: border, width: 1.0) : null,
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    )
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: selected ? textPrimary : textMuted,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: selected ? textPrimary : textMuted,
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CityTile extends StatelessWidget {
  final GeoCity city;
  final Color surface;
  final Color border;
  final Color textPrimary;
  final Color textMuted;
  final VoidCallback onTap;

  const _CityTile({
    required this.city,
    required this.surface,
    required this.border,
    required this.textPrimary,
    required this.textMuted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border, width: 1.0),
        ),
        child: Row(
          children: [
            Icon(Icons.location_city_rounded, size: 18, color: textMuted),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    city.name,
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${city.admin1}, ${city.countryCode}',
                    style: TextStyle(
                      color: textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 18, color: textMuted),
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
  final Color surface;
  final Color border;
  final Color textPrimary;
  final Color textMuted;
  final Color accent;

  const _AttributionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.surface,
    required this.border,
    required this.textPrimary,
    required this.textMuted,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border, width: 1.0),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: textMuted,
                    fontSize: 11,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
