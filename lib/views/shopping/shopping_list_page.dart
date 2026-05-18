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
  bool _hideCheckedItems = false;

  @override
  Widget build(BuildContext context) {
    _syncMealPlanWatcher(context);
    _syncShoppingList(context);

    final authProvider = context.watch<AuthProvider>();
    final mealPlanProvider = context.watch<MealPlanProvider>();
    final shoppingProvider = context.watch<ShoppingListProvider>();
    final uid = authProvider.currentUser?.uid;
    final week = mealPlanProvider.activeWeek;
    final visibleItems = _hideCheckedItems
        ? shoppingProvider.items.where((item) => !item.isChecked).toList()
        : shoppingProvider.items;

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
          _HeroHeader(
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
          _OverviewCard(
            mealCount: mealPlanProvider.plannedMealCount,
            itemCount: shoppingProvider.items.length,
            checkedCount: shoppingProvider.checkedItemCount,
            generatedAt: shoppingProvider.shoppingList?.generatedAt,
            hideCheckedItems: _hideCheckedItems,
            onToggleHideChecked: shoppingProvider.checkedItemCount == 0
                ? null
                : () {
                    setState(() {
                      _hideCheckedItems = !_hideCheckedItems;
                    });
                  },
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
          else if (visibleItems.isEmpty)
            _MessageCard(
              icon: Icons.check_circle_outline,
              title: 'Everything is checked off',
              description: _hideCheckedItems
                  ? 'All items are hidden because they are marked complete. Turn off "Hide completed" or uncheck all items.'
                  : 'Your whole list is complete for this week.',
            )
          else
            _ChecklistCard(
              items: visibleItems,
              totalItemCount: shoppingProvider.items.length,
              checkedItemCount: shoppingProvider.checkedItemCount,
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

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({
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
    final colorScheme = Theme.of(context).colorScheme;
    final progress = itemCount == 0 ? 0.0 : checkedCount / itemCount;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            colorScheme.primaryContainer,
            colorScheme.surfaceContainerHighest,
          ],
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Shopping List',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${_formatDate(week.startDate)} - ${_formatDate(week.endDate)}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
              _ProgressBadge(
                progress: progress,
                checkedCount: checkedCount,
                itemCount: itemCount,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _ActionPill(
                icon: Icons.chevron_left,
                label: 'Previous',
                onTap: isLoading ? null : () => unawaited(onPreviousWeek()),
              ),
              const SizedBox(width: 10),
              _ActionPill(
                icon: Icons.chevron_right,
                label: 'Next',
                onTap: isLoading ? null : () => unawaited(onNextWeek()),
              ),
              const Spacer(),
              if (onClearChecked != null)
                TextButton.icon(
                  onPressed: () => unawaited(onClearChecked!.call()),
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('Uncheck all'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({
    required this.mealCount,
    required this.itemCount,
    required this.checkedCount,
    required this.generatedAt,
    required this.hideCheckedItems,
    required this.onToggleHideChecked,
  });

  final int mealCount;
  final int itemCount;
  final int checkedCount;
  final DateTime? generatedAt;
  final bool hideCheckedItems;
  final VoidCallback? onToggleHideChecked;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.65),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Weekly summary',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _StatTile(
                    label: 'Meals',
                    value: mealCount.toString(),
                    icon: Icons.calendar_month_outlined,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatTile(
                    label: 'Items left',
                    value: (itemCount - checkedCount).toString(),
                    icon: Icons.shopping_basket_outlined,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatTile(
                    label: 'Done',
                    value: checkedCount.toString(),
                    icon: Icons.check_circle_outline,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              mealCount == 0
                  ? 'No meals are planned yet for this week.'
                  : 'Your shopping list is generated directly from this week\'s planned meals.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (generatedAt != null) ...[
              const SizedBox(height: 8),
              Text(
                'Last generated ${_formatDateTime(generatedAt!)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (onToggleHideChecked != null) ...[
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerLeft,
                child: FilterChip(
                  selected: hideCheckedItems,
                  onSelected: (_) => onToggleHideChecked!.call(),
                  avatar: Icon(
                    hideCheckedItems
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 18,
                  ),
                  label: Text(
                    hideCheckedItems ? 'Hide completed on' : 'Hide completed',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChecklistCard extends StatelessWidget {
  const _ChecklistCard({
    required this.items,
    required this.totalItemCount,
    required this.checkedItemCount,
    required this.onToggle,
  });

  final List<ShoppingListItem> items;
  final int totalItemCount;
  final int checkedItemCount;
  final Future<void> Function(String itemId) onToggle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
              child: Row(
                children: [
                  Text(
                    'Ingredients',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$checkedItemCount / $totalItemCount completed',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
                ],
              ),
            ),
            for (var index = 0; index < items.length; index++) ...[
              _IngredientTile(item: items[index], onToggle: onToggle),
              if (index < items.length - 1)
                Divider(
                  height: 1,
                  indent: 14,
                  endIndent: 14,
                  color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _IngredientTile extends StatelessWidget {
  const _IngredientTile({required this.item, required this.onToggle});

  final ShoppingListItem item;
  final Future<void> Function(String itemId) onToggle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final titleStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
      decoration: item.isChecked ? TextDecoration.lineThrough : null,
      color: item.isChecked ? colorScheme.onSurfaceVariant : null,
      fontWeight: FontWeight.w600,
    );

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => unawaited(onToggle(item.id)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Row(
          children: [
            Checkbox(
              value: item.isChecked,
              onChanged: (_) => unawaited(onToggle(item.id)),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.displayName, style: titleStyle),
                  const SizedBox(height: 4),
                  Text(
                    item.isChecked ? 'Completed' : 'Tap when added to cart',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: item.isChecked
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: item.isChecked
                    ? colorScheme.primaryContainer
                    : colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                _formatQuantity(item.totalQuantity, item.unit),
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
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

class _ProgressBadge extends StatelessWidget {
  const _ProgressBadge({
    required this.progress,
    required this.checkedCount,
    required this.itemCount,
  });

  final double progress;
  final int checkedCount;
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      height: 72,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: progress,
            strokeWidth: 7,
            backgroundColor: Theme.of(
              context,
            ).colorScheme.surface.withValues(alpha: 0.65),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$checkedCount',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                '/$itemCount',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({
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
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: enabled
              ? colorScheme.surface.withValues(alpha: 0.85)
              : colorScheme.surface.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 6),
            Text(label),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: colorScheme.primary),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
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
