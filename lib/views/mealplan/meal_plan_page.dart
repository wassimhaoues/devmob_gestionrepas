import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/meal_plan_assignment_args.dart';
import '../../models/meal_plan_entry.dart';
import '../../models/meal_plan_week.dart';
import '../../models/meal_slot_type.dart';
import '../../providers/auth_provider.dart';
import '../../providers/meal_plan_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_panels.dart';
import 'assign_recipe_page.dart';

const String mealPlanRoute = '/meal-plan';

class MealPlanPage extends StatefulWidget {
  const MealPlanPage({super.key, this.manageMealPlanWatching = true});

  final bool manageMealPlanWatching;

  @override
  State<MealPlanPage> createState() => _MealPlanPageState();
}

class _MealPlanPageState extends State<MealPlanPage> {
  String? _lastSyncedUid;
  DateTime? _selectedDay;

  @override
  Widget build(BuildContext context) {
    _syncWeekWatcher(context);

    final provider = context.watch<MealPlanProvider>();
    final week = provider.activeWeek;
    final selectedDay = _effectiveSelectedDay(week);
    final isViewOnly = _isPastWeek(week);

    return RefreshIndicator(
      onRefresh: provider.refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: <Widget>[
          _PlannerHero(
            week: week,
            isLoading: provider.isLoading,
            plannedMealCount: provider.plannedMealCount,
            selectedDay: selectedDay,
            isViewOnly: isViewOnly,
            onPreviousWeek: () async {
              setState(() => _selectedDay = null);
              await provider.showPreviousWeek();
            },
            onNextWeek: () async {
              setState(() => _selectedDay = null);
              await provider.showNextWeek();
            },
          ),
          const SizedBox(height: 16),
          _WeekDayStrip(
            week: week,
            entries: provider.entries,
            selectedDay: selectedDay,
            onDaySelected: (day) => setState(() => _selectedDay = day),
          ),
          const SizedBox(height: 16),
          if (provider.status == MealPlanProviderStatus.loading &&
              provider.entries.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 48),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (provider.status == MealPlanProviderStatus.error &&
              provider.entries.isEmpty)
            _ErrorState(
              message:
                  provider.errorMessage ??
                  'Unable to load the meal plan for this week.',
              onRetry: provider.refresh,
            )
          else ...<Widget>[
            if (!isViewOnly && provider.entries.isEmpty) ...<Widget>[
              const _EmptyWeekState(),
              const SizedBox(height: 12),
            ],
            _DayScheduleSection(day: selectedDay, isViewOnly: isViewOnly),
          ],
        ],
      ),
    );
  }

  DateTime _effectiveSelectedDay(MealPlanWeek week) {
    if (_selectedDay != null) {
      final stillInWeek = week.days.any((d) => _isSameDate(d, _selectedDay!));
      if (stillInWeek) {
        return _selectedDay!;
      }
    }
    final today = DateTime.now();
    final todayNorm = DateTime(today.year, today.month, today.day);
    final todayInWeek = week.days.any((d) => _isSameDate(d, todayNorm));
    return todayInWeek ? todayNorm : week.days.first;
  }

  bool _isPastWeek(MealPlanWeek week) {
    final today = DateTime.now();
    final todayNorm = DateTime(today.year, today.month, today.day);
    return week.endDate.isBefore(todayNorm);
  }

  void _syncWeekWatcher(BuildContext context) {
    if (!widget.manageMealPlanWatching) {
      return;
    }

    final uid = context.read<AuthProvider>().currentUser?.uid;
    final provider = context.read<MealPlanProvider>();
    if (uid == null || uid == _lastSyncedUid || provider.uid == uid) {
      return;
    }

    _lastSyncedUid = uid;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(context.read<MealPlanProvider>().startWatchingWeek(uid: uid));
    });
  }
}

class _PlannerHero extends StatelessWidget {
  const _PlannerHero({
    required this.week,
    required this.isLoading,
    required this.plannedMealCount,
    required this.selectedDay,
    required this.isViewOnly,
    required this.onPreviousWeek,
    required this.onNextWeek,
  });

  final MealPlanWeek week;
  final bool isLoading;
  final int plannedMealCount;
  final DateTime selectedDay;
  final bool isViewOnly;
  final Future<void> Function() onPreviousWeek;
  final Future<void> Function() onNextWeek;

  @override
  Widget build(BuildContext context) {
    final summary = isViewOnly
        ? (plannedMealCount == 0
              ? 'Past week with no planned meals.'
              : '$plannedMealCount meal${plannedMealCount == 1 ? '' : 's'} were logged for this archived week.')
        : (plannedMealCount == 0
              ? 'Start with one recipe and build the whole week from there.'
              : '$plannedMealCount meal${plannedMealCount == 1 ? '' : 's'} already mapped across the week.');

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            AppColors.primary,
            AppColors.primaryDark,
          ],
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.24),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Meal Planner',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_formatDate(week.startDate)} - ${_formatDate(week.endDate)}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.92),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      summary,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.88),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  children: <Widget>[
                    Text(
                      '$plannedMealCount',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(color: Colors.white),
                    ),
                    Text(
                      plannedMealCount == 1 ? 'meal' : 'meals',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.82),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              _InfoChip(
                icon: Icons.today_outlined,
                label: _formatDay(selectedDay),
              ),
              _InfoChip(
                icon: isViewOnly ? Icons.history : Icons.restaurant_menu,
                label: isViewOnly ? 'View only' : 'Tap a slot to assign',
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: <Widget>[
              Expanded(
                child: _HeroAction(
                  icon: Icons.chevron_left,
                  label: 'Previous Week',
                  onTap: isLoading ? null : () => unawaited(onPreviousWeek()),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HeroAction(
                  icon: Icons.chevron_right,
                  label: 'Next Week',
                  onTap: isLoading ? null : () => unawaited(onNextWeek()),
                ),
              ),
            ],
          ),
          if (isViewOnly) ...<Widget>[
            const SizedBox(height: 14),
            Text(
              'Past week — view only',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.82),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroAction extends StatelessWidget {
  const _HeroAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: enabled
              ? Colors.white.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icon, size: 18, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekDayStrip extends StatelessWidget {
  const _WeekDayStrip({
    required this.week,
    required this.entries,
    required this.selectedDay,
    required this.onDaySelected,
  });

  final MealPlanWeek week;
  final List<MealPlanEntry> entries;
  final DateTime selectedDay;
  final ValueChanged<DateTime> onDaySelected;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayNorm = DateTime(today.year, today.month, today.day);

    return SizedBox(
      height: 116,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          final day = week.days[index];
          final isSelected = _isSameDate(day, selectedDay);
          final isToday = _isSameDate(day, todayNorm);
          final entryCount = entries.where((entry) => _isSameDate(entry.date, day)).length;
          return _DayPill(
            day: day,
            entryCount: entryCount,
            isSelected: isSelected,
            isToday: isToday,
            onTap: () => onDaySelected(day),
          );
        },
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemCount: week.days.length,
      ),
    );
  }
}

class _DayPill extends StatelessWidget {
  const _DayPill({
    required this.day,
    required this.entryCount,
    required this.isSelected,
    required this.isToday,
    required this.onTap,
  });

  final DateTime day;
  final int entryCount;
  final bool isSelected;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = isSelected
        ? AppColors.primary
        : isToday
            ? AppColors.primarySoft
            : Colors.white;
    final foregroundColor = isSelected ? Colors.white : AppColors.heading;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 82,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : isToday
                    ? AppColors.primary
                    : AppColors.border,
            width: isToday ? 1.3 : 1,
          ),
          boxShadow: <BoxShadow>[
            if (isSelected)
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              _shortDay(day.weekday),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: foregroundColor.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${day.day}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: foregroundColor,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.16)
                    : AppColors.surfaceTint,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                entryCount == 0 ? 'Open' : '$entryCount',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isSelected ? Colors.white : AppColors.body,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayScheduleSection extends StatelessWidget {
  const _DayScheduleSection({required this.day, required this.isViewOnly});

  final DateTime day;
  final bool isViewOnly;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MealPlanProvider>();
    final filledCount = provider.entriesForDay(day).length;

    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      _formatDay(day),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isViewOnly
                          ? 'Browse the meals recorded for this day.'
                          : 'Choose breakfast, lunch, and dinner for this day.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              _DaySummaryPill(
                filledCount: filledCount,
                isViewOnly: isViewOnly,
              ),
            ],
          ),
          const SizedBox(height: 18),
          for (final slot in MealSlotType.values) ...<Widget>[
            _MealSlotCard(
              day: day,
              slotType: slot,
              entry: provider.entryFor(date: day, slotType: slot),
              isViewOnly: isViewOnly,
            ),
            if (slot != MealSlotType.values.last) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _DaySummaryPill extends StatelessWidget {
  const _DaySummaryPill({
    required this.filledCount,
    required this.isViewOnly,
  });

  final int filledCount;
  final bool isViewOnly;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isViewOnly ? AppColors.indigoSoft : AppColors.primarySoft,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '$filledCount/3',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(
            'slots planned',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _MealSlotCard extends StatelessWidget {
  const _MealSlotCard({
    required this.day,
    required this.slotType,
    required this.entry,
    required this.isViewOnly,
  });

  final DateTime day;
  final MealSlotType slotType;
  final MealPlanEntry? entry;
  final bool isViewOnly;

  @override
  Widget build(BuildContext context) {
    final isEmpty = entry == null;
    final accentColor = _slotColor(slotType);
    final description = isEmpty
        ? (isViewOnly ? 'No meal planned' : 'Tap to assign a recipe')
        : entry!.recipeCategory?.label ?? 'Meal assigned';

    final content = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(_iconForSlot(slotType), color: accentColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(
                      slotType.label,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(width: 8),
                    if (!isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Planned',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  isEmpty ? 'No meal selected' : entry!.recipeTitle,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize: 16,
                    color: isEmpty ? AppColors.body : AppColors.heading,
                    fontStyle: isViewOnly && isEmpty ? FontStyle.italic : null,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isEmpty && !isViewOnly
                        ? AppColors.primary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (isViewOnly && isEmpty)
            const SizedBox.shrink()
          else if (isViewOnly)
            Icon(
              Icons.history_toggle_off,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            )
          else if (isEmpty)
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.add, color: AppColors.primary),
            )
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                IconButton(
                  tooltip: 'Remove assignment',
                  onPressed: () => _confirmRemove(context),
                  icon: const Icon(Icons.delete_outline),
                ),
                const Icon(Icons.chevron_right, color: AppColors.primary),
              ],
            ),
        ],
      ),
    );

    if (isViewOnly) {
      return content;
    }

    return InkWell(
      onTap: () => _openAssignment(context),
      borderRadius: BorderRadius.circular(22),
      child: content,
    );
  }

  Future<void> _openAssignment(BuildContext context) async {
    await Navigator.of(context).pushNamed(
      assignRecipeRoute,
      arguments: MealPlanAssignmentArgs(
        date: entry?.date ?? day,
        slotType: slotType,
      ),
    );
  }

  Future<void> _confirmRemove(BuildContext context) async {
    final existingEntry = entry;
    if (existingEntry == null) {
      return;
    }

    final shouldRemove = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Remove assignment?'),
          content: Text(
            'Remove ${existingEntry.recipeTitle} from ${slotType.label}?',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );

    if (shouldRemove != true || !context.mounted) {
      return;
    }

    final success = await context.read<MealPlanProvider>().removeEntryForSlot(
      date: existingEntry.date,
      slotType: slotType,
    );
    if (!context.mounted || success) {
      return;
    }

    final message =
        context.read<MealPlanProvider>().errorMessage ??
        'Unable to remove meal slot assignment.';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      backgroundColor: AppColors.dangerSoft,
      borderColor: AppColors.danger.withValues(alpha: 0.2),
      child: Column(
        children: <Widget>[
          const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => unawaited(onRetry()),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _EmptyWeekState extends StatelessWidget {
  const _EmptyWeekState();

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      backgroundColor: AppColors.primarySoft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.lightbulb_outline, color: AppColors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Your week is empty',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  'Tap any breakfast, lunch, or dinner slot below to assign a recipe and start building the week.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

bool _isSameDate(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

Color _slotColor(MealSlotType slotType) {
  switch (slotType) {
    case MealSlotType.breakfast:
      return AppColors.amber;
    case MealSlotType.lunch:
      return AppColors.primary;
    case MealSlotType.dinner:
      return AppColors.indigo;
  }
}

IconData _iconForSlot(MealSlotType slotType) {
  switch (slotType) {
    case MealSlotType.breakfast:
      return Icons.free_breakfast_outlined;
    case MealSlotType.lunch:
      return Icons.lunch_dining_outlined;
    case MealSlotType.dinner:
      return Icons.dinner_dining_outlined;
  }
}

String _shortDay(int weekday) {
  const days = <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return days[weekday - 1];
}

String _formatDate(DateTime date) {
  const monthNames = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${monthNames[date.month - 1]} ${date.day}';
}

String _formatDay(DateTime date) {
  const dayNames = <String>[
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  return '${dayNames[date.weekday - 1]}, ${_formatDate(date)}';
}
