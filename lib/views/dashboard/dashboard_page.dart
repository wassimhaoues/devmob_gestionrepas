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

    return AppScaffold(
      title: _titles[_selectedIndex],
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
      bottomNavigationBar: _FloatingNavBar(
        selectedIndex: _selectedIndex,
        onItemTapped: (int index) => setState(() => _selectedIndex = index),
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

    return ListView(
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
        ] else if (mealPlanProvider.status == MealPlanProviderStatus.loading &&
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
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
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
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Quick Actions',
          child: Column(
            children: <Widget>[
              _QuickActionChip(
                label: 'Browse Recipes',
                icon: Icons.menu_book_outlined,
                onPressed: onOpenRecipes,
              ),
              const SizedBox(height: 10),
              _QuickActionChip(
                label: 'Favorite Recipes',
                icon: Icons.star_outline,
                onPressed: onOpenFavorites,
              ),
              const SizedBox(height: 10),
              _QuickActionChip(
                label: 'Meal Plan',
                icon: Icons.calendar_month_outlined,
                onPressed: onOpenMealPlan,
              ),
              const SizedBox(height: 10),
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
              Column(
                children: <Widget>[
                  _PrimaryActionCard(
                    label: 'All Recipes',
                    detail: '${recipes.length} saved',
                    icon: Icons.menu_book_outlined,
                    onTap: onBrowseAllRecipes,
                  ),
                  const SizedBox(height: 10),
                  _PrimaryActionCard(
                    label: 'Favorites',
                    detail: '${favorites.length} starred',
                    icon: Icons.star_outline,
                    onTap: onOpenFavorites,
                  ),
                  const SizedBox(height: 10),
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
        gradient: AppGradients.brand,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        boxShadow: AppShadows.hero(AppColors.primary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 360;
              final avatar = CircleAvatar(
                radius: 24,
                backgroundColor: Colors.white.withValues(alpha: 0.18),
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              );
              if (stacked) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    avatar,
                    const SizedBox(height: 14),
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
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          greeting,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(color: Colors.white),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Manage recipes, plan your week, and keep your shopping list ready before the next grocery run.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: const Color(0xFFE6F5EC)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  avatar,
                ],
              );
            },
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
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(width: 14),
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
    return AppStatTile(
      label: label,
      value: value,
      icon: icon,
      helperText: helperText,
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
      borderRadius: BorderRadius.circular(AppRadii.md),
      onTap: onPressed,
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(color: AppColors.border),
          boxShadow: AppShadows.card,
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(AppRadii.sm - 4),
              ),
              child: Icon(icon, size: 18, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.heading,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: AppColors.muted,
              size: 18,
            ),
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
    return AppActionTile(
      label: label,
      detail: detail,
      icon: icon,
      onTap: onTap,
      width: double.infinity,
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
        AppImageFrame(
          imageUrl: imageUrl,
          semanticLabel: '${recipe.title} recipe image',
          width: 68,
          height: 68,
          radius: AppRadii.md,
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.82),
              letterSpacing: 0.2,
            ),
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
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[AppColors.primarySoft, AppColors.surfaceTint],
            ),
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.14),
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Icon(icon, size: 34, color: AppColors.primary),
        ),
        const SizedBox(height: 14),
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

class _FloatingNavBar extends StatelessWidget {
  const _FloatingNavBar({
    required this.selectedIndex,
    required this.onItemTapped,
  });

  final int selectedIndex;
  final ValueChanged<int> onItemTapped;

  static const List<(IconData, IconData, String)> _destinations = <(
    IconData,
    IconData,
    String,
  )>[
    (Icons.home_rounded, Icons.home_outlined, 'Home'),
    (Icons.menu_book_rounded, Icons.menu_book_outlined, 'Recipes'),
    (Icons.calendar_month_rounded, Icons.calendar_month_outlined, 'Plan'),
    (Icons.shopping_cart_rounded, Icons.shopping_cart_outlined, 'Shopping'),
  ];

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Container(
      margin: EdgeInsets.fromLTRB(20, 8, 20, 12 + bottomPadding),
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppColors.border),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 32,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          for (int i = 0; i < _destinations.length; i++)
            Expanded(
              child: _NavBarItem(
                filledIcon: _destinations[i].$1,
                outlinedIcon: _destinations[i].$2,
                label: _destinations[i].$3,
                isSelected: i == selectedIndex,
                onTap: () => onItemTapped(i),
              ),
            ),
        ],
      ),
    );
  }
}

class _NavBarItem extends StatelessWidget {
  const _NavBarItem({
    required this.filledIcon,
    required this.outlinedIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData filledIcon;
  final IconData outlinedIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primarySoft : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              isSelected ? filledIcon : outlinedIcon,
              color: isSelected ? AppColors.primary : AppColors.muted,
              size: 22,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? AppColors.primary : AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
