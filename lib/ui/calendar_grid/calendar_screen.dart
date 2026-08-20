/// Calendar grid screen — dual-view calendar with Gregorian and Malayalam modes.
///
/// Gregorian view: navigate by Jan/Feb/… month; each cell shows the Gregorian
/// date large, with the Malayalam date + nakshatra embedded inside.
///
/// Malayalam view: navigate by ചിങ്ങം/കന്നി/… month; each cell shows the
/// Malayalam date large, with Gregorian date + nakshatra embedded.
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
// Subtle per-Malayalam-month background tints (index 0–11 = Chingam–Karkidakam)
// ---------------------------------------------------------------------------
const List<Color> _monthTints = [
  Color(0xFF1E1050), // Chingam
  Color(0xFF0E1E3A), // Kanni
  Color(0xFF0F2030), // Thulam
  Color(0xFF1A1535), // Vrischikam
  Color(0xFF101530), // Dhanu
  Color(0xFF0C1E30), // Makaram
  Color(0xFF0F1A35), // Kumbham
  Color(0xFF12153A), // Meenam
  Color(0xFF1A1050), // Medam
  Color(0xFF0E1A30), // Edavam
  Color(0xFF121535), // Mithunam
  Color(0xFF141030), // Karkidakam
];

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
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      final year = SankrantiCalculator.kollavarshamYearApprox(now);
      final mi = _approxMalayalamMonthIndex(now);
      final targetPage = _mlToGlobal(year, mi);
      _currentMlPage = targetPage;
      _mlPageController.animateToPage(
        targetPage,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  void _switchViewMode(CalendarViewMode newMode, String locationKey) {
    final currentMode = ref.read(calendarViewModeProvider);
    if (currentMode == newMode) return;

    if (newMode == CalendarViewMode.malayalam) {
      // Switching from Gregorian -> Malayalam:
      // Jump to the first Malayalam month present in the currently displayed Gregorian month (day 1)
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
      // Switching from Malayalam -> Gregorian:
      // Jump to the Gregorian month where this Malayalam month begins
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

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(context, viewMode),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              _ViewModeToggle(
                current: viewMode,
                onChanged: (mode) => _switchViewMode(mode, locationKey),
              ),
              const _WeekdayHeader(),
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

// ---------------------------------------------------------------------------
// View Mode Toggle
// ---------------------------------------------------------------------------

class _ViewModeToggle extends StatelessWidget {
  final CalendarViewMode current;
  final ValueChanged<CalendarViewMode> onChanged;

  const _ViewModeToggle({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1040),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.surfaceDivider, width: 0.5),
        ),
        child: Row(
          children: [
            _ToggleOption(
              label: 'Gregorian',
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
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: selected ? AppTheme.accentSaffron : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: selected ? AppTheme.primaryDark : AppTheme.textMuted,
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              letterSpacing: 0.3,
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
  static const _days = ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'];

  const _WeekdayHeader();

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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 0.60,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
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
    _scale = Tween<double>(begin: 1.0, end: 0.92)
        .animate(CurvedAnimation(parent: _press, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data.day;
    final monthIdx = d.malayalamMonthIndex;
    final tint = _monthTints[monthIdx.clamp(0, 11)];
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
          margin: const EdgeInsets.all(1),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9),
            border: widget.isToday
                ? Border.all(color: AppTheme.todayRing, width: 1.5)
                : Border.all(color: AppTheme.surfaceDivider, width: 0.5),
            color: widget.isToday ? const Color(0xFF2D1B6B) : tint,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Gregorian date — primary (large)
              Text(
                '${widget.gregorianDate.day}',
                style: TextStyle(
                  color: widget.isToday
                      ? AppTheme.accentGold
                      : AppTheme.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 2),
              // Malayalam month + date — secondary
              Text(
                '$monthName ${d.malayalamDate}',
                style: TextStyle(
                  color: widget.isToday
                      ? AppTheme.accentGoldLight
                      : AppTheme.accentSaffron.withOpacity(0.9),
                  fontSize: 6.5,
                  fontWeight: FontWeight.w600,
                  height: 1.0,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              const SizedBox(height: 2),
              // Nakshatra — tertiary (smallest)
              Text(
                _clampNakshatra(d.nakshatraName),
                style: TextStyle(
                  color: widget.isToday
                      ? Colors.white70
                      : AppTheme.textMuted,
                  fontSize: 6.0,
                  fontWeight: FontWeight.w400,
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
                    const _FlagDot(color: AppTheme.spanColor),
                  if (d.isRepeatOccurrence)
                    const _FlagDot(color: AppTheme.repeatColor),
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
// Malayalam Month Page (same as original but with Gregorian date in cell)
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 0.60,
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
    _scale = Tween<double>(begin: 1.0, end: 0.92)
        .animate(CurvedAnimation(parent: _press, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.day;
    // Gregorian date label e.g. "Aug 18"
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
          margin: const EdgeInsets.all(1),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9),
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
              // Malayalam date — primary (large, amber)
              Text(
                '${d.malayalamDate}',
                style: TextStyle(
                  color: widget.isToday
                      ? AppTheme.accentGold
                      : AppTheme.accentSaffron,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 2),
              // Gregorian date — secondary
              Text(
                gregLabel,
                style: TextStyle(
                  color: widget.isToday
                      ? Colors.white
                      : AppTheme.textSecondary,
                  fontSize: 7,
                  fontWeight: FontWeight.w500,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 2),
              // Nakshatra — tertiary
              Text(
                _clampNakshatra(d.nakshatraName),
                style: TextStyle(
                  color: widget.isToday ? Colors.white70 : AppTheme.textMuted,
                  fontSize: 6.0,
                  fontWeight: FontWeight.w400,
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
                    const _FlagDot(color: AppTheme.spanColor),
                  if (d.isRepeatOccurrence)
                    const _FlagDot(color: AppTheme.repeatColor),
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
    return Container(
      margin: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9),
        color: AppTheme.surfaceCardDim.withOpacity(0.3),
        border: Border.all(color: AppTheme.surfaceDivider, width: 0.5),
      ),
      child: const Center(
        child: Text('?',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: AppTheme.skipColor, size: 48),
            const SizedBox(height: 12),
            Text(
              'Could not compute this month.\n$message',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textSecondary),
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
    return FloatingActionButton.small(
      onPressed: onPressed,
      backgroundColor: AppTheme.accentSaffron,
      foregroundColor: AppTheme.primaryDark,
      tooltip: 'Go to today',
      child: const Icon(Icons.today),
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
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: 0.60,
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
      const Color(0xFF1E1550),
      const Color(0xFF2E2570),
      (progress * 2 - (progress * 2).floor()).abs(),
    )!;
    return Container(
      margin: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        color: shimmerColor,
        borderRadius: BorderRadius.circular(9),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Private helpers
// ---------------------------------------------------------------------------

String _clampNakshatra(String name) {
  // Show up to 6 chars of nakshatra (Malayalam glyphs are wide)
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
