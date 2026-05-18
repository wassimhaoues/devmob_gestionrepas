import 'package:flutter/material.dart';

const String shoppingListRoute = '/shopping-list';

class ShoppingListPage extends StatelessWidget {
  const ShoppingListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        _IntroCard(),
        SizedBox(height: 16),
        _ChecklistPreviewCard(),
        SizedBox(height: 16),
        _GenerationNoteCard(),
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
              'Shopping list generation will come right after meal planning.',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            Text(
              'This page now has a stable home in the app shell so the final flow can plug in cleanly once planned meals exist.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChecklistPreviewCard extends StatelessWidget {
  const _ChecklistPreviewCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Generated List Preview',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            const _ChecklistRow(label: 'Tomatoes', amount: '5 pcs'),
            const Divider(height: 20),
            const _ChecklistRow(label: 'Eggs', amount: '12 pcs'),
            const Divider(height: 20),
            const _ChecklistRow(label: 'Milk', amount: '1 L'),
          ],
        ),
      ),
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({required this.label, required this.amount});

  final String label;
  final String amount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.check_box_outline_blank),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.titleMedium),
        ),
        Text(amount, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

class _GenerationNoteCard extends StatelessWidget {
  const _GenerationNoteCard();

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
              'Generation pipeline',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            const Text('• Read planned meals for a selected week'),
            const Text('• Flatten recipe ingredients'),
            const Text('• Merge duplicate ingredients'),
            const Text('• Produce a checkable weekly shopping list'),
          ],
        ),
      ),
    );
  }
}
