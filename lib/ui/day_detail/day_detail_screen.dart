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
    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, scrollController) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2D1B6B), Color(0xFF1A1040)],
          ),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(
            top: BorderSide(color: AppTheme.surfaceDivider, width: 0.5),
          ),
        ),
        child: Column(
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.textMuted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 24),
                    _buildDateCard(),
                    const SizedBox(height: 16),
                    _buildNakshatraCard(context),
                    const SizedBox(height: 16),
                    if (day.spansFromPreviousDay) ...[
                      _buildFlagCard(
                        context: context,
                        icon: Icons.hourglass_full,
                        color: AppTheme.spanColor,
                        title: 'Spanning Nakshatra',
                        explanation:
                            '${day.nakshatraName} also governed yesterday\'s '
                            'sunrise. The Moon was moving slower than its average '
                            'pace (~13°20\' per day) and remained within '
                            '${day.nakshatraName}\'s span across both consecutive '
                            'sunrises. In traditional Kerala panchang practice, '
                            'this nakshatra is counted for both days.',
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (day.isRepeatOccurrence) ...[
                      _buildRepeatCard(context),
                      const SizedBox(height: 16),
                    ],
                    if (month.skippedNakshatras.isNotEmpty) ...[
                      _buildSkippedCard(context),
                      const SizedBox(height: 16),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final gregorianFormatted =
        DateFormat('EEEE, d MMMM y').format(day.gregorianDate);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${day.malayalamDate} ${month.monthName}',
          style: const TextStyle(
            color: AppTheme.accentGold,
            fontSize: 36,
            fontWeight: FontWeight.w700,
            height: 1.1,
          ),
        ),
        Text(
          '${month.kollavarshamYear} Kollavarsham',
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          gregorianFormatted,
          style: const TextStyle(
            color: AppTheme.textMuted,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildDateCard() {
    final sunriseLocal = day.sunriseUtc.toLocal();
    final sunriseFormatted = DateFormat('h:mm a').format(sunriseLocal);

    return _InfoCard(
      icon: Icons.wb_sunny_outlined,
      iconColor: AppTheme.accentSaffron,
      title: 'Sunrise',
      subtitle: sunriseFormatted,
      detail: 'All astronomical observations (nakshatra, etc.) are '
          'anchored to this local sunrise time.',
    );
  }

  Widget _buildNakshatraCard(BuildContext context) {
    final start = getNakshatraStartDegree(day.nakshatraIndex);
    final end = getNakshatraEndDegree(day.nakshatraIndex);

    return _InfoCard(
      icon: Icons.star_outline,
      iconColor: AppTheme.accentGoldLight,
      title: 'Nakshatra of the Day',
      subtitle: day.nakshatraName,
      detail:
          'The Moon occupied ${day.nakshatraName} (${start.toStringAsFixed(2)}°'
          '– ${end.toStringAsFixed(2)}° sidereal) at local sunrise today.\n\n'
          'Nakshatra ${day.nakshatraIndex + 1} of 27 in the Lahiri sidereal '
          'zodiac. Each nakshatra spans exactly 13°20\'.',
      badge: day.isRepeatOccurrence
          ? _Badge(
              label: day.hasLaterRepeat ? '1st occurrence' : '2nd occurrence',
              color: AppTheme.repeatColor,
            )
          : null,
    );
  }

  Widget _buildRepeatCard(BuildContext context) {
    // Find the other occurrence(s) in the same month
    final otherDays = month.days.where((d) =>
        d.nakshatraIndex == day.nakshatraIndex &&
        d.gregorianDate != day.gregorianDate);

    final otherDateStr = otherDays
        .map((d) => '${month.monthName} ${d.malayalamDate}')
        .join(', ');

    final isFirst = day.hasLaterRepeat;

    return _FlagCard(
      icon: Icons.refresh,
      color: AppTheme.repeatColor,
      title: 'Nakshatra Repeats This Month',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${day.nakshatraName} appears ${isFirst ? 'again' : 'earlier'} '
            'on $otherDateStr in this month.',
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
          ),
          const SizedBox(height: 10),
          Text(
            'This happens because the Moon\'s sidereal cycle (~27.3 days) '
            'is shorter than a Malayalam month (~29–32 days), so the Moon '
            'completes its circuit and revisits the same nakshatra before '
            'the month ends.',
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.repeatColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border:
                  Border.all(color: AppTheme.repeatColor.withOpacity(0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline,
                    size: 16, color: AppTheme.repeatColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Kerala tradition is genuinely divided on which '
                    'occurrence to use for birthday and anniversary '
                    'observances. The ${isFirst ? 'second' : 'first'} '
                    'occurrence ($otherDateStr) is the commonly observed '
                    'default, but many families follow the '
                    '${isFirst ? 'first' : 'second'} occurrence. Both are '
                    'shown here — consult your family tradition.',
                    style: const TextStyle(
                      color: AppTheme.repeatColor,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (!isFirst) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.repeatColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '★ Commonly observed occurrence',
                style: TextStyle(
                  color: AppTheme.repeatColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSkippedCard(BuildContext context) {
    if (month.skippedNakshatras.isEmpty) return const SizedBox.shrink();

    final skippedNames = month.skippedNakshatras
        .map((i) => getNakshatraName(i))
        .join(', ');

    return _FlagCard(
      icon: Icons.skip_next,
      color: AppTheme.skipColor,
      title: 'Skipped Nakshatra(s) This Month',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$skippedNames ${month.skippedNakshatras.length == 1 ? 'was' : 'were'} '
            'skipped this month.',
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'The Moon entered and fully exited '
            '${month.skippedNakshatras.length == 1 ? 'this nakshatra\'s' : 'these nakshatras\''} '
            'span between two consecutive sunrises. '
            'When the Moon moves faster than its average rate '
            '(up to ~15.4°/day, vs. a nakshatra width of 13°20\'), '
            'it is possible to transit an entire nakshatra without '
            'that nakshatra "owning" a sunrise. Such a nakshatra has '
            'no day in this month\'s calendar.',
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              height: 1.5,
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
    return _FlagCard(
      icon: icon,
      color: color,
      title: title,
      body: Text(
        explanation,
        style: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 13,
          height: 1.6,
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.surfaceDivider, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 18),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  )),
              if (badge != null) ...[
                const Spacer(),
                badge!,
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(subtitle,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              )),
          const SizedBox(height: 8),
          Text(detail,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                height: 1.5,
              )),
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
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3), width: 0.5),
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
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
