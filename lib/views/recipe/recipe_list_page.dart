import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/recipe.dart';
import '../../models/recipe_category.dart';
import '../../providers/auth_provider.dart';
import '../../providers/recipe_provider.dart';
import 'add_recipe_page.dart';
import 'recipe_detail_page.dart';

const String recipeListRoute = '/recipes';

class RecipeListPage extends StatefulWidget {
  const RecipeListPage({super.key});

  @override
  State<RecipeListPage> createState() => _RecipeListPageState();
}

class _RecipeListPageState extends State<RecipeListPage> {
  String? _lastSyncedUid;

  @override
  Widget build(BuildContext context) {
    _syncRecipeWatcher(context);

    final recipeProvider = context.watch<RecipeProvider>();
    final recipes = recipeProvider.recipes;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Recipes'),
        actions: [
          PopupMenuButton<RecipeCategory?>(
            tooltip: 'Filter category',
            icon: const Icon(Icons.filter_list),
            onSelected: (category) =>
                recipeProvider.setCategoryFilter(category),
            itemBuilder: (context) => <PopupMenuEntry<RecipeCategory?>>[
              const PopupMenuItem<RecipeCategory?>(
                value: null,
                child: Text('All categories'),
              ),
              ...RecipeCategory.values.map(
                (category) => PopupMenuItem<RecipeCategory?>(
                  value: category,
                  child: Text(category.label),
                ),
              ),
            ],
          ),
          IconButton(
            tooltip: recipeProvider.favoritesOnly
                ? 'Show all recipes'
                : 'Show favorites only',
            onPressed: () =>
                recipeProvider.setFavoritesOnly(!recipeProvider.favoritesOnly),
            icon: Icon(
              recipeProvider.favoritesOnly ? Icons.star : Icons.star_border,
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: recipeProvider.refresh,
        child: Container(
          color: colorScheme.surface,
          child: Builder(
            builder: (context) {
              if (recipeProvider.status == RecipeProviderStatus.loading &&
                  recipes.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }

              if (recipeProvider.status == RecipeProviderStatus.error &&
                  recipes.isEmpty) {
                return _ErrorState(
                  message:
                      recipeProvider.errorMessage ??
                      'Unable to load recipes right now.',
                  onRetry: recipeProvider.refresh,
                );
              }

              if (recipes.isEmpty) {
                return _EmptyState(onAddPressed: () => _openAddRecipe(context));
              }

              return ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: recipes.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final recipe = recipes[index];
                  return _RecipeCard(
                    recipe: recipe,
                    onTap: () => _openRecipeDetail(context, recipe.id),
                    onFavoriteToggle: () {
                      unawaited(
                        recipeProvider.toggleFavorite(
                          recipeId: recipe.id,
                          isFavorite: !recipe.isFavorite,
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddRecipe(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Recipe'),
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

  Future<void> _openAddRecipe(BuildContext context) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const AddRecipePage()));
  }

  Future<void> _openRecipeDetail(BuildContext context, String recipeId) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RecipeDetailPage(recipeId: recipeId),
      ),
    );
  }
}

class _RecipeCard extends StatelessWidget {
  const _RecipeCard({
    required this.recipe,
    required this.onTap,
    required this.onFavoriteToggle,
  });

  final Recipe recipe;
  final VoidCallback onTap;
  final VoidCallback onFavoriteToggle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
      child: ListTile(
        onTap: onTap,
        title: Text(recipe.title),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(
                label: Text(recipe.category.label),
                visualDensity: VisualDensity.compact,
              ),
              Chip(
                label: Text('${recipe.ingredients.length} ingredients'),
                visualDensity: VisualDensity.compact,
              ),
              Chip(
                label: Text('${recipe.steps.length} steps'),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
        trailing: IconButton(
          onPressed: onFavoriteToggle,
          icon: Icon(recipe.isFavorite ? Icons.star : Icons.star_border),
          color: recipe.isFavorite ? colorScheme.primary : null,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAddPressed});

  final VoidCallback onAddPressed;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 60),
        Icon(
          Icons.menu_book_outlined,
          size: 72,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 16),
        Text(
          'No recipes yet',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          'Create your first recipe to start building your meal workflow.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: onAddPressed,
          icon: const Icon(Icons.add),
          label: const Text('Create Recipe'),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 60),
        Icon(
          Icons.error_outline,
          size: 64,
          color: Theme.of(context).colorScheme.error,
        ),
        const SizedBox(height: 16),
        Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 18),
        FilledButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    );
  }
}
