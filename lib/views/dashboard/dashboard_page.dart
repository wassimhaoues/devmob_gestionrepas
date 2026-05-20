import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_user.dart';
import '../../models/recipe.dart';
import '../../providers/auth_provider.dart';
import '../../providers/meal_plan_provider.dart';
import '../../providers/recipe_provider.dart';
import '../../providers/shopping_list_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_panels.dart';
import '../mealplan/meal_plan_page.dart';
import '../recipe/add_recipe_page.dart';
import '../recipe/recipe_list_page.dart';
import '../shopping/shopping_list_page.dart';

const String dashboardRoute = '/dashboard';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _selectedIndex = 0;
  String? _lastRecipeSyncUid;
  String? _lastMealPlanSyncUid;

  static const List<String> _titles = <String>[
    'Home',
    'Recipes',
    'Meal Plan',
    'Shopping List',
  ];

  @override
  Widget build(BuildContext context) {
    _syncSignedInProviders(context);

    final authProvider = context.watch<AuthProvider>();
    final mealPlanProvider = context.watch<MealPlanProvider>();
    final recipeProvider = context.watch<RecipeProvider>();
    final shoppingProvider = context.watch<ShoppingListProvider>();
    final isRefreshingModules =
        recipeProvider.isLoading ||
        mealPlanProvider.isLoading ||
        shoppingProvider.isLoading;

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
        actions: <Widget>[
          IconButton(
            onPressed: isRefreshingModules ? null : _refreshVisibleData,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh data',
          ),
          IconButton(
            onPressed: authProvider.isLoading ? null : _signOut,
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: <Widget>[
          _HomeTab(
            user: authProvider.currentUser,
            mealPlanProvider: mealPlanProvider,
            recipeProvider: recipeProvider,
            shoppingProvider: shoppingProvider,
            onRetryRecipes: _refreshRecipes,
            onRetryMealPlan: _refreshMealPlanAndShopping,
            onRetryShopping: _refreshShoppingSummary,
            onOpenRecipes: () => setState(() => _selectedIndex = 1),
            onOpenFavorites: () =>
                Navigator.of(context).pushNamed(favoriteRecipesRoute),
            onOpenMealPlan: () => setState(() => _selectedIndex = 2),
            onOpenShoppingList: () => setState(() => _selectedIndex = 3),
          ),
          _RecipesHubTab(
            recipeProvider: recipeProvider,
            onRetryRecipes: _refreshRecipes,
            onBrowseAllRecipes: () =>
                Navigator.of(context).pushNamed(recipeListRoute),
            onOpenFavorites: () =>
                Navigator.of(context).pushNamed(favoriteRecipesRoute),
            onAddRecipe: () => Navigator.of(context).pushNamed(addRecipeRoute),
          ),
          const MealPlanPage(manageMealPlanWatching: false),
          const ShoppingListPage(manageMealPlanWatching: false),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (int index) {
          setState(() => _selectedIndex = index);
        },
        destinations: const <NavigationDestination>[
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Recipes',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Meal Plan',
          ),
          NavigationDestination(
            icon: Icon(Icons.shopping_cart_outlined),
            selectedIcon: Icon(Icons.shopping_cart),
            label: 'Shopping',
          ),
        ],
      ),
    );
  }

  void _syncSignedInProviders(BuildContext context) {
    final uid = context.read<AuthProvider>().currentUser?.uid;
    final recipeProvider = context.read<RecipeProvider>();
    final mealPlanProvider = context.read<MealPlanProvider>();

    if (uid == null) {
      _lastRecipeSyncUid = null;
      _lastMealPlanSyncUid = null;
      return;
    }

    if (uid != _lastRecipeSyncUid && recipeProvider.uid != uid) {
      _lastRecipeSyncUid = uid;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        unawaited(recipeProvider.startWatching(uid: uid));
      });
    }

    if (uid != _lastMealPlanSyncUid && mealPlanProvider.uid != uid) {
      _lastMealPlanSyncUid = uid;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        unawaited(mealPlanProvider.startWatchingWeek(uid: uid));
      });
    }
  }

  Future<void> _signOut() async {
    final recipeProvider = context.read<RecipeProvider>();
    final mealPlanProvider = context.read<MealPlanProvider>();
    final shoppingListProvider = context.read<ShoppingListProvider>();
    final authProvider = context.read<AuthProvider>();

    await recipeProvider.stopWatching();
    await mealPlanProvider.stopWatching();
    shoppingListProvider.reset();
    _lastRecipeSyncUid = null;
    _lastMealPlanSyncUid = null;
    await authProvider.signOut();
  }

  Future<void> _refreshVisibleData() async {
    if (_selectedIndex == 1) {
      await _refreshRecipes();
      return;
    }
    if (_selectedIndex == 2) {
      await _refreshMealPlanAndShopping();
      return;
    }
    if (_selectedIndex == 3) {
      await _refreshShoppingSummary();
      return;
    }

    await _refreshRecipes();
    await _refreshMealPlanAndShopping();
  }

  Future<void> _refreshRecipes() async {
    await context.read<RecipeProvider>().refresh();
  }

  Future<void> _refreshMealPlanAndShopping() async {
    final mealPlanProvider = context.read<MealPlanProvider>();
    await mealPlanProvider.refresh();
    await _refreshShoppingSummary();
  }

  Future<void> _refreshShoppingSummary() async {
    final authProvider = context.read<AuthProvider>();
    final mealPlanProvider = context.read<MealPlanProvider>();
    final shoppingProvider = context.read<ShoppingListProvider>();
    final uid = authProvider.currentUser?.uid;
    if (uid == null) {
      return;
    }

    await shoppingProvider.refresh(
      uid: uid,
      week: mealPlanProvider.activeWeek,
      entries: mealPlanProvider.entries,
    );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab({
    required this.user,
    required this.mealPlanProvider,
    required this.recipeProvider,
    required this.shoppingProvider,
    required this.onRetryRecipes,
    required this.onRetryMealPlan,
    required this.onRetryShopping,
    required this.onOpenRecipes,
    required this.onOpenFavorites,
    required this.onOpenMealPlan,
    required this.onOpenShoppingList,
  });

  final AppUser? user;
  final MealPlanProvider mealPlanProvider;
  final RecipeProvider recipeProvider;
  final ShoppingListProvider shoppingProvider;
  final Future<void> Function() onRetryRecipes;
  final Future<void> Function() onRetryMealPlan;
  final Future<void> Function() onRetryShopping;
  final VoidCallback onOpenRecipes;
  final VoidCallback onOpenFavorites;
  final VoidCallback onOpenMealPlan;
  final VoidCallback onOpenShoppingList;

  @override
  Widget build(BuildContext context) {
    final recipes = recipeProvider.recipes;
    final favoriteCount = recipes
        .where((Recipe recipe) => recipe.isFavorite)
        .length;
    final recentRecipes = recipes.take(3).toList();
    final greeting = _buildGreeting(user);
    final plannedMealCount = mealPlanProvider.plannedMealCount;
    final plannedMealValue =
        mealPlanProvider.status == MealPlanProviderStatus.loading &&
            plannedMealCount == 0
        ? '...'
        : plannedMealCount.toString();
    final shoppingPendingCount = shoppingProvider.pendingItems.length;
    final shoppingValue =
        shoppingProvider.status == ShoppingListProviderStatus.loading &&
            shoppingPendingCount == 0 &&
            shoppingProvider.completedItems.isEmpty
        ? '...'
        : shoppingPendingCount.toString();
    final shoppingHelperText = switch (shoppingProvider.status) {
      ShoppingListProviderStatus.error => 'Open shopping tab to retry',
      _ when plannedMealCount == 0 => 'After planning',
      _ when shoppingPendingCount == 0 => 'Nothing left this week',
      _ => 'To buy this week',
    };

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            AppColors.primary.withValues(alpha: 0.16),
            AppColors.background,
          ],
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: <Widget>[
          _DashboardHero(
            greeting: greeting,
            initials: _buildInitials(user),
            recipeCount: recipes.length,
            favoriteCount: favoriteCount,
            plannedMealCount: plannedMealCount,
          ),
          if (recipeProvider.status == RecipeProviderStatus.error) ...<Widget>[
            const SizedBox(height: 16),
            _SyncStatusCard(
              icon: Icons.menu_book_outlined,
              title: 'Recipes need attention',
              description:
                  recipeProvider.errorMessage ??
                  'Unable to refresh your recipes right now.',
              actionLabel: 'Retry recipes',
              onAction: onRetryRecipes,
            ),
          ] else if (recipeProvider.status == RecipeProviderStatus.loading &&
              recipes.isEmpty) ...<Widget>[
            const SizedBox(height: 16),
            const _SyncStatusCard(
              icon: Icons.sync,
              title: 'Syncing recipes',
              description:
                  'Fetching your saved recipes for the dashboard summary.',
            ),
          ],
          if (mealPlanProvider.status ==
              MealPlanProviderStatus.error) ...<Widget>[
            const SizedBox(height: 12),
            _SyncStatusCard(
              icon: Icons.calendar_month_outlined,
              title: 'Meal plan could not be refreshed',
              description:
                  mealPlanProvider.errorMessage ??
                  'Current-week planning data is temporarily unavailable.',
              actionLabel: 'Retry meal plan',
              onAction: onRetryMealPlan,
            ),
          ] else if (mealPlanProvider.status ==
                  MealPlanProviderStatus.loading &&
              plannedMealCount == 0) ...<Widget>[
            const SizedBox(height: 12),
            const _SyncStatusCard(
              icon: Icons.sync,
              title: 'Syncing this week',
              description:
                  'Loading your current meal plan so shopping can stay in sync.',
            ),
          ],
          if (shoppingProvider.status ==
              ShoppingListProviderStatus.error) ...<Widget>[
            const SizedBox(height: 12),
            _SyncStatusCard(
              icon: Icons.shopping_cart_outlined,
              title: 'Shopping summary unavailable',
              description:
                  shoppingProvider.errorMessage ??
                  'The weekly shopping summary could not be generated.',
              actionLabel: 'Retry shopping',
              onAction: onRetryShopping,
            ),
          ] else if (shoppingProvider.status ==
                  ShoppingListProviderStatus.loading &&
              plannedMealCount > 0 &&
              shoppingProvider.items.isEmpty) ...<Widget>[
            const SizedBox(height: 12),
            const _SyncStatusCard(
              icon: Icons.sync,
              title: 'Generating shopping summary',
              description:
                  'Aggregating this week\'s planned ingredients for your shopping list.',
            ),
          ],
          const SizedBox(height: 18),
          AppPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                AppSectionTitle(
                  'Weekly Snapshot',
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      shoppingHelperText,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: AppColors.primary),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _StatCard(
                        label: 'Meals planned',
                        value: plannedMealValue,
                        icon: Icons.calendar_today_outlined,
                        helperText: plannedMealCount == 0
                            ? 'Current week'
                            : 'This week',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        label: 'Shopping items',
                        value: shoppingValue,
                        icon: Icons.shopping_basket_outlined,
                        helperText: shoppingHelperText,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Quick Actions',
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: <Widget>[
                _QuickActionChip(
                  label: 'Browse Recipes',
                  icon: Icons.menu_book_outlined,
                  onPressed: onOpenRecipes,
                ),
                _QuickActionChip(
                  label: 'Favorite Recipes',
                  icon: Icons.star_outline,
                  onPressed: onOpenFavorites,
                ),
                _QuickActionChip(
                  label: 'Meal Plan',
                  icon: Icons.calendar_month_outlined,
                  onPressed: onOpenMealPlan,
                ),
                _QuickActionChip(
                  label: 'Shopping List',
                  icon: Icons.shopping_cart_outlined,
                  onPressed: onOpenShoppingList,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Recent Recipes',
            child: recentRecipes.isEmpty
                ? const _InfoState(
                    icon: Icons.menu_book_outlined,
                    title: 'No recipes yet',
                    description:
                        'Create your first recipe to start building the rest of your weekly workflow.',
                  )
                : Column(
                    children: <Widget>[
                      for (final Recipe recipe in recentRecipes) ...<Widget>[
                        _RecentRecipeTile(recipe: recipe),
                        if (recipe != recentRecipes.last)
                          const Divider(height: 20),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  String _buildGreeting(AppUser? user) {
    final displayName = user?.displayName.trim() ?? '';
    if (displayName.isEmpty) {
      return 'Welcome back';
    }

    return 'Welcome back, $displayName';
  }

  String _buildInitials(AppUser? user) {
    final displayName = user?.displayName.trim() ?? '';
    if (displayName.isEmpty) {
      return 'MP';
    }

    final parts = displayName.split(RegExp(r'\s+'));
    final first = parts.first.isNotEmpty ? parts.first[0] : '';
    final last = parts.length > 1 && parts.last.isNotEmpty ? parts.last[0] : '';
    return '$first$last'.toUpperCase();
  }
}

class _RecipesHubTab extends StatelessWidget {
  const _RecipesHubTab({
    required this.recipeProvider,
    required this.onRetryRecipes,
    required this.onBrowseAllRecipes,
    required this.onOpenFavorites,
    required this.onAddRecipe,
  });

  final RecipeProvider recipeProvider;
  final Future<void> Function() onRetryRecipes;
  final VoidCallback onBrowseAllRecipes;
  final VoidCallback onOpenFavorites;
  final VoidCallback onAddRecipe;

  @override
  Widget build(BuildContext context) {
    final recipes = recipeProvider.recipes;
    final favorites = recipes
        .where((Recipe recipe) => recipe.isFavorite)
        .toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        if (recipeProvider.status == RecipeProviderStatus.error) ...<Widget>[
          _SyncStatusCard(
            icon: Icons.warning_amber_outlined,
            title: 'Recipes could not be refreshed',
            description:
                recipeProvider.errorMessage ??
                'The recipes workspace is temporarily out of sync.',
            actionLabel: 'Retry recipes',
            onAction: onRetryRecipes,
          ),
          const SizedBox(height: 16),
        ] else if (recipeProvider.status == RecipeProviderStatus.loading &&
            recipes.isEmpty) ...<Widget>[
          const _SyncStatusCard(
            icon: Icons.sync,
            title: 'Syncing recipes workspace',
            description:
                'Loading your saved recipes and favorites for quick access.',
          ),
          const SizedBox(height: 16),
        ],
        _SectionCard(
          title: 'Recipes Workspace',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Your recipes module is ready. Use it as the source for the meal-planning and shopping flows that come next.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: <Widget>[
                  _PrimaryActionCard(
                    label: 'All Recipes',
                    detail: '${recipes.length} saved',
                    icon: Icons.menu_book_outlined,
                    onTap: onBrowseAllRecipes,
                  ),
                  _PrimaryActionCard(
                    label: 'Favorites',
                    detail: '${favorites.length} starred',
                    icon: Icons.star_outline,
                    onTap: onOpenFavorites,
                  ),
                  _PrimaryActionCard(
                    label: 'Add Recipe',
                    detail: 'Create a new dish',
                    icon: Icons.add_circle_outline,
                    onTap: onAddRecipe,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Favorite Picks',
          child: favorites.isEmpty
              ? const _InfoState(
                  icon: Icons.star_outline,
                  title: 'No favorites yet',
                  description:
                      'Star the recipes you want to reach quickly during meal planning.',
                )
              : Column(
                  children: <Widget>[
                    for (final Recipe recipe in favorites.take(3)) ...<Widget>[
                      _RecentRecipeTile(recipe: recipe),
                      if (recipe != favorites.take(3).last)
                        const Divider(height: 20),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _DashboardHero extends StatelessWidget {
  const _DashboardHero({
    required this.greeting,
    required this.initials,
    required this.recipeCount,
    required this.favoriteCount,
    required this.plannedMealCount,
  });

  final String greeting;
  final String initials;
  final int recipeCount;
  final int favoriteCount;
  final int plannedMealCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 26),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[AppColors.primary, AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.22),
            blurRadius: 26,
            offset: const Offset(0, 16),
          ),
        ],
      ),
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
                      greeting,
                      style: Theme.of(
                        context,
                      ).textTheme.headlineSmall?.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Manage recipes, plan your week, and keep your shopping list ready before the next grocery run.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFFE6F5EC),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.white.withValues(alpha: 0.18),
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: <Widget>[
              Expanded(
                child: _HeroStatCard(
                  label: 'Recipes',
                  value: recipeCount.toString(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HeroStatCard(
                  label: 'Favorites',
                  value: favoriteCount.toString(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HeroStatCard(
                  label: 'This week',
                  value: plannedMealCount.toString(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AppSectionTitle(title),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _SyncStatusCard extends StatelessWidget {
  const _SyncStatusCard({
    required this.icon,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String description;
  final String? actionLabel;
  final Future<void> Function()? onAction;

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      backgroundColor: AppColors.surfaceTint,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (actionLabel != null && onAction != null) ...<Widget>[
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: () => unawaited(onAction!()),
                    icon: const Icon(Icons.refresh),
                    label: Text(actionLabel!),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    this.helperText,
  });

  final String label;
  final String value;
  final IconData icon;
  final String? helperText;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceTint,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(height: 12),
          Text(value, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(label, style: Theme.of(context).textTheme.titleSmall),
          if (helperText != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(helperText!, style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}

class _QuickActionChip extends StatelessWidget {
  const _QuickActionChip({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onPressed,
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceTint,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(label),
          ],
        ),
      ),
    );
  }
}

class _PrimaryActionCard extends StatelessWidget {
  const _PrimaryActionCard({
    required this.label,
    required this.detail,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String detail;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 170,
      child: AppPanel(
        backgroundColor: AppColors.surfaceTint,
        padding: EdgeInsets.zero,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: AppColors.primary),
                ),
                const SizedBox(height: 12),
                Text(label, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(detail, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RecentRecipeTile extends StatelessWidget {
  const _RecentRecipeTile({required this.recipe});

  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    final imageUrl = recipe.imageUrl ?? '';

    return Row(
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            width: 68,
            height: 68,
            child: imageUrl.isEmpty
                ? const DecoratedBox(
                    decoration: BoxDecoration(color: AppColors.primarySoft),
                    child: Icon(
                      Icons.restaurant_menu,
                      color: AppColors.primary,
                    ),
                  )
                : Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const DecoratedBox(
                      decoration: BoxDecoration(color: AppColors.primarySoft),
                      child: Icon(
                        Icons.restaurant_menu,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                recipe.title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                recipe.category.label,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              Text(
                '${recipe.ingredients.length} ingredients • ${recipe.steps.length} steps',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        if (recipe.isFavorite)
          const Icon(Icons.star, color: AppColors.primary, size: 20),
      ],
    );
  }
}

class _HeroStatCard extends StatelessWidget {
  const _HeroStatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: const Color(0xFFD9F0E1)),
          ),
        ],
      ),
    );
  }
}

class _InfoState extends StatelessWidget {
  const _InfoState({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(icon, size: 30, color: AppColors.primary),
        ),
        const SizedBox(height: 12),
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        Text(
          description,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}
