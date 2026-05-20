import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/meal_plan_assignment_args.dart';
import '../../models/meal_plan_entry.dart';
import '../../models/meal_plan_week.dart';
import '../../models/meal_slot_type.dart';
import '../../providers/auth_provider.dart';
import '../../providers/meal_plan_provider.dart';
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
        padding: const EdgeInsets.all(16),
        children: [
          _WeekHeader(
            week: week,
            isLoading: provider.isLoading,
            plannedMealCount: provider.plannedMealCount,
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
          const SizedBox(height: 12),
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
          else
            Column(
              children: [
                if (!isViewOnly && provider.entries.isEmpty) ...[
                  const _EmptyWeekState(),
                  const SizedBox(height: 12),
                ],
                _DayScheduleSection(day: selectedDay, isViewOnly: isViewOnly),
              ],
            ),
        ],
      ),
    );
  }

  DateTime _effectiveSelectedDay(MealPlanWeek week) {
    if (_selectedDay != null) {
      final stillInWeek = week.days.any((d) => _isSameDate(d, _selectedDay!));
      if (stillInWeek) return _selectedDay!;
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

class _WeekHeader extends StatelessWidget {
  const _WeekHeader({
    required this.week,
    required this.isLoading,
    required this.plannedMealCount,
    required this.isViewOnly,
    required this.onPreviousWeek,
    required this.onNextWeek,
  });

  final MealPlanWeek week;
  final bool isLoading;
  final int plannedMealCount;
  final bool isViewOnly;
  final Future<void> Function() onPreviousWeek;
  final Future<void> Function() onNextWeek;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final subtitle = isViewOnly
        ? (plannedMealCount == 0
              ? 'No meals were planned'
              : '$plannedMealCount meal${plannedMealCount == 1 ? '' : 's'} recorded')
        : (plannedMealCount == 0
              ? 'No meals planned yet'
              : '$plannedMealCount meal${plannedMealCount == 1 ? '' : 's'} planned');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_formatDate(week.startDate)} – ${_formatDate(week.endDate)}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 2),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              if (isViewOnly) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.history,
                      size: 13,
                      color: colorScheme.outline,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Past week — view only',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        IconButton(
          onPressed: isLoading ? null : () => unawaited(onPreviousWeek()),
          tooltip: 'Previous week',
          icon: const Icon(Icons.chevron_left),
        ),
        IconButton(
          onPressed: isLoading ? null : () => unawaited(onNextWeek()),
          tooltip: 'Next week',
          icon: const Icon(Icons.chevron_right),
        ),
      ],
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
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: week.days.map((day) {
        final isSelected = _isSameDate(day, selectedDay);
        final isToday = _isSameDate(day, todayNorm);
        final entryCount =
            entries.where((e) => _isSameDate(e.date, day)).length;

        final Color bgColor;
        final Color fgColor;
        final Border? border;

        if (isSelected) {
          bgColor = colorScheme.primary;
          fgColor = colorScheme.onPrimary;
          border = null;
        } else if (isToday) {
          bgColor = colorScheme.primaryContainer.withValues(alpha: 0.35);
          fgColor = colorScheme.primary;
          border = Border.all(color: colorScheme.primary, width: 1.5);
        } else {
          bgColor = colorScheme.surfaceContainerHighest.withValues(alpha: 0.4);
          fgColor = colorScheme.onSurface;
          border = null;
        }

        return Expanded(
          child: GestureDetector(
            onTap: () => onDaySelected(day),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(10),
                border: border,
              ),
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _shortDay(day.weekday),
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: fgColor),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${day.day}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: fgColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: 8,
                    child: entryCount > 0
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              entryCount.clamp(0, 3),
                              (_) => Container(
                                width: 4,
                                height: 4,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 1,
                                ),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSelected
                                      ? colorScheme.onPrimary
                                            .withValues(alpha: 0.85)
                                      : colorScheme.primary,
                                ),
                              ),
                            ),
                          )
                        : null,
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _formatDay(day),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 10),
        for (final slot in MealSlotType.values) ...[
          _MealSlotRow(
            day: day,
            slotType: slot,
            entry: provider.entryFor(date: day, slotType: slot),
            isViewOnly: isViewOnly,
          ),
          if (slot != MealSlotType.values.last) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _MealSlotRow extends StatelessWidget {
  const _MealSlotRow({
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
    final colorScheme = Theme.of(context).colorScheme;
    final isEmpty = entry == null;

    final avatar = CircleAvatar(
      radius: 18,
      backgroundColor: isViewOnly && isEmpty
          ? colorScheme.surfaceContainerHighest
          : colorScheme.primaryContainer,
      foregroundColor:
          isViewOnly && isEmpty ? colorScheme.outline : colorScheme.primary,
      child: Icon(_iconForSlot(slotType), size: 18),
    );

    final slotLabel = SizedBox(width: 88, child: Text(slotType.label));

    final slotContent = Expanded(
      child: isEmpty
          ? Text(
              isViewOnly ? 'No meal planned' : 'Tap to assign a recipe',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isViewOnly ? colorScheme.outline : null,
                fontStyle: isViewOnly ? FontStyle.italic : null,
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry!.recipeTitle,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                if (entry!.recipeCategory != null)
                  Text(
                    entry!.recipeCategory!.label,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
    );

    final trailing = isViewOnly
        ? (isEmpty
              ? const SizedBox.shrink()
              : Icon(Icons.history, size: 16, color: colorScheme.outline))
        : (isEmpty
              ? const Icon(Icons.add_circle_outline)
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Remove assignment',
                      onPressed: () => _confirmRemove(context),
                      icon: const Icon(Icons.delete_outline),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ));

    final rowContent = Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          avatar,
          const SizedBox(width: 12),
          slotLabel,
          slotContent,
          trailing,
        ],
      ),
    );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: colorScheme.surfaceContainerHighest.withValues(
          alpha: isViewOnly && isEmpty ? 0.25 : 0.45,
        ),
      ),
      child: isViewOnly
          ? rowContent
          : InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _openAssignment(context),
              child: rowContent,
            ),
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
          actions: [
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
    return Padding(
      padding: const EdgeInsets.only(top: 48),
      child: Column(
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: Theme.of(context).colorScheme.error,
          ),
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
    return Card(
      elevation: 0,
      color: Theme.of(
        context,
      ).colorScheme.primaryContainer.withValues(alpha: 0.32),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.lightbulb_outline),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your week is empty',
                    style: Theme.of(context).textTheme.titleMedium,
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
      ),
    );
  }
}

bool _isSameDate(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
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
