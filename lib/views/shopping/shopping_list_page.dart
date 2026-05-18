import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/meal_plan_entry.dart';
import '../../models/meal_plan_week.dart';
import '../../models/shopping_list_item.dart';
import '../../providers/auth_provider.dart';
import '../../providers/meal_plan_provider.dart';
import '../../providers/shopping_list_provider.dart';

const String shoppingListRoute = '/shopping-list';

class ShoppingListPage extends StatefulWidget {
  const ShoppingListPage({super.key});

  @override
  State<ShoppingListPage> createState() => _ShoppingListPageState();
}

class _ShoppingListPageState extends State<ShoppingListPage> {
  String? _lastSyncedMealPlanUid;
  String? _lastLoadSignature;

  @override
  Widget build(BuildContext context) {
    _syncMealPlanWatcher(context);
    _syncShoppingList(context);

    final authProvider = context.watch<AuthProvider>();
    final mealPlanProvider = context.watch<MealPlanProvider>();
    final shoppingProvider = context.watch<ShoppingListProvider>();
    final uid = authProvider.currentUser?.uid;
    final week = mealPlanProvider.activeWeek;

    return RefreshIndicator(
      onRefresh: () => _refreshProviders(
        uid: uid,
        week: week,
        mealPlanProvider: mealPlanProvider,
        shoppingProvider: shoppingProvider,
      ),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _WeekHeader(
            week: week,
            itemCount: shoppingProvider.items.length,
            checkedCount: shoppingProvider.checkedItemCount,
            isLoading: mealPlanProvider.isLoading || shoppingProvider.isLoading,
            onPreviousWeek: () async => mealPlanProvider.showPreviousWeek(),
            onNextWeek: () async => mealPlanProvider.showNextWeek(),
            onClearChecked: shoppingProvider.checkedItemCount == 0
                ? null
                : shoppingProvider.clearCheckedItems,
          ),
          const SizedBox(height: 16),
          _ContextCard(
            mealCount: mealPlanProvider.plannedMealCount,
            generatedAt: shoppingProvider.shoppingList?.generatedAt,
          ),
          const SizedBox(height: 16),
          if (uid == null)
            const _MessageCard(
              icon: Icons.lock_outline,
              title: 'Sign in required',
              description:
                  'You need an authenticated session to generate a shopping list.',
            )
          else if (mealPlanProvider.status == MealPlanProviderStatus.loading &&
              mealPlanProvider.entries.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 56),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (mealPlanProvider.status == MealPlanProviderStatus.error &&
              mealPlanProvider.entries.isEmpty)
            _ErrorCard(
              message:
                  mealPlanProvider.errorMessage ??
                  'Unable to load the meal plan for this week.',
              onRetry: () => _refreshProviders(
                uid: uid,
                week: week,
                mealPlanProvider: mealPlanProvider,
                shoppingProvider: shoppingProvider,
              ),
            )
          else if (shoppingProvider.status ==
                  ShoppingListProviderStatus.loading &&
              shoppingProvider.items.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 56),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (shoppingProvider.status == ShoppingListProviderStatus.error)
            _ErrorCard(
              message:
                  shoppingProvider.errorMessage ??
                  'Unable to generate the shopping list.',
              onRetry: () => _refreshProviders(
                uid: uid,
                week: week,
                mealPlanProvider: mealPlanProvider,
                shoppingProvider: shoppingProvider,
              ),
            )
          else if (mealPlanProvider.entries.isEmpty)
            const _MessageCard(
              icon: Icons.shopping_cart_outlined,
              title: 'No planned meals for this week',
              description:
                  'Plan at least one recipe in the meal planner and the shopping list will be generated automatically.',
            )
          else if (shoppingProvider.items.isEmpty)
            const _MessageCard(
              icon: Icons.receipt_long_outlined,
              title: 'No ingredients found',
              description:
                  'Your planned recipes do not contain any usable ingredients yet.',
            )
          else
            _ChecklistCard(
              items: shoppingProvider.items,
              onToggle: shoppingProvider.toggleItem,
            ),
        ],
      ),
    );
  }

  Future<void> _refreshProviders({
    required String? uid,
    required MealPlanWeek week,
    required MealPlanProvider mealPlanProvider,
    required ShoppingListProvider shoppingProvider,
  }) async {
    if (uid == null) {
      return;
    }

    await mealPlanProvider.refresh();
    await shoppingProvider.refresh(
      uid: uid,
      week: week,
      entries: mealPlanProvider.entries,
    );
  }

  void _syncMealPlanWatcher(BuildContext context) {
    final uid = context.read<AuthProvider>().currentUser?.uid;
    if (uid == null || uid == _lastSyncedMealPlanUid) {
      return;
    }

    _lastSyncedMealPlanUid = uid;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(context.read<MealPlanProvider>().startWatchingWeek(uid: uid));
    });
  }

  void _syncShoppingList(BuildContext context) {
    final uid = context.read<AuthProvider>().currentUser?.uid;
    if (uid == null) {
      _lastLoadSignature = null;
      return;
    }

    final mealPlanProvider = context.read<MealPlanProvider>();
    final signature = _buildLoadSignature(
      uid: uid,
      week: mealPlanProvider.activeWeek,
      entries: mealPlanProvider.entries,
    );
    if (signature == _lastLoadSignature) {
      return;
    }

    _lastLoadSignature = signature;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(
        context.read<ShoppingListProvider>().loadForWeek(
          uid: uid,
          week: mealPlanProvider.activeWeek,
          entries: mealPlanProvider.entries,
        ),
      );
    });
  }

  String _buildLoadSignature({
    required String uid,
    required MealPlanWeek week,
    required List<MealPlanEntry> entries,
  }) {
    final entrySignature =
        entries.map((entry) => '${entry.id}:${entry.recipeId}').toList()
          ..sort();
    return '$uid|${week.startDate.toIso8601String()}|${entrySignature.join(',')}';
  }
}

class _WeekHeader extends StatelessWidget {
  const _WeekHeader({
    required this.week,
    required this.itemCount,
    required this.checkedCount,
    required this.isLoading,
    required this.onPreviousWeek,
    required this.onNextWeek,
    required this.onClearChecked,
  });

  final MealPlanWeek week;
  final int itemCount;
  final int checkedCount;
  final bool isLoading;
  final Future<void> Function() onPreviousWeek;
  final Future<void> Function() onNextWeek;
  final Future<void> Function()? onClearChecked;

  @override
  Widget build(BuildContext context) {
    final subtitle = itemCount == 0
        ? 'No shopping items generated yet'
        : '$checkedCount of $itemCount item${itemCount == 1 ? '' : 's'} checked';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_formatDate(week.startDate)} - ${_formatDate(week.endDate)}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
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
        PopupMenuButton<String>(
          tooltip: 'Shopping actions',
          onSelected: (value) {
            if (value == 'clear' && onClearChecked != null) {
              unawaited(onClearChecked!.call());
            }
          },
          itemBuilder: (context) => <PopupMenuEntry<String>>[
            PopupMenuItem<String>(
              value: 'clear',
              enabled: onClearChecked != null,
              child: const Text('Uncheck all'),
            ),
          ],
        ),
      ],
    );
  }
}

class _ContextCard extends StatelessWidget {
  const _ContextCard({required this.mealCount, required this.generatedAt});

  final int mealCount;
  final DateTime? generatedAt;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: colorScheme.primaryContainer.withValues(alpha: 0.3),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Based on this week\'s meal plan',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              mealCount == 0
                  ? 'No meals are planned yet for this week.'
                  : '$mealCount planned meal${mealCount == 1 ? '' : 's'} included in the generated list.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (generatedAt != null) ...[
              const SizedBox(height: 8),
              Text(
                'Last generated ${_formatDateTime(generatedAt!)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChecklistCard extends StatelessWidget {
  const _ChecklistCard({required this.items, required this.onToggle});

  final List<ShoppingListItem> items;
  final Future<void> Function(String itemId) onToggle;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Column(
        children: [
          for (var index = 0; index < items.length; index++) ...[
            CheckboxListTile(
              value: items[index].isChecked,
              onChanged: (_) => unawaited(onToggle(items[index].id)),
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(items[index].displayName),
              subtitle: Text(_buildSourceLabel(items[index])),
              secondary: Text(
                _formatQuantity(items[index].totalQuantity, items[index].unit),
              ),
            ),
            if (index < items.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }

  String _buildSourceLabel(ShoppingListItem item) {
    final recipeCount = item.sourceRecipeIds.length;
    return recipeCount == 1
        ? 'Used in 1 planned recipe'
        : 'Used in $recipeCount planned recipes';
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(icon, size: 40),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(
        context,
      ).colorScheme.errorContainer.withValues(alpha: 0.55),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => unawaited(onRetry()),
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDate(DateTime date) {
  const months = <String>[
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
  return '${months[date.month - 1]} ${date.day}';
}

String _formatDateTime(DateTime dateTime) {
  final hour = dateTime.hour.toString().padLeft(2, '0');
  final minute = dateTime.minute.toString().padLeft(2, '0');
  return '${_formatDate(dateTime)} at $hour:$minute';
}

String _formatQuantity(double quantity, String unit) {
  final normalizedQuantity = quantity % 1 == 0
      ? quantity.toStringAsFixed(0)
      : quantity
            .toStringAsFixed(2)
            .replaceFirst(RegExp(r'0+$'), '')
            .replaceFirst(RegExp(r'\.$'), '');
  return '$normalizedQuantity $unit';
}
