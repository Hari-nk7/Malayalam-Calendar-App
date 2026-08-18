/// Calendar grid screen — shows a full Malayalam month with swipe navigation.
library calendar_screen;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:malayalam_calendar_app/data/models/malayalam_day.dart';
import 'package:malayalam_calendar_app/data/models/malayalam_month.dart';
import 'package:malayalam_calendar_app/providers/providers.dart';
import 'package:malayalam_calendar_app/core/astro/sankranti_calculator.dart';
import 'package:malayalam_calendar_app/ui/theme/app_theme.dart';
import 'package:malayalam_calendar_app/ui/day_detail/day_detail_screen.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen>
    with TickerProviderStateMixin {
  late AnimationController _shimmerController;
  late PageController _pageController;

  static int _monthToGlobalIndex(int year, int monthIndex) =>
      year * 12 + monthIndex;

  static MonthKey _globalIndexToKey(int globalIndex, String locationKey) {
    final year = globalIndex ~/ 12;
    final monthIndex = globalIndex % 12;
    return MonthKey(
      kollavarshamYear: year,
      monthIndex: monthIndex,
      locationCacheKey: locationKey,
    );
  }

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    final initialKey = ref.read(displayedMonthKeyProvider);
    final initialPage = _monthToGlobalIndex(
      initialKey.kollavarshamYear,
      initialKey.monthIndex,
    );
    _pageController = PageController(initialPage: initialPage);
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentKey = ref.watch(displayedMonthKeyProvider);
    final locationKey = currentKey.locationCacheKey;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(context, ref, currentKey),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              _WeekdayHeader(),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (page) {
                    final newKey = _globalIndexToKey(page, locationKey);
                    ref.read(displayedMonthKeyProvider.notifier).state = newKey;
                  },
                  itemBuilder: (ctx, page) {
                    final key = _globalIndexToKey(page, locationKey);
                    return _MonthPage(
                      monthKey: key,
                      shimmerController: _shimmerController,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: _TodayFab(onPressed: () {
        final now = DateTime.now();
        final todayYear = SankrantiCalculator.kollavarshamYearApprox(now);
        final todayMonth = _approxMalayalamMonthIndex(now);
        final targetPage = _monthToGlobalIndex(todayYear, todayMonth);
        _pageController.animateToPage(
          targetPage,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    WidgetRef ref,
    MonthKey key,
  ) {
    final monthAsync = ref.watch(calendarMonthProvider(key));
    final title = monthAsync.when(
      data: (m) => '${m.monthName}  •  ${m.kollavarshamYear} KE',
      loading: () => '…',
      error: (_, __) => 'Error',
    );

    return AppBar(
      title: Text(title, style: const TextStyle(color: AppTheme.textPrimary)),
      actions: [
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          tooltip: 'Settings',
          onPressed: () => Navigator.of(context).pushNamed('/settings'),
        ),
      ],
    );
  }
}

class _WeekdayHeader extends StatelessWidget {
  static const _days = ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: _days
            .map((d) => Expanded(
                  child: Center(
                    child: Text(
                      d,
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }
}

class _MonthPage extends ConsumerWidget {
  final MonthKey monthKey;
  final AnimationController shimmerController;

  const _MonthPage({
    required this.monthKey,
    required this.shimmerController,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monthAsync = ref.watch(calendarMonthProvider(monthKey));

    return monthAsync.when(
      data: (month) => _MonthGrid(month: month),
      loading: () => _ShimmerGrid(controller: shimmerController),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: AppTheme.skipColor, size: 48),
              const SizedBox(height: 12),
              Text(
                'Could not compute this month.\n$e',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MonthGrid extends ConsumerWidget {
  final MalayalamMonth month;

  const _MonthGrid({required this.month});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = DateTime.now();
    final firstDay = month.firstGregorianDay;
    // Day of week of the 1st (0=Sun … 6=Sat)
    final startOffset = firstDay.weekday % 7;
    final totalCells = startOffset + month.days.length;
    final rows = (totalCells / 7).ceil();

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 0.75,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: rows * 7,
      itemBuilder: (ctx, index) {
        final dayIndex = index - startOffset;
        if (dayIndex < 0 || dayIndex >= month.days.length) {
          return const SizedBox.shrink();
        }
        final day = month.days[dayIndex];
        final isToday = _isSameDay(day.gregorianDate, today);
        return _DayCell(
          day: day,
          isToday: isToday,
          onTap: () {
            ref.read(selectedDateProvider.notifier).state = day.gregorianDate;
            DayDetailSheet.show(context, day, month);
          },
        );
      },
    );
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _DayCell extends StatefulWidget {
  final MalayalamDay day;
  final bool isToday;
  final VoidCallback onTap;

  const _DayCell({
    required this.day,
    required this.isToday,
    required this.onTap,
  });

  @override
  State<_DayCell> createState() => _DayCellState();
}

class _DayCellState extends State<_DayCell>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.day;
    return GestureDetector(
      onTapDown: (_) => _pressController.forward(),
      onTapUp: (_) {
        _pressController.reverse();
        widget.onTap();
      },
      onTapCancel: () => _pressController.reverse(),
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Container(
          margin: const EdgeInsets.all(1),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: widget.isToday
                ? Border.all(color: AppTheme.todayRing, width: 1.5)
                : Border.all(color: AppTheme.surfaceDivider, width: 0.5),
            gradient: widget.isToday
                ? const LinearGradient(
                    colors: [Color(0xFF3D2B80), Color(0xFF2D1B6B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: widget.isToday ? null : AppTheme.surfaceCardDim,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Malayalam date number (large)
              Text(
                '${d.malayalamDate}',
                style: TextStyle(
                  color: widget.isToday
                      ? AppTheme.accentGold
                      : AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 1),
              // Nakshatra name (tiny, 3 chars)
              Text(
                d.nakshatraName.substring(0, d.nakshatraName.length.clamp(0, 5)),
                style: TextStyle(
                  color: widget.isToday
                      ? AppTheme.accentGoldLight
                      : AppTheme.textMuted,
                  fontSize: 7.5,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              // Flag dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (d.spansFromPreviousDay)
                    _FlagDot(color: AppTheme.spanColor),
                  if (d.isRepeatOccurrence)
                    _FlagDot(color: AppTheme.repeatColor),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FlagDot extends StatelessWidget {
  final Color color;
  const _FlagDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 4,
      height: 4,
      margin: const EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _ShimmerGrid extends StatelessWidget {
  final AnimationController controller;
  const _ShimmerGrid({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        return GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: 0.75,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
          ),
          itemCount: 35,
          itemBuilder: (_, __) => _ShimmerCell(progress: controller.value),
        );
      },
    );
  }
}

class _ShimmerCell extends StatelessWidget {
  final double progress;
  const _ShimmerCell({required this.progress});

  @override
  Widget build(BuildContext context) {
    final shimmerColor = Color.lerp(
      AppTheme.surfaceCardDim,
      AppTheme.surfaceCard,
      (progress * 2 - 1).abs(),
    )!;

    return Container(
      margin: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        color: shimmerColor,
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }
}

class _TodayFab extends StatelessWidget {
  final VoidCallback onPressed;
  const _TodayFab({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.small(
      onPressed: onPressed,
      backgroundColor: AppTheme.accentSaffron,
      foregroundColor: AppTheme.primaryDark,
      tooltip: 'Go to today',
      child: const Icon(Icons.today),
    );
  }
}

int _approxMalayalamMonthIndex(DateTime date) {
  if (date.month == 8) {
    return (date.day >= 17) ? 0 : 11;
  }
  const monthMap = {
    9: 1,
    10: 2,
    11: 3,
    12: 4,
    1: 5,
    2: 6,
    3: 7,
    4: 8,
    5: 9,
    6: 10,
    7: 11,
  };
  return monthMap[date.month] ?? 0;
}
