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
  const MealPlanPage({super.key});

  @override
  State<MealPlanPage> createState() => _MealPlanPageState();
}

class _MealPlanPageState extends State<MealPlanPage> {
  String? _lastSyncedUid;

  @override
  Widget build(BuildContext context) {
    _syncWeekWatcher(context);

    final provider = context.watch<MealPlanProvider>();
    final week = provider.activeWeek;

    return RefreshIndicator(
      onRefresh: provider.refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _IntroCard(week: week, plannedMealCount: provider.plannedMealCount),
          const SizedBox(height: 16),
          _WeekHeader(
            week: week,
            isLoading: provider.isLoading,
            onPreviousWeek: provider.showPreviousWeek,
            onNextWeek: provider.showNextWeek,
          ),
          const SizedBox(height: 12),
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
                if (provider.entries.isEmpty) ...[
                  const _EmptyWeekState(),
                  const SizedBox(height: 12),
                ],
                _WeekScheduleCard(week: week),
              ],
            ),
          const SizedBox(height: 16),
          const _PhaseNoteCard(),
        ],
      ),
    );
  }

  void _syncWeekWatcher(BuildContext context) {
    final uid = context.read<AuthProvider>().currentUser?.uid;
    if (uid == null || uid == _lastSyncedUid) {
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

class _IntroCard extends StatelessWidget {
  const _IntroCard({required this.week, required this.plannedMealCount});

  final MealPlanWeek week;
  final int plannedMealCount;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(
        context,
      ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Weekly meal planning',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            Text(
              'Build your week from breakfast to dinner. This checkpoint gives you the live week structure and persisted entries; recipe assignment is the next step.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 12),
            Text(
              '${_formatDate(week.startDate)} - ${_formatDate(week.endDate)} • $plannedMealCount planned meals',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekHeader extends StatelessWidget {
  const _WeekHeader({
    required this.week,
    required this.isLoading,
    required this.onPreviousWeek,
    required this.onNextWeek,
  });

  final MealPlanWeek week;
  final bool isLoading;
  final Future<void> Function() onPreviousWeek;
  final Future<void> Function() onNextWeek;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Week of ${_formatDate(week.startDate)}',
            style: Theme.of(context).textTheme.titleLarge,
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

class _WeekScheduleCard extends StatelessWidget {
  const _WeekScheduleCard({required this.week});

  final MealPlanWeek week;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Week Schedule', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            for (final day in week.days) ...[
              _DayScheduleSection(day: day),
              if (day != week.days.last) const Divider(height: 24),
            ],
          ],
        ),
      ),
    );
  }
}

class _DayScheduleSection extends StatelessWidget {
  const _DayScheduleSection({required this.day});

  final DateTime day;

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
  });

  final DateTime day;
  final MealSlotType slotType;
  final MealPlanEntry? entry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _openAssignment(context),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: colorScheme.primaryContainer,
                foregroundColor: colorScheme.primary,
                child: Icon(_iconForSlot(slotType), size: 18),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 88,
                child: Text(slotType.label),
              ),
              Expanded(
                child: entry == null
                    ? Text(
                        'Tap to assign a recipe',
                        style: Theme.of(context).textTheme.bodyMedium,
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
              ),
              if (entry == null)
                const Icon(Icons.add_circle_outline)
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Remove assignment',
                      onPressed: () => _confirmRemove(context),
                      icon: const Icon(Icons.delete_outline),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
            ],
          ),
        ),
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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

class _PhaseNoteCard extends StatelessWidget {
  const _PhaseNoteCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(
        context,
      ).colorScheme.primaryContainer.withValues(alpha: 0.35),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Next checkpoint',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            const Text('• pick a recipe for any slot'),
            const Text('• replace or remove assignments from the UI'),
            const Text('• connect recipe selection flow into this week view'),
          ],
        ),
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
