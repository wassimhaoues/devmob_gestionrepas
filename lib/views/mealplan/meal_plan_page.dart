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
        cacheExtent: 10000,
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
              child: AppLoadingState(
                message: 'Loading this week...',
                icon: Icons.calendar_month_outlined,
              ),
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
        gradient: AppGradients.brand,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        boxShadow: AppShadows.hero(AppColors.primary),
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
                      style: Theme.of(
                        context,
                      ).textTheme.headlineSmall?.copyWith(color: Colors.white),
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
                      style: Theme.of(
                        context,
                      ).textTheme.headlineSmall?.copyWith(color: Colors.white),
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
              AppHeroTag(
                icon: Icons.today_outlined,
                label: _formatDay(selectedDay),
              ),
              AppHeroTag(
                icon: isViewOnly ? Icons.history : Icons.restaurant_menu,
                label: isViewOnly ? 'View only' : 'Tap a slot to assign',
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: <Widget>[
              Expanded(
                child: AppHeroAction(
                  icon: Icons.chevron_left,
                  label: 'Previous Week',
                  onTap: isLoading ? null : () => unawaited(onPreviousWeek()),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppHeroAction(
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
          final entryCount = entries
              .where((entry) => _isSameDate(entry.date, day))
              .length;
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
                          : 'Assign one or more recipes to each meal slot.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              _DaySummaryPill(filledCount: filledCount, isViewOnly: isViewOnly),
            ],
          ),
          const SizedBox(height: 18),
          for (final slot in MealSlotType.values) ...<Widget>[
            _MealSlotCard(
              day: day,
              slotType: slot,
              entries: provider.entriesForSlot(date: day, slotType: slot),
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
  const _DaySummaryPill({required this.filledCount, required this.isViewOnly});

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
            '$filledCount',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(
            filledCount == 1 ? 'recipe' : 'recipes',
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
    required this.entries,
    required this.isViewOnly,
  });

  final DateTime day;
  final MealSlotType slotType;
  final List<MealPlanEntry> entries;
  final bool isViewOnly;

  @override
  Widget build(BuildContext context) {
    final accentColor = _slotColor(slotType);
    final isEmpty = entries.isEmpty;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
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
                      Text(
                        slotType.label,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isEmpty
                            ? (isViewOnly ? 'No meal planned' : 'No recipes yet')
                            : '${entries.length} recipe${entries.length == 1 ? '' : 's'}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isEmpty && !isViewOnly
                              ? AppColors.primary
                              : AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isViewOnly)
                  InkWell(
                    onTap: () => _openAssignment(context),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.add, color: AppColors.primary),
                    ),
                  ),
              ],
            ),
          ),
          if (!isEmpty) ...<Widget>[
            Divider(height: 1, color: AppColors.border),
            for (final entry in entries)
              _RecipeEntryRow(
                entry: entry,
                isViewOnly: isViewOnly,
                isLast: entry == entries.last,
                onRemove: () => _confirmRemove(context, entry),
              ),
          ] else if (!isViewOnly) ...<Widget>[
            Divider(height: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Text(
                'Tap + to add a recipe to this slot.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.muted,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openAssignment(BuildContext context) async {
    await Navigator.of(context).pushNamed(
      assignRecipeRoute,
      arguments: MealPlanAssignmentArgs(date: day, slotType: slotType),
    );
  }

  Future<void> _confirmRemove(BuildContext context, MealPlanEntry entry) async {
    final shouldRemove = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Remove recipe?'),
          content: Text('Remove "${entry.recipeTitle}" from ${slotType.label}?'),
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

    final success = await context.read<MealPlanProvider>().removeEntry(entry.id);
    if (!context.mounted || success) {
      return;
    }

    final message =
        context.read<MealPlanProvider>().errorMessage ??
        'Unable to remove recipe from slot.';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _RecipeEntryRow extends StatelessWidget {
  const _RecipeEntryRow({
    required this.entry,
    required this.isViewOnly,
    required this.isLast,
    required this.onRemove,
  });

  final MealPlanEntry entry;
  final bool isViewOnly;
  final bool isLast;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: <Widget>[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _slotColor(entry.slotType),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      entry.recipeTitle,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    if (entry.recipeCategory != null) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        entry.recipeCategory!.label,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              if (!isViewOnly)
                IconButton(
                  tooltip: 'Remove',
                  onPressed: onRemove,
                  icon: const Icon(Icons.close, size: 18),
                  color: AppColors.muted,
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ),
        if (!isLast) Divider(height: 1, indent: 36, color: AppColors.border),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return AppErrorState(message: message, onRetry: onRetry);
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
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
            child: const Icon(
              Icons.lightbulb_outline,
              color: AppColors.primary,
            ),
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
                  'Tap + on any slot below to assign recipes. Each slot can hold multiple recipes.',
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
    case MealSlotType.dessert:
      return AppColors.pink;
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
    case MealSlotType.dessert:
      return Icons.cake_outlined;
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
