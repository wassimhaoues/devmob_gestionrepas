import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/recipe.dart';
import '../../models/recipe_category.dart';
import '../../providers/auth_provider.dart';
import '../../providers/recipe_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_panels.dart';
import 'add_recipe_page.dart';
import 'recipe_detail_page.dart';

const String recipeListRoute = '/recipes';
const String favoriteRecipesRoute = '/recipes/favorites';

class RecipeListPage extends StatefulWidget {
  const RecipeListPage({
    super.key,
    this.pageTitle = 'My Recipes',
    this.favoritesOnlyView = false,
  });

  final String pageTitle;
  final bool favoritesOnlyView;

  @override
  State<RecipeListPage> createState() => _RecipeListPageState();
}

class _RecipeListPageState extends State<RecipeListPage> {
  String? _lastSyncedUid;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    _syncRecipeWatcher(context);

    final recipeProvider = context.watch<RecipeProvider>();
    final sourceRecipes = widget.favoritesOnlyView
        ? recipeProvider.recipes
              .where((Recipe recipe) => recipe.isFavorite)
              .toList()
        : recipeProvider.recipes;
    final recipes = sourceRecipes.where((Recipe recipe) {
      if (_query.trim().isEmpty) {
        return true;
      }
      final query = _query.trim().toLowerCase();
      return recipe.title.toLowerCase().contains(query) ||
          recipe.description.toLowerCase().contains(query) ||
          recipe.category.label.toLowerCase().contains(query);
    }).toList();

    return AppScaffold(
      useAppBar: false,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddRecipe(context),
        icon: const Icon(Icons.add),
        label: const Text('Add recipe'),
      ),
      body: RefreshIndicator(
        onRefresh: recipeProvider.refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
          children: <Widget>[
            _RecipesHeader(
              pageTitle: widget.pageTitle,
              recipeCount: sourceRecipes.length,
              favoritesOnlyView: widget.favoritesOnlyView,
              onAddPressed: () => _openAddRecipe(context),
              onBack: Navigator.of(context).canPop()
                  ? () => Navigator.of(context).maybePop()
                  : null,
            ),
            const SizedBox(height: 16),
            _SearchField(
              value: _query,
              onChanged: (String value) => setState(() => _query = value),
            ),
            const SizedBox(height: 12),
            _FilterBar(
              activeCategory: recipeProvider.activeCategory,
              favoritesOnly: recipeProvider.favoritesOnly,
              favoritesOnlyView: widget.favoritesOnlyView,
              onCategorySelected: recipeProvider.setCategoryFilter,
              onFavoritesToggle: widget.favoritesOnlyView
                  ? null
                  : () => recipeProvider.setFavoritesOnly(
                      !recipeProvider.favoritesOnly,
                    ),
            ),
            if (recipeProvider.status == RecipeProviderStatus.loading &&
                sourceRecipes.isEmpty) ...<Widget>[
              const SizedBox(height: 20),
              const AppLoadingState(
                message: 'Loading your recipes...',
                icon: Icons.menu_book_outlined,
              ),
            ] else if (recipeProvider.status == RecipeProviderStatus.error &&
                sourceRecipes.isEmpty) ...<Widget>[
              const SizedBox(height: 20),
              _ErrorState(
                message:
                    recipeProvider.errorMessage ??
                    'Unable to load recipes right now.',
                onRetry: recipeProvider.refresh,
              ),
            ] else if (recipes.isEmpty) ...<Widget>[
              const SizedBox(height: 20),
              _EmptyState(
                onAddPressed: () => _openAddRecipe(context),
                favoritesOnlyView: widget.favoritesOnlyView,
                hasSearchQuery: _query.trim().isNotEmpty,
                onBrowseAllPressed: widget.favoritesOnlyView
                    ? () => Navigator.of(
                        context,
                      ).pushReplacementNamed(recipeListRoute)
                    : null,
                onClearSearch: _query.trim().isEmpty
                    ? null
                    : () => setState(() => _query = ''),
              ),
            ] else ...<Widget>[
              const SizedBox(height: 16),
              ...List<Widget>.generate(recipes.length, (int index) {
                final recipe = recipes[index];
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index == recipes.length - 1 ? 0 : 12,
                  ),
                  child: _RecipeCard(
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
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  void _syncRecipeWatcher(BuildContext context) {
    final uid = context.read<AuthProvider>().currentUser?.uid;
    if (uid == null || uid == _lastSyncedUid) {
      return;
    }

    _lastSyncedUid = uid;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(context.read<RecipeProvider>().startWatching(uid: uid));
    });
  }

  Future<void> _openAddRecipe(BuildContext context) async {
    await Navigator.of(context).pushNamed(addRecipeRoute);
  }

  Future<void> _openRecipeDetail(BuildContext context, String recipeId) async {
    await Navigator.of(
      context,
    ).pushNamed(recipeDetailRoute, arguments: recipeId);
  }
}

class _RecipesHeader extends StatelessWidget {
  const _RecipesHeader({
    required this.pageTitle,
    required this.recipeCount,
    required this.favoritesOnlyView,
    required this.onAddPressed,
    this.onBack,
  });

  final String pageTitle;
  final int recipeCount;
  final bool favoritesOnlyView;
  final VoidCallback onAddPressed;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
      decoration: BoxDecoration(
        gradient: AppGradients.brand,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        boxShadow: AppShadows.hero(AppColors.primary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              if (onBack != null) ...<Widget>[
                Material(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                  child: InkWell(
                    onTap: onBack,
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text(
                  pageTitle,
                  style: Theme.of(
                    context,
                  ).textTheme.headlineSmall?.copyWith(color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            favoritesOnlyView
                ? '$recipeCount favorite recipes ready for quick planning.'
                : '$recipeCount recipes saved and ready for meal planning.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: const Color(0xFFE4F4EA)),
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final metric = _HeroMetric(
                label: favoritesOnlyView ? 'Favorites' : 'Recipes',
                value: recipeCount.toString(),
              );
              final button = OutlinedButton.icon(
                onPressed: onAddPressed,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.35)),
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                ),
                icon: const Icon(Icons.add),
                label: const Text('New recipe'),
              );
              if (constraints.maxWidth < 380) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    metric,
                    const SizedBox(height: 12),
                    button,
                  ],
                );
              }
              return Row(
                children: <Widget>[
                  Expanded(child: metric),
                  const SizedBox(width: 12),
                  Expanded(child: button),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({required this.label, required this.value});

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

class _SearchField extends StatelessWidget {
  const _SearchField({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: value,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: 'Search recipes',
        hintText: 'Title, description, or category',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: value.isEmpty
            ? null
            : IconButton(
                onPressed: () => onChanged(''),
                icon: const Icon(Icons.close),
              ),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.activeCategory,
    required this.favoritesOnly,
    required this.favoritesOnlyView,
    required this.onCategorySelected,
    required this.onFavoritesToggle,
  });

  final RecipeCategory? activeCategory;
  final bool favoritesOnly;
  final bool favoritesOnlyView;
  final Future<void> Function(RecipeCategory? category) onCategorySelected;
  final Future<void> Function()? onFavoritesToggle;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          FilterChip(
            label: const Text('All'),
            selected: activeCategory == null,
            onSelected: (_) => unawaited(onCategorySelected(null)),
          ),
          const SizedBox(width: 8),
          ...RecipeCategory.values.map((RecipeCategory category) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(category.label),
                selected: activeCategory == category,
                onSelected: (_) => unawaited(onCategorySelected(category)),
              ),
            );
          }),
          if (!favoritesOnlyView)
            FilterChip(
              label: const Text('Favorites'),
              selected: favoritesOnly,
              onSelected: (_) => unawaited(onFavoritesToggle?.call()),
            ),
        ],
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
    return AppPanel(
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Stack(
              children: <Widget>[
                _RecipeThumbnail(
                  imageUrl: recipe.imageUrl,
                  title: recipe.title,
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Material(
                    color: Colors.white.withValues(alpha: 0.92),
                    shape: const CircleBorder(),
                    child: IconButton(
                      onPressed: onFavoriteToggle,
                      tooltip: recipe.isFavorite ? 'Unfavorite' : 'Favorite',
                      icon: Icon(
                        recipe.isFavorite ? Icons.star : Icons.star_border,
                        color: recipe.isFavorite
                            ? AppColors.pink
                            : AppColors.muted,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    recipe.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (recipe.description.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      recipe.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      _RecipeMetaChip(
                        label: recipe.category.label,
                        color: _categoryAccent(recipe.category),
                      ),
                      _RecipeMetaChip(
                        label: '${recipe.ingredients.length} ingredients',
                        color: AppColors.amber,
                      ),
                      _RecipeMetaChip(
                        label: '${recipe.steps.length} steps',
                        color: AppColors.indigo,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecipeMetaChip extends StatelessWidget {
  const _RecipeMetaChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AppStatusChip(label: label, color: color);
  }
}

class _RecipeThumbnail extends StatelessWidget {
  const _RecipeThumbnail({required this.imageUrl, required this.title});

  final String? imageUrl;
  final String title;

  @override
  Widget build(BuildContext context) {
    return AppImageFrame(
      imageUrl: imageUrl,
      semanticLabel: '$title recipe image',
      aspectRatio: 16 / 9,
      radius: 24,
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.onAddPressed,
    required this.favoritesOnlyView,
    required this.hasSearchQuery,
    this.onBrowseAllPressed,
    this.onClearSearch,
  });

  final VoidCallback onAddPressed;
  final bool favoritesOnlyView;
  final bool hasSearchQuery;
  final VoidCallback? onBrowseAllPressed;
  final VoidCallback? onClearSearch;

  @override
  Widget build(BuildContext context) {
    final title = hasSearchQuery
        ? 'No recipes match your search'
        : favoritesOnlyView
        ? 'No favorite recipes yet'
        : 'No recipes yet';
    final description = hasSearchQuery
        ? 'Try a different keyword or clear the search field.'
        : favoritesOnlyView
        ? 'Star a recipe to keep it close at hand here.'
        : 'Create your first recipe to start building your meal workflow.';

    return AppMessageState(
      icon: hasSearchQuery
          ? Icons.search_off_rounded
          : Icons.menu_book_outlined,
      title: title,
      description: description,
      actionLabel: hasSearchQuery && onClearSearch != null
          ? 'Clear search'
          : !favoritesOnlyView
          ? 'Create recipe'
          : onBrowseAllPressed != null
          ? 'Browse all recipes'
          : null,
      onAction: hasSearchQuery && onClearSearch != null
          ? onClearSearch
          : !favoritesOnlyView
          ? onAddPressed
          : onBrowseAllPressed,
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return AppErrorState(message: message, onRetry: onRetry);
  }
}

Color _categoryAccent(RecipeCategory category) {
  switch (category) {
    case RecipeCategory.breakfast:
      return const Color(0xFFD97706);
    case RecipeCategory.lunch:
      return AppColors.primary;
    case RecipeCategory.dinner:
      return AppColors.indigo;
    case RecipeCategory.dessert:
      return AppColors.pink;
  }
}
