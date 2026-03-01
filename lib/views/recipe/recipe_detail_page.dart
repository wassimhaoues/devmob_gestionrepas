import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/recipe.dart';
import '../../providers/recipe_provider.dart';
import 'edit_recipe_page.dart';

const String recipeDetailRoute = '/recipes/detail';

class RecipeDetailPage extends StatelessWidget {
  const RecipeDetailPage({super.key, this.recipeId});

  final String? recipeId;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RecipeProvider>();
    final resolvedId = _resolveRecipeId(context);
    final recipe = resolvedId == null ? null : provider.recipeById(resolvedId);

    if (recipe == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Recipe Detail')),
        body: const Center(child: Text('Recipe not found.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(recipe.title),
        actions: [
          IconButton(
            tooltip: 'Edit recipe',
            onPressed: () => _openEditPage(context, recipe.id),
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: recipe.isFavorite ? 'Unfavorite' : 'Favorite',
            onPressed: () => provider.toggleFavorite(
              recipeId: recipe.id,
              isFavorite: !recipe.isFavorite,
            ),
            icon: Icon(recipe.isFavorite ? Icons.star : Icons.star_border),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SummaryCard(recipe: recipe),
          const SizedBox(height: 12),
          _IngredientsCard(recipe: recipe),
          const SizedBox(height: 12),
          _StepsCard(recipe: recipe),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => _confirmDelete(context, recipe.id),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete Recipe'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  String? _resolveRecipeId(BuildContext context) {
    final routeArgs = ModalRoute.of(context)?.settings.arguments;
    if (routeArgs is String && routeArgs.trim().isNotEmpty) {
      return routeArgs.trim();
    }
    if (recipeId != null && recipeId!.trim().isNotEmpty) {
      return recipeId!.trim();
    }
    return null;
  }

  Future<void> _openEditPage(BuildContext context, String id) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => EditRecipePage(recipeId: id)),
    );
  }

  Future<void> _confirmDelete(BuildContext context, String id) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete recipe?'),
          content: const Text(
            'This action removes the recipe permanently from your account.',
          ),
          actions: [
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

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.recipe});

  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(
        context,
      ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text(recipe.category.label)),
                Chip(
                  label: Text(recipe.isFavorite ? 'Favorite' : 'Not favorite'),
                ),
              ],
            ),
            if (recipe.description.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                recipe.description,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            if ((recipe.imageUrl ?? '').isNotEmpty ||
                (recipe.imageStoragePath ?? '').isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Image metadata',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              if ((recipe.imageUrl ?? '').isNotEmpty)
                Text('URL: ${recipe.imageUrl}'),
              if ((recipe.imageStoragePath ?? '').isNotEmpty)
                Text('Storage path: ${recipe.imageStoragePath}'),
            ],
          ],
        ),
      ),
    );
  }
}

class _IngredientsCard extends StatelessWidget {
  const _IngredientsCard({required this.recipe});

  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ingredients', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            ...recipe.ingredients.map(
              (ingredient) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text(
                  '• ${ingredient.quantity} ${ingredient.unit} ${ingredient.displayName}',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepsCard extends StatelessWidget {
  const _StepsCard({required this.recipe});

  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Preparation', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            ...recipe.steps.map(
              (step) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text('Step ${step.order}'),
                subtitle: Text(step.text),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
