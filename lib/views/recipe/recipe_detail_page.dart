import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/recipe.dart';
import '../../providers/recipe_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_panels.dart';
import 'edit_recipe_page.dart';

const String recipeDetailRoute = '/recipes/detail';

class RecipeDetailPage extends StatefulWidget {
  const RecipeDetailPage({super.key, this.recipeId});

  final String? recipeId;

  @override
  State<RecipeDetailPage> createState() => _RecipeDetailPageState();
}

class _RecipeDetailPageState extends State<RecipeDetailPage> {
  String? _resolvedId;
  bool _didScheduleLoad = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didScheduleLoad) {
      return;
    }

    _resolvedId = _resolveRecipeId(context);
    _didScheduleLoad = true;
    final recipeId = _resolvedId;
    if (recipeId == null) {
      return;
    }

    final provider = context.read<RecipeProvider>();
    if (provider.recipeById(recipeId) != null) {
      provider.loadRecipeById(recipeId);
      return;
    }

    unawaited(provider.loadRecipeById(recipeId));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RecipeProvider>();
    final resolvedId = _resolvedId ?? _resolveRecipeId(context);
    final recipe = resolvedId == null ? null : provider.recipeById(resolvedId);

    if (resolvedId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Recipe detail')),
        body: const Center(child: Text('Recipe id is missing.')),
      );
    }

    if (recipe == null && provider.isLoading) {
      return const Scaffold(body: _RecipeLoadingState());
    }

    if (recipe == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Recipe detail')),
        body: _MissingRecipeState(
          message: provider.errorMessage ?? 'Recipe not found.',
          onRetry: () =>
              provider.loadRecipeById(resolvedId, forceRefresh: true),
        ),
      );
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: <Widget>[
          _RecipeHeroSliver(
            recipe: recipe,
            onBack: () => Navigator.of(context).maybePop(),
            onEdit: () => _openEditPage(context, recipe.id),
            onFavoriteToggle: () => provider.toggleFavorite(
              recipeId: recipe.id,
              isFavorite: !recipe.isFavorite,
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Column(
                children: <Widget>[
                  Transform.translate(
                    offset: const Offset(0, -24),
                    child: _RecipeSummaryHeader(recipe: recipe),
                  ),
                  _RecipeSection(
                    title: 'Ingredients',
                    child: Column(
                      children: recipe.ingredients
                          .map(
                            (ingredient) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _IngredientRow(
                                label: ingredient.displayName,
                                quantity:
                                    '${ingredient.quantity} ${ingredient.unit}',
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _RecipeSection(
                    title: 'Preparation',
                    child: Column(
                      children: recipe.steps
                          .map(
                            (step) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _StepRow(step: step),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  if ((recipe.imageMimeType ?? '').isNotEmpty ||
                      recipe.imageSizeBytes != null) ...<Widget>[
                    const SizedBox(height: 14),
                    _RecipeSection(
                      title: 'Photo details',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          if ((recipe.imageMimeType ?? '').isNotEmpty)
                            Text('Format: ${recipe.imageMimeType}'),
                          if (recipe.imageSizeBytes != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                'Size: ${_formatBytes(recipe.imageSizeBytes!)}',
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  OutlinedButton.icon(
                    onPressed: () => _confirmDelete(context, recipe.id),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete recipe'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? _resolveRecipeId(BuildContext context) {
    final routeArgs = ModalRoute.of(context)?.settings.arguments;
    if (routeArgs is String && routeArgs.trim().isNotEmpty) {
      return routeArgs.trim();
    }
    if (widget.recipeId != null && widget.recipeId!.trim().isNotEmpty) {
      return widget.recipeId!.trim();
    }
    return null;
  }

  Future<void> _openEditPage(BuildContext context, String id) async {
    await Navigator.of(context).pushNamed(editRecipeRoute, arguments: id);
  }

  Future<void> _confirmDelete(BuildContext context, String id) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Delete recipe?'),
          content: const Text(
            'This action removes the recipe permanently from your account.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true || !context.mounted) {
      return;
    }

    final success = await context.read<RecipeProvider>().deleteRecipe(id);
    if (!context.mounted) {
      return;
    }

    if (success) {
      Navigator.of(context).pop();
      return;
    }

    final errorMessage =
        context.read<RecipeProvider>().errorMessage ??
        'Failed to delete recipe.';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(errorMessage)));
  }
}

class _RecipeHeroSliver extends StatelessWidget {
  const _RecipeHeroSliver({
    required this.recipe,
    required this.onBack,
    required this.onEdit,
    required this.onFavoriteToggle,
  });

  final Recipe recipe;
  final VoidCallback onBack;
  final VoidCallback onEdit;
  final VoidCallback onFavoriteToggle;

  @override
  Widget build(BuildContext context) {
    final hasImage = (recipe.imageUrl ?? '').isNotEmpty;

    return SliverAppBar(
      expandedHeight: 300,
      pinned: true,
      stretch: true,
      backgroundColor: AppColors.primaryDark,
      leading: _HeroIconButton(
        icon: Icons.arrow_back,
        tooltip: 'Back',
        onPressed: onBack,
      ),
      actions: <Widget>[
        _HeroIconButton(
          icon: Icons.edit_outlined,
          tooltip: 'Edit recipe',
          onPressed: onEdit,
        ),
        _HeroIconButton(
          icon: recipe.isFavorite ? Icons.star : Icons.star_border,
          tooltip: recipe.isFavorite ? 'Unfavorite' : 'Favorite',
          onPressed: onFavoriteToggle,
        ),
        const SizedBox(width: 8),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (hasImage)
              Image.network(
                recipe.imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _HeroFallback(recipe: recipe),
              )
            else
              _HeroFallback(recipe: recipe),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Color(0x33000000),
                    Color(0x14000000),
                    Color(0xA614241B),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroFallback extends StatelessWidget {
  const _HeroFallback({required this.recipe});

  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[AppColors.primary, AppColors.primaryDark],
        ),
      ),
      child: Center(
        child: Icon(
          recipe.isFavorite ? Icons.star_rounded : Icons.restaurant_menu,
          color: Colors.white.withValues(alpha: 0.9),
          size: 56,
        ),
      ),
    );
  }
}

class _HeroIconButton extends StatelessWidget {
  const _HeroIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Material(
        color: Colors.white.withValues(alpha: 0.88),
        shape: const CircleBorder(),
        child: IconButton(
          tooltip: tooltip,
          onPressed: onPressed,
          icon: Icon(icon, color: AppColors.heading),
        ),
      ),
    );
  }
}

class _RecipeSummaryHeader extends StatelessWidget {
  const _RecipeSummaryHeader({required this.recipe});

  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _MetaBadge(
                label: recipe.category.label,
                color: _categoryAccent(recipe),
              ),
              _MetaBadge(
                label: recipe.isFavorite ? 'Favorite' : 'Recipe',
                color: recipe.isFavorite ? AppColors.pink : AppColors.primary,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(recipe.title, style: Theme.of(context).textTheme.headlineSmall),
          if (recipe.description.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              recipe.description,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final stats = <Widget>[
                _StatTile(
                  label: 'Ingredients',
                  value: recipe.ingredients.length.toString(),
                  icon: Icons.shopping_basket_outlined,
                  color: AppColors.amber,
                ),
                _StatTile(
                  label: 'Steps',
                  value: recipe.steps.length.toString(),
                  icon: Icons.format_list_numbered_rounded,
                  color: AppColors.indigo,
                ),
              ];
              if (constraints.maxWidth < 360) {
                return Column(
                  children: <Widget>[
                    stats[0],
                    const SizedBox(height: 10),
                    stats[1],
                  ],
                );
              }
              return Row(
                children: <Widget>[
                  Expanded(child: stats[0]),
                  const SizedBox(width: 10),
                  Expanded(child: stats[1]),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MetaBadge extends StatelessWidget {
  const _MetaBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

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
          Icon(icon, color: color),
          const SizedBox(height: 10),
          Text(value, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 2),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _RecipeSection extends StatelessWidget {
  const _RecipeSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AppSectionTitle(title),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _IngredientRow extends StatelessWidget {
  const _IngredientRow({required this.label, required this.quantity});

  final String label;
  final String quantity;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceTint,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 8,
        children: <Widget>[
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 120, maxWidth: 220),
            child: Text(label),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              quantity,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.step});

  final dynamic step;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceTint,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(999),
            ),
            alignment: Alignment.center,
            child: Text(
              '${step.order}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.primary),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              step.text,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _MissingRecipeState extends StatelessWidget {
  const _MissingRecipeState({required this.message, required this.onRetry});

  final String message;
  final Future<Recipe?> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: AppPanel(
          backgroundColor: AppColors.dangerSoft,
          borderColor: AppColors.danger.withValues(alpha: 0.2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.menu_book_outlined, size: 48),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => unawaited(onRetry()),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecipeLoadingState extends StatelessWidget {
  const _RecipeLoadingState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: AppPanel(
          backgroundColor: AppColors.surfaceTint,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.menu_book_outlined,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 16),
              const CircularProgressIndicator(),
              const SizedBox(height: 14),
              Text(
                'Loading recipe details...',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Color _categoryAccent(Recipe recipe) {
  switch (recipe.category) {
    case dynamic _ when recipe.category.name == 'breakfast':
      return const Color(0xFFD97706);
    case dynamic _ when recipe.category.name == 'lunch':
      return AppColors.primary;
    case dynamic _ when recipe.category.name == 'dinner':
      return AppColors.indigo;
    case dynamic _:
      return AppColors.pink;
  }
}

String _formatBytes(int bytes) {
  if (bytes < 1024) {
    return '$bytes B';
  }
  final kilobytes = bytes / 1024;
  if (kilobytes < 1024) {
    return '${kilobytes.toStringAsFixed(1)} KB';
  }
  final megabytes = kilobytes / 1024;
  return '${megabytes.toStringAsFixed(1)} MB';
}
