import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_user.dart';
import '../../models/recipe.dart';
import '../../providers/auth_provider.dart';
import '../../providers/meal_plan_provider.dart';
import '../../providers/recipe_provider.dart';
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
  String? _lastSyncedUid;

  static const List<String> _titles = <String>[
    'Home',
    'Recipes',
    'Meal Plan',
    'Shopping List',
  ];

  @override
  Widget build(BuildContext context) {
    _syncRecipeWatcher(context);

    final authProvider = context.watch<AuthProvider>();
    final mealPlanProvider = context.watch<MealPlanProvider>();
    final recipeProvider = context.watch<RecipeProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
        actions: [
          IconButton(
            onPressed: authProvider.isLoading ? null : _signOut,
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _HomeTab(
            user: authProvider.currentUser,
            mealPlanProvider: mealPlanProvider,
            recipeProvider: recipeProvider,
            onOpenRecipes: () => setState(() => _selectedIndex = 1),
            onOpenFavorites: () => Navigator.of(
              context,
            ).pushNamed(favoriteRecipesRoute),
            onOpenMealPlan: () => setState(() => _selectedIndex = 2),
            onOpenShoppingList: () => setState(() => _selectedIndex = 3),
          ),
          _RecipesHubTab(
            recipeProvider: recipeProvider,
            onBrowseAllRecipes: () =>
                Navigator.of(context).pushNamed(recipeListRoute),
            onOpenFavorites: () => Navigator.of(
              context,
            ).pushNamed(favoriteRecipesRoute),
            onAddRecipe: () => Navigator.of(context).pushNamed(addRecipeRoute),
          ),
          const MealPlanPage(),
          const ShoppingListPage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: const [
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

  void _syncRecipeWatcher(BuildContext context) {
    final uid = context.read<AuthProvider>().currentUser?.uid;
    if (uid == null || uid == _lastSyncedUid) {
      return;
    }

    _lastSyncedUid = uid;
    unawaited(context.read<RecipeProvider>().startWatching(uid: uid));
  }

  Future<void> _signOut() async {
    final recipeProvider = context.read<RecipeProvider>();
    final mealPlanProvider = context.read<MealPlanProvider>();
    final authProvider = context.read<AuthProvider>();

    await recipeProvider.stopWatching();
    await mealPlanProvider.stopWatching();
    await authProvider.signOut();
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab({
    required this.user,
    required this.mealPlanProvider,
    required this.recipeProvider,
    required this.onOpenRecipes,
    required this.onOpenFavorites,
    required this.onOpenMealPlan,
    required this.onOpenShoppingList,
  });

  final AppUser? user;
  final MealPlanProvider mealPlanProvider;
  final RecipeProvider recipeProvider;
  final VoidCallback onOpenRecipes;
  final VoidCallback onOpenFavorites;
  final VoidCallback onOpenMealPlan;
  final VoidCallback onOpenShoppingList;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final recipes = recipeProvider.recipes;
    final favoriteCount = recipes.where((recipe) => recipe.isFavorite).length;
    final recentRecipes = recipes.take(3).toList();
    final greeting = _buildGreeting(user);
    final plannedMealCount = mealPlanProvider.plannedMealCount;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            colorScheme.primaryContainer.withValues(alpha: 0.42),
            colorScheme.surface,
          ],
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(greeting, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'Manage recipes, plan your week, and generate your next shopping list from one place.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Recipes',
                  value: recipes.length.toString(),
                  icon: Icons.menu_book_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  label: 'Favorites',
                  value: favoriteCount.toString(),
                  icon: Icons.star_outline,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Meals Planned',
                  value: plannedMealCount.toString(),
                  icon: Icons.calendar_today_outlined,
                  helperText: plannedMealCount == 0
                      ? 'Current week'
                      : 'This week',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  label: 'Shopping Items',
                  value: '0',
                  icon: Icons.shopping_basket_outlined,
                  helperText: 'After planning',
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _SectionCard(
            title: 'Quick Actions',
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
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
                    children: [
                      for (final recipe in recentRecipes) ...[
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
}

class _RecipesHubTab extends StatelessWidget {
  const _RecipesHubTab({
    required this.recipeProvider,
    required this.onBrowseAllRecipes,
    required this.onOpenFavorites,
    required this.onAddRecipe,
  });

  final RecipeProvider recipeProvider;
  final VoidCallback onBrowseAllRecipes;
  final VoidCallback onOpenFavorites;
  final VoidCallback onAddRecipe;

  @override
  Widget build(BuildContext context) {
    final recipes = recipeProvider.recipes;
    final favorites = recipes.where((recipe) => recipe.isFavorite).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionCard(
          title: 'Recipes Workspace',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your recipes module is ready. Use it as the source for the meal-planning and shopping flows that come next.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
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
                  children: [
                    for (final recipe in favorites.take(3)) ...[
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

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

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
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            child,
          ],
        ),
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
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.72),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: colorScheme.primary),
            const SizedBox(height: 12),
            Text(value, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(label, style: Theme.of(context).textTheme.titleSmall),
            if (helperText != null) ...[
              const SizedBox(height: 4),
              Text(
                helperText!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
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
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onPressed,
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
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: 170,
      child: Card(
        elevation: 0,
        color: colorScheme.primaryContainer.withValues(alpha: 0.55),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: colorScheme.primary),
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
    final colorScheme = Theme.of(context).colorScheme;
    final imageUrl = recipe.imageUrl ?? '';

    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 68,
            height: 68,
            child: imageUrl.isEmpty
                ? DecoratedBox(
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                    ),
                    child: Icon(
                      Icons.restaurant_menu,
                      color: colorScheme.primary,
                    ),
                  )
                : Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => DecoratedBox(
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                      ),
                      child: Icon(
                        Icons.restaurant_menu,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(recipe.title, style: Theme.of(context).textTheme.titleMedium),
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
          Icon(Icons.star, color: colorScheme.primary, size: 20),
      ],
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
      children: [
        Icon(icon, size: 44),
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
