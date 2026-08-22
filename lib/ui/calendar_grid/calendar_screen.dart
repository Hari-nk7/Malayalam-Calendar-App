/// Calendar grid screen — clean, subtle, production-grade dual-view calendar.
/// Supports both Gregorian and Malayalam primary perspectives with Light and Dark modes.
library calendar_screen;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:malayalam_calendar_app/data/models/malayalam_day.dart';
import 'package:malayalam_calendar_app/data/models/malayalam_month.dart';
import 'package:malayalam_calendar_app/providers/providers.dart';
import 'package:malayalam_calendar_app/core/astro/sankranti_calculator.dart';
import 'package:malayalam_calendar_app/ui/theme/app_theme.dart';
import 'package:malayalam_calendar_app/ui/day_detail/day_detail_screen.dart';

// ---------------------------------------------------------------------------
// Subtle per-Malayalam-month tints (index 0–11 = Chingam–Karkidakam)
// Ultra-subtle so the UI looks clean, professional, and elegant in both modes.
// ---------------------------------------------------------------------------
Color _getMonthCellColor(int monthIndex, bool isDark) {
  if (isDark) {
    // Subtle slate/graphite variations in dark mode
    final darkTints = [
      const Color(0xFF1B1D24), // Chingam
      const Color(0xFF181A20), // Kanni
      const Color(0xFF191B22), // Thulam
      const Color(0xFF1C1E26), // Vrischikam
      const Color(0xFF181B22), // Dhanu
      const Color(0xFF191A20), // Makaram
      const Color(0xFF1B1C24), // Kumbham
      const Color(0xFF1A1B23), // Meenam
      const Color(0xFF1C1E25), // Medam
      const Color(0xFF181B21), // Edavam
      const Color(0xFF191B24), // Mithunam
      const Color(0xFF1B1D26), // Karkidakam
    ];
    return darkTints[monthIndex.clamp(0, 11)];
  } else {
    // Crisp white / subtle cool-warm porcelain variations in light mode
    final lightTints = [
      const Color(0xFFFFFFFF), // Chingam
      const Color(0xFFFAFAFB), // Kanni
      const Color(0xFFFFFFFF), // Thulam
      const Color(0xFFFAF9FB), // Vrischikam
      const Color(0xFFFFFFFF), // Dhanu
      const Color(0xFFF9FAFB), // Makaram
      const Color(0xFFFFFFFF), // Kumbham
      const Color(0xFFFAFAFB), // Meenam
      const Color(0xFFFFFFFF), // Medam
      const Color(0xFFF9FAFB), // Edavam
      const Color(0xFFFFFFFF), // Mithunam
      const Color(0xFFFAFAF9), // Karkidakam
    ];
    return lightTints[monthIndex.clamp(0, 11)];
  }
}

// ---------------------------------------------------------------------------
// Main Screen
// ---------------------------------------------------------------------------

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen>
    with TickerProviderStateMixin {
  late AnimationController _shimmerController;

  // Track the current global page index for each view mode
  late int _currentGregPage;
  late int _currentMlPage;

  // One PageController per view mode — avoids global-index collisions
  late PageController _gregPageController;
  late PageController _mlPageController;

  // ── Gregorian global index helpers ──────────────────────────────────────
  static int _gregToGlobal(int year, int month) => year * 12 + month - 1;
  static ({int year, int month}) _gregFromGlobal(int i) =>
      (year: i ~/ 12, month: i % 12 + 1);

  // ── Malayalam global index helpers ──────────────────────────────────────
  static int _mlToGlobal(int year, int mi) => year * 12 + mi;
  static MonthKey _mlFromGlobal(int i, String locKey) => MonthKey(
        kollavarshamYear: i ~/ 12,
        monthIndex: i % 12,
        locationCacheKey: locKey,
      );

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    final now = DateTime.now();
    _currentGregPage = _gregToGlobal(now.year, now.month);
    _gregPageController = PageController(initialPage: _currentGregPage);

    final mlKey = ref.read(displayedMonthKeyProvider);
    _currentMlPage = _mlToGlobal(mlKey.kollavarshamYear, mlKey.monthIndex);
    _mlPageController = PageController(initialPage: _currentMlPage);
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    _gregPageController.dispose();
    _mlPageController.dispose();
    super.dispose();
  }

  void _goToToday() {
    final mode = ref.read(calendarViewModeProvider);
    final now = DateTime.now();
    if (mode == CalendarViewMode.gregorian) {
      final targetPage = _gregToGlobal(now.year, now.month);
      _currentGregPage = targetPage;
      _gregPageController.animateToPage(
        targetPage,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      final year = SankrantiCalculator.kollavarshamYearApprox(now);
      final mi = _approxMalayalamMonthIndex(now);
      final targetPage = _mlToGlobal(year, mi);
      _currentMlPage = targetPage;
      _mlPageController.animateToPage(
        targetPage,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  void _navigateMonth(int delta) {
    final mode = ref.read(calendarViewModeProvider);
    if (mode == CalendarViewMode.gregorian) {
      _gregPageController.animateToPage(
        _currentGregPage + delta,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _mlPageController.animateToPage(
        _currentMlPage + delta,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _switchViewMode(CalendarViewMode newMode, String locationKey) {
    final currentMode = ref.read(calendarViewModeProvider);
    if (currentMode == newMode) return;

    if (newMode == CalendarViewMode.malayalam) {
      // Gregorian -> Malayalam: jump to first Malayalam month of Gregorian month (day 1)
      final gm = _gregFromGlobal(_currentGregPage);
      final date = DateTime(gm.year, gm.month, 1);
      final mlYear = SankrantiCalculator.kollavarshamYearApprox(date);
      final mlMonthIndex = _approxMalayalamMonthIndex(date);
      final targetPage = _mlToGlobal(mlYear, mlMonthIndex);

      _currentMlPage = targetPage;
      ref.read(displayedMonthKeyProvider.notifier).state = MonthKey(
        kollavarshamYear: mlYear,
        monthIndex: mlMonthIndex,
        locationCacheKey: locationKey,
      );
      if (_mlPageController.hasClients) {
        _mlPageController.jumpToPage(targetPage);
      }
    } else {
      // Malayalam -> Gregorian: jump to Gregorian month where Malayalam month begins
      final mlYear = _currentMlPage ~/ 12;
      final mlMonthIndex = _currentMlPage % 12;
      final baseGregYear = mlYear + 824;
      final gregYear = (mlMonthIndex >= 5) ? baseGregYear + 1 : baseGregYear;
      const mlToGregMonth = [8, 9, 10, 11, 12, 1, 2, 3, 4, 5, 6, 7];
      final gregMonth = mlToGregMonth[mlMonthIndex];
      final targetPage = _gregToGlobal(gregYear, gregMonth);

      _currentGregPage = targetPage;
      ref.read(displayedGregorianMonthProvider.notifier).state =
          GregorianMonthKey(
        year: gregYear,
        month: gregMonth,
        locationCacheKey: locationKey,
      );
      if (_gregPageController.hasClients) {
        _gregPageController.jumpToPage(targetPage);
      }
    }

    ref.read(calendarViewModeProvider.notifier).state = newMode;
  }

  @override
  Widget build(BuildContext context) {
    final viewMode = ref.watch(calendarViewModeProvider);
    final locationKey = ref.watch(locationProvider).cacheKey;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.darkBackground : AppTheme.lightBackground;

    return Scaffold(
      backgroundColor: bg,
      appBar: _buildAppBar(context, viewMode),
      body: SafeArea(
        child: Column(
          children: [
            _ViewModeToggle(
              current: viewMode,
              onChanged: (mode) => _switchViewMode(mode, locationKey),
            ),
            const _WeekdayHeader(),
            const SizedBox(height: 2),
            Expanded(
              child: Stack(
                children: [
                  Offstage(
                    offstage: viewMode != CalendarViewMode.gregorian,
                    child: _buildGregorianView(locationKey),
                  ),
                  Offstage(
                    offstage: viewMode != CalendarViewMode.malayalam,
                    child: _buildMalayalamView(locationKey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _TodayFab(onPressed: _goToToday),
    );
  }

  // ── Gregorian PageView ──────────────────────────────────────────────────

  Widget _buildGregorianView(String locationKey) {
    return PageView.builder(
      controller: _gregPageController,
      onPageChanged: (page) {
        _currentGregPage = page;
        final gm = _gregFromGlobal(page);
        ref.read(displayedGregorianMonthProvider.notifier).state =
            GregorianMonthKey(
          year: gm.year,
          month: gm.month,
          locationCacheKey: locationKey,
        );
      },
      itemBuilder: (_, page) {
        final gm = _gregFromGlobal(page);
        final gmKey = GregorianMonthKey(
          year: gm.year,
          month: gm.month,
          locationCacheKey: locationKey,
        );
        return _GregorianMonthPage(
          gregKey: gmKey,
          shimmerController: _shimmerController,
        );
      },
    );
  }

  // ── Malayalam PageView ──────────────────────────────────────────────────

  Widget _buildMalayalamView(String locationKey) {
    return PageView.builder(
      controller: _mlPageController,
      onPageChanged: (page) {
        _currentMlPage = page;
        ref.read(displayedMonthKeyProvider.notifier).state =
            _mlFromGlobal(page, locationKey);
      },
      itemBuilder: (_, page) {
        final key = _mlFromGlobal(page, locationKey);
        return _MalayalamMonthPage(
          monthKey: key,
          shimmerController: _shimmerController,
        );
      },
    );
  }

  // ── AppBar ──────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar(BuildContext context, CalendarViewMode mode) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textMuted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;

    String title;
    if (mode == CalendarViewMode.gregorian) {
      final gKey = ref.watch(displayedGregorianMonthProvider);
      title = DateFormat('MMMM yyyy').format(DateTime(gKey.year, gKey.month));
    } else {
      final mlKey = ref.watch(displayedMonthKeyProvider);
      final monthAsync = ref.watch(calendarMonthProvider(mlKey));
      title = monthAsync.when(
        data: (m) => '${m.monthName}  •  ${m.kollavarshamYear} KE',
        loading: () => '…',
        error: (_, __) => 'Error',
      );
    }

    return AppBar(
      title: GestureDetector(
        onTap: () => _showMonthPicker(context, mode),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.arrow_drop_down, color: textMuted),
            ],
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.settings_outlined, color: textMuted, size: 22),
          tooltip: 'Settings',
          onPressed: () => Navigator.of(context).pushNamed('/settings'),
        ),
      ],
    );
  }

  void _showMonthPicker(BuildContext context, CalendarViewMode mode) async {
    int initialMonth;
    int initialYear;
    
    if (mode == CalendarViewMode.gregorian) {
      final gKey = ref.read(displayedGregorianMonthProvider);
      initialMonth = gKey.month;
      initialYear = gKey.year;
    } else {
      final mlKey = ref.read(displayedMonthKeyProvider);
      initialMonth = mlKey.monthIndex;
      initialYear = mlKey.kollavarshamYear;
    }

    final result = await showDialog<({int month, int year})>(
      context: context,
      builder: (context) => _MonthYearPickerDialog(
        mode: mode,
        initialMonth: initialMonth,
        initialYear: initialYear,
      ),
    );

    if (result != null) {
      if (mode == CalendarViewMode.gregorian) {
        final targetPage = _gregToGlobal(result.year, result.month);
        _currentGregPage = targetPage;
        _gregPageController.jumpToPage(targetPage);
      } else {
        final targetPage = _mlToGlobal(result.year, result.month);
        _currentMlPage = targetPage;
        _mlPageController.jumpToPage(targetPage);
      }
    }
  }
}

// ---------------------------------------------------------------------------
// View Mode Toggle (iOS / Notion style segmented pill control)
// ---------------------------------------------------------------------------

class _ViewModeToggle extends StatelessWidget {
  final CalendarViewMode current;
  final ValueChanged<CalendarViewMode> onChanged;

  const _ViewModeToggle({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.darkSurfaceSubtle : AppTheme.lightSurfaceSubtle;
    final border = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        height: 38,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border, width: 1.0),
        ),
        child: Row(
          children: [
            _ToggleOption(
              label: 'English',
              selected: current == CalendarViewMode.gregorian,
              onTap: () => onChanged(CalendarViewMode.gregorian),
            ),
            _ToggleOption(
              label: 'Malayalam',
              selected: current == CalendarViewMode.malayalam,
              onTap: () => onChanged(CalendarViewMode.malayalam),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ToggleOption({
    required this.label,
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
          decoration: BoxDecoration(
            color: selected ? activeBg : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            border: selected ? Border.all(color: border, width: 1.0) : null,
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.25 : 0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    )
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: selected ? textPrimary : textMuted,
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Weekday Header
// ---------------------------------------------------------------------------

class _WeekdayHeader extends StatelessWidget {
  static const _days = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

  const _WeekdayHeader();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textMuted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        children: _days
            .map((d) => Expanded(
                  child: Center(
                    child: Text(
                      d,
                      style: TextStyle(
                        color: textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Gregorian Month Page
// ---------------------------------------------------------------------------

class _GregorianMonthPage extends ConsumerWidget {
  final GregorianMonthKey gregKey;
  final AnimationController shimmerController;

  const _GregorianMonthPage({
    required this.gregKey,
    required this.shimmerController,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(gregorianMonthDataProvider(gregKey));
    return dataAsync.when(
      data: (days) => _GregorianMonthGrid(
        year: gregKey.year,
        month: gregKey.month,
        days: days,
      ),
      loading: () => _ShimmerGrid(controller: shimmerController),
      error: (e, _) => _ErrorView(message: e.toString()),
    );
  }
}

// ---------------------------------------------------------------------------
// Gregorian Month Grid
// ---------------------------------------------------------------------------

class _GregorianMonthGrid extends ConsumerWidget {
  final int year;
  final int month;
  final List<GregorianDayData?> days;

  const _GregorianMonthGrid({
    required this.year,
    required this.month,
    required this.days,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = DateTime.now();
    final firstDay = DateTime(year, month, 1);
    final startOffset = firstDay.weekday % 7; // Sunday = 0
    final totalCells = startOffset + days.length;
    final rows = (totalCells / 7).ceil();

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 0.58,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: rows * 7,
      itemBuilder: (ctx, index) {
        final dayIndex = index - startOffset;
        if (dayIndex < 0 || dayIndex >= days.length) {
          return const SizedBox.shrink();
        }
        final data = days[dayIndex];
        final gregorianDate = DateTime(year, month, dayIndex + 1);
        final isToday = _isSameDay(gregorianDate, today);

        if (data == null) {
          return _EmptyDayCell(isToday: isToday);
        }

        return _GregorianDayCell(
          gregorianDate: gregorianDate,
          data: data,
          isToday: isToday,
          onTap: () {
            ref.read(selectedDateProvider.notifier).state = gregorianDate;
            DayDetailSheet.show(context, data.day, data.month);
          },
        );
      },
    );
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

// ---------------------------------------------------------------------------
// Gregorian Day Cell
// ---------------------------------------------------------------------------

class _GregorianDayCell extends StatefulWidget {
  final DateTime gregorianDate;
  final GregorianDayData data;
  final bool isToday;
  final VoidCallback onTap;

  const _GregorianDayCell({
    required this.gregorianDate,
    required this.data,
    required this.isToday,
    required this.onTap,
  });

  @override
  State<_GregorianDayCell> createState() => _GregorianDayCellState();
}

class _GregorianDayCellState extends State<_GregorianDayCell>
    with SingleTickerProviderStateMixin {
  late AnimationController _press;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.94)
        .animate(CurvedAnimation(parent: _press, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textMuted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextSecondary;
    final border = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final accent = isDark ? AppTheme.accentAmberDark : AppTheme.accentAmber;

    final d = widget.data.day;
    final monthIdx = d.malayalamMonthIndex;
    final cellBg = _getMonthCellColor(monthIdx, isDark);
    final monthName = widget.data.month.monthName;

    return GestureDetector(
      onTapDown: (_) => _press.forward(),
      onTapUp: (_) {
        _press.reverse();
        widget.onTap();
      },
      onTapCancel: () => _press.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          decoration: BoxDecoration(
            color: widget.isToday
                ? (isDark ? accent.withOpacity(0.15) : accent.withOpacity(0.08))
                : cellBg,
            borderRadius: BorderRadius.circular(10),
            border: widget.isToday
                ? Border.all(color: accent, width: 1.8)
                : Border.all(color: border, width: 1.0),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.isToday)
                Text(
                  'Today',
                  style: TextStyle(
                    color: accent,
                    fontSize: 7.0,
                    fontWeight: FontWeight.w700,
                    height: 1.0,
                  ),
                ),
              if (widget.isToday) const SizedBox(height: 1),
              // Gregorian date — primary
              Text(
                '${widget.gregorianDate.day}',
                style: TextStyle(
                  color: widget.isToday ? accent : textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 2),
              // Malayalam month + date badge/text
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                decoration: BoxDecoration(
                  color: accent.withOpacity(isDark ? 0.15 : 0.10),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '$monthName ${d.malayalamDate}',
                  style: TextStyle(
                    color: accent,
                    fontSize: 6.8,
                    fontWeight: FontWeight.w700,
                    height: 1.0,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              const SizedBox(height: 2),
              // Nakshatra
              Text(
                _clampNakshatra(d.nakshatraName),
                style: TextStyle(
                  color: textMuted,
                  fontSize: 6.2,
                  fontWeight: FontWeight.w500,
                  height: 1.0,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              const SizedBox(height: 2),
              // Flag dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (d.spansFromPreviousDay)
                    _FlagDot(color: isDark ? AppTheme.spanColorDark : AppTheme.spanColorLight),
                  if (d.isRepeatOccurrence)
                    _FlagDot(color: isDark ? AppTheme.repeatColorDark : AppTheme.repeatColorLight),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Malayalam Month Page
// ---------------------------------------------------------------------------

class _MalayalamMonthPage extends ConsumerWidget {
  final MonthKey monthKey;
  final AnimationController shimmerController;

  const _MalayalamMonthPage({
    required this.monthKey,
    required this.shimmerController,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monthAsync = ref.watch(calendarMonthProvider(monthKey));
    return monthAsync.when(
      data: (month) => _MalayalamMonthGrid(month: month),
      loading: () => _ShimmerGrid(controller: shimmerController),
      error: (e, _) => _ErrorView(message: e.toString()),
    );
  }
}

// ---------------------------------------------------------------------------
// Malayalam Month Grid
// ---------------------------------------------------------------------------

class _MalayalamMonthGrid extends ConsumerWidget {
  final MalayalamMonth month;

  const _MalayalamMonthGrid({required this.month});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = DateTime.now();
    final firstDay = month.firstGregorianDay;
    final startOffset = firstDay.weekday % 7;
    final totalCells = startOffset + month.days.length;
    final rows = (totalCells / 7).ceil();

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 0.58,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: rows * 7,
      itemBuilder: (ctx, index) {
        final dayIndex = index - startOffset;
        if (dayIndex < 0 || dayIndex >= month.days.length) {
          return const SizedBox.shrink();
        }
        final day = month.days[dayIndex];
        final isToday = _isSameDay(day.gregorianDate, today);
        return _MalayalamDayCell(
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

// ---------------------------------------------------------------------------
// Malayalam Day Cell
// ---------------------------------------------------------------------------

class _MalayalamDayCell extends StatefulWidget {
  final MalayalamDay day;
  final bool isToday;
  final VoidCallback onTap;

  const _MalayalamDayCell({
    required this.day,
    required this.isToday,
    required this.onTap,
  });

  @override
  State<_MalayalamDayCell> createState() => _MalayalamDayCellState();
}

class _MalayalamDayCellState extends State<_MalayalamDayCell>
    with SingleTickerProviderStateMixin {
  late AnimationController _press;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.94)
        .animate(CurvedAnimation(parent: _press, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textMuted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextSecondary;
    final border = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final cardBg = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final accent = isDark ? AppTheme.accentAmberDark : AppTheme.accentAmber;

    final d = widget.day;
    final gregLabel = DateFormat('MMM d').format(d.gregorianDate);

    return GestureDetector(
      onTapDown: (_) => _press.forward(),
      onTapUp: (_) {
        _press.reverse();
        widget.onTap();
      },
      onTapCancel: () => _press.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          decoration: BoxDecoration(
            color: widget.isToday
                ? (isDark ? accent.withOpacity(0.15) : accent.withOpacity(0.08))
                : cardBg,
            borderRadius: BorderRadius.circular(10),
            border: widget.isToday
                ? Border.all(color: accent, width: 1.8)
                : Border.all(color: border, width: 1.0),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.isToday)
                Text(
                  'Today',
                  style: TextStyle(
                    color: accent,
                    fontSize: 7.0,
                    fontWeight: FontWeight.w700,
                    height: 1.0,
                  ),
                ),
              if (widget.isToday) const SizedBox(height: 1),
              // Malayalam date — primary
              Text(
                '${d.malayalamDate}',
                style: TextStyle(
                  color: accent,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 2),
              // Gregorian date
              Text(
                gregLabel,
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 7.5,
                  fontWeight: FontWeight.w600,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 2),
              // Nakshatra
              Text(
                _clampNakshatra(d.nakshatraName),
                style: TextStyle(
                  color: textMuted,
                  fontSize: 6.2,
                  fontWeight: FontWeight.w500,
                  height: 1.0,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (d.spansFromPreviousDay)
                    _FlagDot(color: isDark ? AppTheme.spanColorDark : AppTheme.spanColorLight),
                  if (d.isRepeatOccurrence)
                    _FlagDot(color: isDark ? AppTheme.repeatColorDark : AppTheme.repeatColorLight),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared widgets
// ---------------------------------------------------------------------------

class _EmptyDayCell extends StatelessWidget {
  final bool isToday;
  const _EmptyDayCell({required this.isToday});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final bg = isDark ? AppTheme.darkSurfaceSubtle : AppTheme.lightSurfaceSubtle;
    final textMuted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: bg,
        border: Border.all(color: border, width: 1.0),
      ),
      child: Center(
        child: Text('?', style: TextStyle(color: textMuted, fontSize: 12)),
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

class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView({required this.message});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textSecondary = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 44),
            const SizedBox(height: 12),
            Text(
              'Could not compute this month.\n$message',
              textAlign: TextAlign.center,
              style: TextStyle(color: textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayFab extends StatelessWidget {
  final VoidCallback onPressed;
  const _TodayFab({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppTheme.accentAmberDark : AppTheme.accentAmber;

    return FloatingActionButton.small(
      onPressed: onPressed,
      backgroundColor: accent,
      foregroundColor: isDark ? Colors.black : Colors.white,
      tooltip: 'Go to today',
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: const Icon(Icons.today_rounded, size: 20),
    );
  }
}

// ---------------------------------------------------------------------------
// Shimmer loading cells
// ---------------------------------------------------------------------------

class _ShimmerGrid extends StatelessWidget {
  final AnimationController controller;
  const _ShimmerGrid({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        return GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: 0.58,
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? const Color(0xFF181A1F) : const Color(0xFFF1F3F5);
    final highlightColor = isDark ? const Color(0xFF262933) : const Color(0xFFE2E8F0);

    final shimmerColor = Color.lerp(
      baseColor,
      highlightColor,
      (progress * 2 - (progress * 2).floor()).abs(),
    )!;

    return Container(
      decoration: BoxDecoration(
        color: shimmerColor,
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Private helpers
// ---------------------------------------------------------------------------

String _clampNakshatra(String name) {
  return name.length > 6 ? name.substring(0, 6) : name;
}

int _approxMalayalamMonthIndex(DateTime date) {
  const transitions = {
    1: (14, 4, 5),   // Jan: Dhanu(4) -> Makaram(5)
    2: (13, 5, 6),   // Feb: Makaram(5) -> Kumbham(6)
    3: (14, 6, 7),   // Mar: Kumbham(6) -> Meenam(7)
    4: (14, 7, 8),   // Apr: Meenam(7) -> Medam(8)
    5: (14, 8, 9),   // May: Medam(8) -> Edavam(9)
    6: (14, 9, 10),  // Jun: Edavam(9) -> Mithunam(10)
    7: (16, 10, 11), // Jul: Mithunam(10) -> Karkidakam(11)
    8: (17, 11, 0),  // Aug: Karkidakam(11) -> Chingam(0)
    9: (17, 0, 1),   // Sep: Chingam(0) -> Kanni(1)
    10: (17, 1, 2),  // Oct: Kanni(1) -> Thulam(2)
    11: (16, 2, 3),  // Nov: Thulam(2) -> Vrischikam(3)
    12: (15, 3, 4),  // Dec: Vrischikam(3) -> Dhanu(4)
  };

  final t = transitions[date.month];
  if (t == null) return 0;
  return (date.day >= t.$1) ? t.$3 : t.$2;
}

// ---------------------------------------------------------------------------
// Month & Year Picker Dialog
// ---------------------------------------------------------------------------

class _MonthYearPickerDialog extends StatefulWidget {
  final CalendarViewMode mode;
  final int initialMonth; // 1-12 for Greg, 0-11 for Mal
  final int initialYear;

  const _MonthYearPickerDialog({
    required this.mode,
    required this.initialMonth,
    required this.initialYear,
  });

  @override
  State<_MonthYearPickerDialog> createState() => _MonthYearPickerDialogState();
}

class _MonthYearPickerDialogState extends State<_MonthYearPickerDialog> {
  late int _selectedMonth;
  late int _selectedYear;

  @override
  void initState() {
    super.initState();
    _selectedMonth = widget.initialMonth;
    _selectedYear = widget.initialYear;
  }

  @override
  Widget build(BuildContext context) {
    final isGreg = widget.mode == CalendarViewMode.gregorian;
    
    final List<String> monthNames = isGreg
        ? [
            'January', 'February', 'March', 'April', 'May', 'June',
            'July', 'August', 'September', 'October', 'November', 'December'
          ]
        : [
            'Chingam', 'Kanni', 'Thulam', 'Vrischikam', 'Dhanu', 'Makaram',
            'Kumbham', 'Meenam', 'Medam', 'Edavam', 'Mithunam', 'Karkidakam'
          ];
          
    final int minYear = isGreg ? 1900 : 1000;
    final int maxYear = isGreg ? 2100 : 1300;
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final text = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;

    return AlertDialog(
      backgroundColor: bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        'Select Month & Year',
        style: TextStyle(color: text, fontWeight: FontWeight.w600, fontSize: 18),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Month Dropdown
          DropdownButtonFormField<int>(
            value: _selectedMonth,
            dropdownColor: bg,
            style: TextStyle(color: text, fontSize: 16),
            decoration: InputDecoration(
              labelText: 'Month',
              labelStyle: TextStyle(color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            items: List.generate(12, (index) {
              final val = isGreg ? index + 1 : index;
              return DropdownMenuItem(
                value: val,
                child: Text(monthNames[index]),
              );
            }),
            onChanged: (val) {
              if (val != null) setState(() => _selectedMonth = val);
            },
          ),
          const SizedBox(height: 16),
          // Year Dropdown
          DropdownButtonFormField<int>(
            value: _selectedYear,
            dropdownColor: bg,
            style: TextStyle(color: text, fontSize: 16),
            menuMaxHeight: 300,
            decoration: InputDecoration(
              labelText: 'Year',
              labelStyle: TextStyle(color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            items: List.generate(maxYear - minYear + 1, (index) {
              final val = minYear + index;
              return DropdownMenuItem(
                value: val,
                child: Text('$val'),
              );
            }),
            onChanged: (val) {
              if (val != null) setState(() => _selectedYear = val);
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel', style: TextStyle(color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop((month: _selectedMonth, year: _selectedYear)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.accentAmber,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 0,
          ),
          child: const Text('Go', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
