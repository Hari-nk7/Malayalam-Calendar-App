/// Day detail bottom sheet — shows full astronomical detail for a tapped day.
///
/// Surfaces: Malayalam date, Gregorian date, sunrise time, nakshatra,
/// and FULL EXPLANATORY TEXT for every flag (spanning, skipped, repeat).
library day_detail_screen;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:malayalam_calendar_app/data/models/malayalam_day.dart';
import 'package:malayalam_calendar_app/data/models/malayalam_month.dart';
import 'package:malayalam_calendar_app/core/astro/nakshatra_calculator.dart';
import 'package:malayalam_calendar_app/ui/theme/app_theme.dart';

class DayDetailSheet extends StatelessWidget {
  final MalayalamDay day;
  final MalayalamMonth month;

  const DayDetailSheet({
    super.key,
    required this.day,
    required this.month,
  });

  static void show(
    BuildContext context,
    MalayalamDay day,
    MalayalamMonth month,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DayDetailSheet(day: day, month: month),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final border = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final textMuted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;
    final spanColor = isDark ? AppTheme.spanColorDark : AppTheme.spanColorLight;
    final repeatColor = isDark ? AppTheme.repeatColorDark : AppTheme.repeatColorLight;
    final skipColor = isDark ? AppTheme.skipColorDark : AppTheme.skipColorLight;

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, scrollController) => Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(
            top: BorderSide(color: border, width: 1.0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.4 : 0.1),
              blurRadius: 20,
              offset: const Offset(0, -4),
            )
          ],
        ),
        child: Column(
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: textMuted.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(context),
                    const SizedBox(height: 24),
                    _buildDateCard(context),
                    const SizedBox(height: 14),
                    _buildNakshatraCard(context),
                    const SizedBox(height: 14),
                    if (day.spansFromPreviousDay) ...[
                      _buildFlagCard(
                        context: context,
                        icon: Icons.hourglass_full_rounded,
                        color: spanColor,
                        title: 'Spanning Nakshatra',
                        explanation:
                            '${day.nakshatraName} also governed yesterday\'s '
                            'sunrise. The Moon was moving slower than its average '
                            'pace (~13°20\' per day) and remained within '
                            '${day.nakshatraName}\'s span across both consecutive '
                            'sunrises. In traditional Kerala panchang practice, '
                            'this nakshatra is counted for both days.',
                      ),
                      const SizedBox(height: 14),
                    ],
                    if (day.isRepeatOccurrence) ...[
                      _buildRepeatCard(context, repeatColor),
                      const SizedBox(height: 14),
                    ],
                    if (month.skippedNakshatras.isNotEmpty) ...[
                      _buildSkippedCard(context, skipColor),
                      const SizedBox(height: 14),
                    ],
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textSecondary = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;
    final textMuted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;
    final accent = isDark ? AppTheme.accentAmberDark : AppTheme.accentAmber;

    final gregorianFormatted =
        DateFormat('EEEE, d MMMM y').format(day.gregorianDate);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '${day.malayalamDate} ${month.monthName}',
              style: TextStyle(
                color: accent,
                fontSize: 32,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                height: 1.1,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${month.kollavarshamYear} KE',
              style: TextStyle(
                color: textSecondary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          gregorianFormatted,
          style: TextStyle(
            color: textMuted,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildDateCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppTheme.accentAmberDark : AppTheme.accentAmber;
    final sunriseLocal = day.sunriseUtc.toLocal();
    final sunriseFormatted = DateFormat('h:mm a').format(sunriseLocal);

    return _InfoCard(
      icon: Icons.wb_sunny_rounded,
      iconColor: accent,
      title: 'Sunrise Time',
      subtitle: sunriseFormatted,
      detail: 'All astronomical boundaries and Nakshatras in this calendar '
          'are referenced to this exact local sunrise.',
    );
  }

  Widget _buildNakshatraCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final repeatColor = isDark ? AppTheme.repeatColorDark : AppTheme.repeatColorLight;
    final start = getNakshatraStartDegree(day.nakshatraIndex);
    final end = getNakshatraEndDegree(day.nakshatraIndex);

    return _InfoCard(
      icon: Icons.auto_awesome_rounded,
      iconColor: isDark ? AppTheme.accentAmberDark : AppTheme.accentAmber,
      title: 'Active Nakshatra',
      subtitle: day.nakshatraName,
      detail:
          'The Moon occupied ${day.nakshatraName} (${start.toStringAsFixed(2)}°'
          '– ${end.toStringAsFixed(2)}° sidereal) at local sunrise.\n\n'
          'Star ${day.nakshatraIndex + 1} of 27 in the Lahiri (Chitra Paksha) '
          'sidereal zodiac.',
      badge: day.isRepeatOccurrence
          ? _Badge(
              label: day.hasLaterRepeat ? '1st Occurrence' : '2nd Occurrence',
              color: repeatColor,
            )
          : null,
    );
  }

  Widget _buildRepeatCard(BuildContext context, Color repeatColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textSecondary = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;

    final otherDays = month.days.where((d) =>
        d.nakshatraIndex == day.nakshatraIndex &&
        d.gregorianDate != day.gregorianDate);

    final otherDateStr = otherDays
        .map((d) => '${month.monthName} ${d.malayalamDate}')
        .join(', ');

    final isFirst = day.hasLaterRepeat;

    return _FlagCard(
      icon: Icons.refresh_rounded,
      color: repeatColor,
      title: 'Repeating Star This Month',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${day.nakshatraName} occurs ${isFirst ? 'again' : 'earlier'} '
            'on $otherDateStr in this month.',
            style: TextStyle(
              color: textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Because the Moon\'s sidereal cycle (~27.3 days) is shorter than '
            'a solar month (~29–32 days), the Moon revisits this star before the month ends.',
            style: TextStyle(
              color: textSecondary,
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: repeatColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: repeatColor.withOpacity(0.25)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, size: 16, color: repeatColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Kerala tradition varies on which occurrence is observed for birthdays '
                    'and rituals. The ${isFirst ? 'second' : 'first'} occurrence ($otherDateStr) '
                    'is the common default, but family traditions vary.',
                    style: TextStyle(
                      color: repeatColor,
                      fontSize: 12,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (!isFirst) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: repeatColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '★ Commonly observed occurrence',
                style: TextStyle(
                  color: repeatColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSkippedCard(BuildContext context, Color skipColor) {
    if (month.skippedNakshatras.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textSecondary = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;

    final skippedNames = month.skippedNakshatras
        .map((i) => getNakshatraName(i))
        .join(', ');

    return _FlagCard(
      icon: Icons.skip_next_rounded,
      color: skipColor,
      title: 'Skipped Nakshatra(s)',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$skippedNames ${month.skippedNakshatras.length == 1 ? 'was' : 'were'} '
            'skipped this month.',
            style: TextStyle(
              color: textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'The Moon entered and exited this star\'s span between two consecutive sunrises. '
            'Because lunar motion was fast, no sunrise fell inside this star.',
            style: TextStyle(
              color: textSecondary,
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlagCard({
    required BuildContext context,
    required IconData icon,
    required Color color,
    required String title,
    required String explanation,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textSecondary = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;

    return _FlagCard(
      icon: icon,
      color: color,
      title: title,
      body: Text(
        explanation,
        style: TextStyle(
          color: textSecondary,
          fontSize: 13,
          height: 1.5,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared card widgets
// ---------------------------------------------------------------------------

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String detail;
  final Widget? badge;

  const _InfoCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.detail,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppTheme.darkSurfaceSubtle : AppTheme.lightSurfaceSubtle;
    final border = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textSecondary = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;
    final textMuted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 18),
              const SizedBox(width: 8),
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  color: textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              if (badge != null) ...[
                const Spacer(),
                badge!,
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              color: textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            detail,
            style: TextStyle(
              color: textSecondary,
              fontSize: 12.5,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _FlagCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final Widget body;

  const _FlagCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.25), width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          body,
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
