import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/meal_plan_entry.dart';
import '../../models/meal_plan_week.dart';
import '../../models/shopping_list_item.dart';
import '../../providers/auth_provider.dart';
import '../../providers/meal_plan_provider.dart';
import '../../providers/shopping_list_provider.dart';
import '../../services/shopping/local_shopping_list_state_service.dart';

const String shoppingListRoute = '/shopping-list';

class ShoppingListPage extends StatefulWidget {
  const ShoppingListPage({super.key});

  @override
  State<ShoppingListPage> createState() => _ShoppingListPageState();
}

class _ShoppingListPageState extends State<ShoppingListPage> {
  String? _lastSyncedMealPlanUid;
  String? _lastLoadSignature;
  bool _isCompletedExpanded = false;

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
          _HeroHeader(
            week: week,
            pendingCount: shoppingProvider.pendingItems.length,
            completedCount: shoppingProvider.completedItems.length,
            isLoading: mealPlanProvider.isLoading || shoppingProvider.isLoading,
            onPreviousWeek: () async => mealPlanProvider.showPreviousWeek(),
            onNextWeek: () async => mealPlanProvider.showNextWeek(),
          ),
          const SizedBox(height: 16),
          _OverviewCard(
            mealCount: mealPlanProvider.plannedMealCount,
            pendingCount: shoppingProvider.pendingItems.length,
            completedCount: shoppingProvider.completedItems.length,
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
              shoppingProvider.pendingItems.isEmpty &&
              shoppingProvider.completedItems.isEmpty)
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
          else ...[
            _PendingSection(
              mealPlanEntries: mealPlanProvider.entries,
              items: shoppingProvider.pendingItems,
              onToggle: shoppingProvider.completePendingItem,
            ),
            const SizedBox(height: 16),
            _CompletedSection(
              items: shoppingProvider.completedItems,
              isExpanded: _isCompletedExpanded,
              onToggleExpanded: () {
                setState(() => _isCompletedExpanded = !_isCompletedExpanded);
              },
              onReopenItem: (item) async {
                final shoppingListProvider = context
                    .read<ShoppingListProvider>();
                final mode = await _showReopenDialog(context, item);
                if (mode == null || !mounted) {
                  return;
                }
                await shoppingListProvider.reopenCompletedItem(
                  itemId: item.id,
                  mode: mode,
                );
              },
            ),
          ],
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

  Future<CompletedItemReopenMode?> _showReopenDialog(
    BuildContext context,
    ShoppingListItem item,
  ) {
    return showDialog<CompletedItemReopenMode>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reopen completed item?'),
          content: Text(
            'How would you like to return ${item.displayName} to your shopping list?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(
                context,
              ).pop(CompletedItemReopenMode.reopenSeparately),
              child: const Text('Reopen separately'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(
                context,
              ).pop(CompletedItemReopenMode.mergeIntoPending),
              child: const Text('Merge into pending'),
            ),
          ],
        );
      },
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
    required this.pendingCount,
    required this.completedCount,
    required this.isLoading,
    required this.onPreviousWeek,
    required this.onNextWeek,
  });

  final MealPlanWeek week;
  final int pendingCount;
  final int completedCount;
  final bool isLoading;
  final Future<void> Function() onPreviousWeek;
  final Future<void> Function() onNextWeek;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final total = pendingCount + completedCount;
    final progress = total == 0 ? 0.0 : completedCount / total;

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
                completedCount: completedCount,
                totalCount: total,
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
    required this.pendingCount,
    required this.completedCount,
    required this.generatedAt,
  });

  final int mealCount;
  final int pendingCount;
  final int completedCount;
  final DateTime? generatedAt;

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
                    label: 'To buy',
                    value: pendingCount.toString(),
                    icon: Icons.shopping_basket_outlined,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatTile(
                    label: 'Completed',
                    value: completedCount.toString(),
                    icon: Icons.check_circle_outline,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              mealCount == 0
                  ? 'No meals are planned yet for this week.'
                  : 'Pending items come from this week\'s meal plan. Completed items stay frozen as your shopping history.',
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

class _PendingSection extends StatelessWidget {
  const _PendingSection({
    required this.mealPlanEntries,
    required this.items,
    required this.onToggle,
  });

  final List<MealPlanEntry> mealPlanEntries;
  final List<ShoppingListItem> items;
  final Future<void> Function(String itemId) onToggle;

  @override
  Widget build(BuildContext context) {
    if (mealPlanEntries.isEmpty) {
      return const _MessageCard(
        icon: Icons.shopping_cart_outlined,
        title: 'No planned meals for this week',
        description:
            'Plan at least one recipe in the meal planner and the shopping list will be generated automatically.',
      );
    }

    if (items.isEmpty) {
      return const _MessageCard(
        icon: Icons.shopping_bag_outlined,
        title: 'Nothing left to buy',
        description:
            'Everything for this week is currently in your completed history.',
      );
    }

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
                    'To Buy',
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
                      '${items.length} active',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
                ],
              ),
            ),
            for (var index = 0; index < items.length; index++) ...[
              _PendingIngredientTile(item: items[index], onToggle: onToggle),
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

class _CompletedSection extends StatelessWidget {
  const _CompletedSection({
    required this.items,
    required this.isExpanded,
    required this.onToggleExpanded,
    required this.onReopenItem,
  });

  final List<ShoppingListItem> items;
  final bool isExpanded;
  final VoidCallback onToggleExpanded;
  final Future<void> Function(ShoppingListItem item) onReopenItem;

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
            InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: onToggleExpanded,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                child: Row(
                  children: [
                    Text(
                      'Completed',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${items.length} batch${items.length == 1 ? '' : 'es'}',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
                  ],
                ),
              ),
            ),
            if (isExpanded && items.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(8, 6, 8, 10),
                child: Text('Nothing completed yet.'),
              ),
            if (isExpanded)
              for (var index = 0; index < items.length; index++) ...[
                _CompletedIngredientTile(
                  item: items[index],
                  onReopenItem: onReopenItem,
                ),
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

class _PendingIngredientTile extends StatelessWidget {
  const _PendingIngredientTile({required this.item, required this.onToggle});

  final ShoppingListItem item;
  final Future<void> Function(String itemId) onToggle;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => unawaited(onToggle(item.id)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Row(
          children: [
            Checkbox(
              value: false,
              onChanged: (_) => unawaited(onToggle(item.id)),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.displayName,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (item.isNewBatch) const _TinyBadge(label: 'New'),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.origin == ShoppingListItemOrigin.reopened
                        ? 'Reopened from completed history'
                        : 'Tap when added to cart',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _QuantityPill(
              label: _formatQuantity(item.totalQuantity, item.unit),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompletedIngredientTile extends StatelessWidget {
  const _CompletedIngredientTile({
    required this.item,
    required this.onReopenItem,
  });

  final ShoppingListItem item;
  final Future<void> Function(ShoppingListItem item) onReopenItem;

  @override
  Widget build(BuildContext context) {
    final completedAt = item.completedAt;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => unawaited(onReopenItem(item)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.displayName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      decoration: TextDecoration.lineThrough,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    completedAt == null
                        ? 'Completed'
                        : 'Completed ${_formatDateTime(completedAt)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _QuantityPill(
              label: _formatQuantity(item.totalQuantity, item.unit),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuantityPill extends StatelessWidget {
  const _QuantityPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _TinyBadge extends StatelessWidget {
  const _TinyBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
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
    required this.completedCount,
    required this.totalCount,
  });

  final double progress;
  final int completedCount;
  final int totalCount;

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
                '$completedCount',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                '/$totalCount',
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
