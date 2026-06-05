import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../services/auth_service.dart';
import '../../services/workout_service.dart';
import '../../theme/app_theme.dart';

class ProgressScreen extends ConsumerStatefulWidget {
  const ProgressScreen({super.key});

  @override
  ConsumerState<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends ConsumerState<ProgressScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final uid = authState.valueOrNull?.uid ?? '';
    final sessionsAsync = ref.watch(sessionsStreamProvider(uid));

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: sessionsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.primary),
        ),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (sessions) => CustomScrollView(
          slivers: [
            SliverAppBar(
              backgroundColor: AppTheme.background,
              floating: true,
              title: Text('Progress',
                  style: Theme.of(context).textTheme.headlineLarge),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                child: Column(
                  children: [
                    _StatsOverview(sessions: sessions),
                    const SizedBox(height: 28),
                    _WorkoutCalendar(
                      sessions: sessions,
                      focusedDay: _focusedDay,
                      selectedDay: _selectedDay,
                      calendarFormat: _calendarFormat,
                      onDaySelected: (selected, focused) {
                        setState(() {
                          _selectedDay = selected;
                          _focusedDay = focused;
                        });
                      },
                      onFormatChanged: (format) =>
                          setState(() => _calendarFormat = format),
                    ),
                    if (_selectedDay != null) ...[
                      const SizedBox(height: 20),
                      _DayDetail(
                        day: _selectedDay!,
                        sessions: sessions,
                      ),
                    ],
                    const SizedBox(height: 28),
                    _WeeklyBarChart(sessions: sessions),
                    const SizedBox(height: 28),
                    _RecentSessions(sessions: sessions.take(5).toList()),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Stats overview row
// ─────────────────────────────────────────────
class _StatsOverview extends StatelessWidget {
  final List<WorkoutSession> sessions;

  const _StatsOverview({required this.sessions});

  @override
  Widget build(BuildContext context) {
    final totalSessions = sessions.length;
    final totalMinutes = sessions.fold<int>(0, (acc, s) => acc + s.durationMinutes);
    final totalSets = sessions.fold<int>(0, (acc, s) => acc + s.totalSets);

    // Streak calculation
    int streak = 0;
    final today = DateTime.now();
    for (int i = 0; i < 365; i++) {
      final day = today.subtract(Duration(days: i));
      final hasWorkout = sessions.any((s) => isSameDay(s.startTime, day));
      if (hasWorkout) {
        streak++;
      } else if (i > 0) {
        break;
      }
    }

    final stats = [
      ('🔥', '$streak', 'Day Streak'),
      ('💪', '$totalSessions', 'Workouts'),
      ('⏱️', '${totalMinutes}m', 'Total Time'),
      ('📦', '$totalSets', 'Total Sets'),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 2.2,
      ),
      itemCount: stats.length,
      itemBuilder: (context, i) {
        final (icon, value, label) = stats[i];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(value,
                      style: const TextStyle(
                        color: AppTheme.primary,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      )),
                  Text(label,
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 11,
                      )),
                ],
              ),
            ],
          ),
        ).animate().fadeIn(delay: (i * 80).ms);
      },
    );
  }
}

// ─────────────────────────────────────────────
// Calendar
// ─────────────────────────────────────────────
class _WorkoutCalendar extends StatelessWidget {
  final List<WorkoutSession> sessions;
  final DateTime focusedDay;
  final DateTime? selectedDay;
  final CalendarFormat calendarFormat;
  final Function(DateTime, DateTime) onDaySelected;
  final Function(CalendarFormat) onFormatChanged;

  const _WorkoutCalendar({
    required this.sessions,
    required this.focusedDay,
    required this.selectedDay,
    required this.calendarFormat,
    required this.onDaySelected,
    required this.onFormatChanged,
  });

  bool _hasWorkout(DateTime day) {
    return sessions.any((s) => isSameDay(s.startTime, day));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: TableCalendar(
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: focusedDay,
        selectedDayPredicate: (day) => isSameDay(selectedDay, day),
        calendarFormat: calendarFormat,
        onDaySelected: onDaySelected,
        onFormatChanged: onFormatChanged,
        onPageChanged: (focusedDay) {},
        eventLoader: (day) => _hasWorkout(day) ? [true] : [],
        calendarStyle: CalendarStyle(
          outsideDaysVisible: false,
          defaultTextStyle: const TextStyle(color: AppTheme.textPrimary),
          weekendTextStyle: const TextStyle(color: AppTheme.textSecondary),
          selectedDecoration: const BoxDecoration(
            color: AppTheme.primary,
            shape: BoxShape.circle,
          ),
          selectedTextStyle: const TextStyle(
            color: AppTheme.background,
            fontWeight: FontWeight.w700,
          ),
          todayDecoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          todayTextStyle: const TextStyle(
            color: AppTheme.primary,
            fontWeight: FontWeight.w600,
          ),
          markerDecoration: const BoxDecoration(
            color: AppTheme.primary,
            shape: BoxShape.circle,
          ),
          markerSize: 5,
          markersMaxCount: 1,
        ),
        headerStyle: HeaderStyle(
          formatButtonVisible: true,
          titleCentered: true,
          formatButtonDecoration: BoxDecoration(
            border: Border.all(color: AppTheme.border),
            borderRadius: BorderRadius.circular(8),
          ),
          formatButtonTextStyle: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 12,
          ),
          titleTextStyle: const TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
          leftChevronIcon: const Icon(Icons.chevron_left,
              color: AppTheme.textSecondary),
          rightChevronIcon: const Icon(Icons.chevron_right,
              color: AppTheme.textSecondary),
        ),
        daysOfWeekStyle: const DaysOfWeekStyle(
          weekdayStyle: TextStyle(color: AppTheme.textMuted, fontSize: 12),
          weekendStyle: TextStyle(color: AppTheme.textMuted, fontSize: 12),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Day detail
// ─────────────────────────────────────────────
class _DayDetail extends StatelessWidget {
  final DateTime day;
  final List<WorkoutSession> sessions;

  const _DayDetail({required this.day, required this.sessions});

  @override
  Widget build(BuildContext context) {
    final daySessions = sessions.where((s) => isSameDay(s.startTime, day)).toList();
    final dateStr = DateFormat('EEEE, MMMM d').format(day);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(dateStr, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          if (daySessions.isEmpty)
            const Text('Rest day 😴',
                style: TextStyle(color: AppTheme.textSecondary))
          else
            for (final s in daySessions)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Text('💪', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.dayName,
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w600,
                              )),
                          Text(
                            '${s.durationMinutes} min · ${s.totalSets} sets',
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '✓ Done',
                        style: TextStyle(
                          color: AppTheme.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
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

// ─────────────────────────────────────────────
// Weekly bar chart
// ─────────────────────────────────────────────
class _WeeklyBarChart extends StatelessWidget {
  final List<WorkoutSession> sessions;

  const _WeeklyBarChart({required this.sessions});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final days = List.generate(7, (i) {
      return now.subtract(Duration(days: 6 - i));
    });

    final counts = days.map((d) {
      return sessions
          .where((s) => isSameDay(s.startTime, d))
          .fold<double>(0, (acc, s) => acc + s.durationMinutes);
    }).toList();

    final dayLabels = days.map((d) => DateFormat('E').format(d)).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('This Week',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text('Minutes of exercise per day',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 20),
          SizedBox(
            height: 140,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: (counts.reduce((a, b) => a > b ? a : b) + 10).clamp(30, double.infinity),
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= dayLabels.length) return const SizedBox();
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            dayLabels[i],
                            style: const TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 11,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: AppTheme.border,
                    strokeWidth: 1,
                  ),
                  drawVerticalLine: false,
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(
                  7,
                  (i) => BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: counts[i],
                        color: isSameDay(days[i], now)
                            ? AppTheme.primary
                            : AppTheme.primary.withOpacity(0.4),
                        width: 20,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(6),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Recent sessions list
// ─────────────────────────────────────────────
class _RecentSessions extends StatelessWidget {
  final List<WorkoutSession> sessions;

  const _RecentSessions({required this.sessions});

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Recent Workouts',
            style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 14),
        for (final s in sessions)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceElevated,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: Text('💪', style: TextStyle(fontSize: 20)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.dayName,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          )),
                      Text(
                        DateFormat('MMM d · h:mm a').format(s.startTime),
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${s.durationMinutes}m',
                        style: const TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        )),
                    Text('${s.totalSets} sets',
                        style: const TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 11,
                        )),
                  ],
                ),
              ],
            ),
          ).animate().fadeIn(delay: 100.ms),
      ],
    );
  }
}
