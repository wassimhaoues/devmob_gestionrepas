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
import '../../theme/app_theme.dart';
import '../../widgets/app_panels.dart';

const String shoppingListRoute = '/shopping-list';

class ShoppingListPage extends StatefulWidget {
  const ShoppingListPage({super.key, this.manageMealPlanWatching = true});

  final bool manageMealPlanWatching;

  @override
  State<ShoppingListPage> createState() => _ShoppingListPageState();
}

class _ShoppingListPageState extends State<ShoppingListPage> {
  String? _lastSyncedMealPlanUid;
  String? _lastLoadSignature;
  bool _isPendingExpanded = true;
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
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: <Widget>[
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
          else ...<Widget>[
            _PendingSection(
              mealPlanEntries: mealPlanProvider.entries,
              items: shoppingProvider.pendingItems,
              isExpanded: _isPendingExpanded,
              onToggleExpanded: () {
                setState(() => _isPendingExpanded = !_isPendingExpanded);
              },
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
          actions: <Widget>[
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
    if (!widget.manageMealPlanWatching) {
      return;
    }

    final uid = context.read<AuthProvider>().currentUser?.uid;
    final mealPlanProvider = context.read<MealPlanProvider>();
    if (uid == null || uid == _lastSyncedMealPlanUid || mealPlanProvider.uid == uid) {
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
    final total = pendingCount + completedCount;
    final progress = total == 0 ? 0.0 : completedCount / total;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[AppColors.primary, AppColors.indigo],
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.indigo.withValues(alpha: 0.22),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      padding: const EdgeInsets.all(22),
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
                      'Shopping List',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${_formatDate(week.startDate)} - ${_formatDate(week.endDate)}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      pendingCount == 0
                          ? 'You are caught up for this week.'
                          : 'Check items as you shop and they will move into completed history.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
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
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              _HeroTag(
                icon: Icons.shopping_bag_outlined,
                label: '$pendingCount to buy',
              ),
              _HeroTag(
                icon: Icons.check_circle_outline,
                label: '$completedCount completed',
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
        ],
      ),
    );
  }
}

class _HeroTag extends StatelessWidget {
  const _HeroTag({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
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
    return AppPanel(
      backgroundColor: AppColors.surfaceTint,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const AppSectionTitle('Weekly Summary'),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: _StatTile(
                  label: 'Meals',
                  value: mealCount.toString(),
                  icon: Icons.calendar_month_outlined,
                  accentColor: AppColors.indigo,
                  backgroundColor: AppColors.indigoSoft,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatTile(
                  label: 'To buy',
                  value: pendingCount.toString(),
                  icon: Icons.shopping_basket_outlined,
                  accentColor: AppColors.amber,
                  backgroundColor: AppColors.amberSoft,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatTile(
                  label: 'Done',
                  value: completedCount.toString(),
                  icon: Icons.check_circle_outline,
                  accentColor: AppColors.primary,
                  backgroundColor: AppColors.primarySoft,
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
          if (generatedAt != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              'Last generated ${_formatDateTime(generatedAt!)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _PendingSection extends StatelessWidget {
  const _PendingSection({
    required this.mealPlanEntries,
    required this.items,
    required this.isExpanded,
    required this.onToggleExpanded,
    required this.onToggle,
  });

  final List<MealPlanEntry> mealPlanEntries;
  final List<ShoppingListItem> items;
  final bool isExpanded;
  final VoidCallback onToggleExpanded;
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

    return AppPanel(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: <Widget>[
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onToggleExpanded,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                children: <Widget>[
                  const Expanded(
                    child: _SectionHeader(
                      title: 'To Buy',
                      subtitle: 'Check items as they go into your cart.',
                      icon: Icons.shopping_bag_outlined,
                      accentColor: AppColors.amber,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _CountBadge(label: '${items.length} active'),
                  const SizedBox(width: 8),
                  Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
                ],
              ),
            ),
          ),
          if (isExpanded) ...<Widget>[
            const SizedBox(height: 12),
            for (var index = 0; index < items.length; index++) ...<Widget>[
              _PendingIngredientTile(item: items[index], onToggle: onToggle),
              if (index < items.length - 1)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Divider(height: 1),
                ),
            ],
          ],
        ],
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
    return AppPanel(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: <Widget>[
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onToggleExpanded,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                children: <Widget>[
                  const Expanded(
                    child: _SectionHeader(
                      title: 'Completed',
                      subtitle: 'Tap a batch to reopen it if needed.',
                      icon: Icons.check_circle_outline,
                      accentColor: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _CountBadge(
                    label: '${items.length} batch${items.length == 1 ? '' : 'es'}',
                    accentColor: AppColors.primarySoft,
                    textColor: AppColors.primaryDark,
                  ),
                  const SizedBox(width: 8),
                  Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
                ],
              ),
            ),
          ),
          if (isExpanded && items.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 10, 8, 4),
              child: Text(
                'Nothing completed yet.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          if (isExpanded) ...<Widget>[
            const SizedBox(height: 8),
            for (var index = 0; index < items.length; index++) ...<Widget>[
              _CompletedIngredientTile(
                item: items[index],
                onReopenItem: onReopenItem,
              ),
              if (index < items.length - 1)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Divider(height: 1),
                ),
            ],
          ],
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: accentColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 2),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ],
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
      borderRadius: BorderRadius.circular(20),
      onTap: () => unawaited(onToggle(item.id)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: item.isNewBatch ? AppColors.amberSoft.withValues(alpha: 0.45) : Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.borderStrong),
              ),
              child: Checkbox(
                value: false,
                onChanged: (_) => unawaited(onToggle(item.id)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          item.displayName,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
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
      borderRadius: BorderRadius.circular(20),
      onTap: () => unawaited(onReopenItem(item)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primarySoft.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.check_circle, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    item.displayName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      decoration: TextDecoration.lineThrough,
                      fontWeight: FontWeight.w700,
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
      constraints: const BoxConstraints(minWidth: 92),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.heading,
        ),
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
        color: AppColors.amberSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppColors.amber,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({
    required this.label,
    this.accentColor = AppColors.surfaceTint,
    this.textColor = AppColors.heading,
  });

  final String label;
  final Color accentColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accentColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: textColor,
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
    return AppPanel(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: <Widget>[
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, size: 28, color: AppColors.primary),
            ),
            const SizedBox(height: 14),
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
    return AppPanel(
      backgroundColor: AppColors.dangerSoft,
      borderColor: AppColors.danger.withValues(alpha: 0.18),
      child: Column(
        children: <Widget>[
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
      width: 82,
      height: 82,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          CircularProgressIndicator(
            value: progress,
            strokeWidth: 7,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            backgroundColor: Colors.white.withValues(alpha: 0.25),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  children: <InlineSpan>[
                    TextSpan(
                      text: '$completedCount',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    TextSpan(
                      text: '/$totalCount',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.88),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.accentColor,
    required this.backgroundColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color accentColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: accentColor),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
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
