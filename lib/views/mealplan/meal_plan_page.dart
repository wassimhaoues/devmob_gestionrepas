import 'package:flutter/material.dart';

const String mealPlanRoute = '/meal-plan';

class MealPlanPage extends StatelessWidget {
  const MealPlanPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        _IntroCard(),
        SizedBox(height: 16),
        _WeekPreviewCard(),
        SizedBox(height: 16),
        _RoadmapCard(),
      ],
    );
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(
        context,
      ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Weekly meal planning is the next core feature.',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            Text(
              'This screen is now part of the real app shell, and the next implementation phase will turn it into the working calendar required by the PDF.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekPreviewCard extends StatelessWidget {
  const _WeekPreviewCard();

  @override
  Widget build(BuildContext context) {
    final days = <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Week Preview', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            for (final day in days) ...[
              _DayPreviewRow(day: day),
              if (day != days.last) const Divider(height: 20),
            ],
          ],
        ),
      ),
    );
  }
}

class _DayPreviewRow extends StatelessWidget {
  const _DayPreviewRow({required this.day});

  final String day;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 52,
          child: Text(day, style: Theme.of(context).textTheme.titleMedium),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              Chip(label: Text('Breakfast')),
              Chip(label: Text('Lunch')),
              Chip(label: Text('Dinner')),
            ],
          ),
        ),
      ],
    );
  }
}

class _RoadmapCard extends StatelessWidget {
  const _RoadmapCard();

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
              'Planned in the next phase',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            const Text('• Weekly calendar navigation'),
            const Text('• Breakfast, lunch, and dinner slots'),
            const Text('• Recipe assignment to each slot'),
            const Text('• Persistence per authenticated user'),
          ],
        ),
      ),
    );
  }
}
