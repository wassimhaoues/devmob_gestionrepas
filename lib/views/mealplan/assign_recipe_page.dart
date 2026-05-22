import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/meal_plan_assignment_args.dart';
import '../../models/recipe.dart';
import '../../providers/auth_provider.dart';
import '../../providers/meal_plan_provider.dart';
import '../../services/recipe/recipe_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_panels.dart';
import '../recipe/add_recipe_page.dart';

const String assignRecipeRoute = '/meal-plan/assign-recipe';

class AssignRecipePage extends StatefulWidget {
  const AssignRecipePage({super.key, this.args});

  final MealPlanAssignmentArgs? args;

  @override
  State<AssignRecipePage> createState() => _AssignRecipePageState();
}

class _AssignRecipePageState extends State<AssignRecipePage> {
  final TextEditingController _searchController = TextEditingController();

  String? _lastLoadedUid;
  List<Recipe> _recipes = const <Recipe>[];
  bool _isLoading = true;
  bool _favoritesOnly = false;
  String? _errorMessage;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final uid = context.read<AuthProvider>().currentUser?.uid;
    if (uid == null || uid == _lastLoadedUid) {
      return;
    }

    _lastLoadedUid = uid;
    unawaited(_loadRecipes(uid));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final args = _resolveArgs(context);
    if (args == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Assign Recipe')),
        body: const Center(child: Text('Meal slot is missing.')),
      );
    }

    final filteredRecipes = _buildFilteredRecipes();
    final mealPlanProvider = context.watch<MealPlanProvider>();
    final currentEntry = mealPlanProvider.entryFor(
      date: args.date,
      slotType: args.slotType,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Assign Recipe')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        children: <Widget>[
          _AssignmentHero(
            args: args,
            currentRecipeTitle: currentEntry?.recipeTitle,
          ),
          const SizedBox(height: 12),
          AppPanel(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: <Widget>[
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    labelText: 'Search recipes',
                    hintText: 'Search by title, description, or category',
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                            icon: const Icon(Icons.close),
                          ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    FilterChip(
                      label: const Text('Favorites first'),
                      selected: _favoritesOnly,
                      onSelected: (value) {
                        setState(() => _favoritesOnly = value);
                      },
                    ),
                    const Spacer(),
                    _InlineStatChip(
                      icon: Icons.restaurant_menu,
                      label: '${filteredRecipes.length} shown',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.only(top: 48),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_errorMessage != null)
            _ErrorState(
              message: _errorMessage!,
              onRetry: _reloadCurrentUserRecipes,
            )
          else if (filteredRecipes.isEmpty)
            _EmptyState(
              hasSearchQuery: _searchController.text.trim().isNotEmpty,
              onCreateRecipe: () =>
                  Navigator.of(context).pushNamed(addRecipeRoute),
            )
          else
            ...filteredRecipes.map(
              (recipe) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _RecipeSelectionCard(
                  recipe: recipe,
                  isSaving: mealPlanProvider.status ==
                      MealPlanProviderStatus.mutating,
                  onTap: () => _assignRecipe(args, recipe),
                ),
              ),
            ),
        ],
      ),
    );
  }

  MealPlanAssignmentArgs? _resolveArgs(BuildContext context) {
    final routeArgs = ModalRoute.of(context)?.settings.arguments;
    if (routeArgs is MealPlanAssignmentArgs) {
      return routeArgs;
    }
    return widget.args;
  }

  List<Recipe> _buildFilteredRecipes() {
    final query = _searchController.text.trim().toLowerCase();
    Iterable<Recipe> filtered = _recipes;

    if (_favoritesOnly) {
      filtered = filtered.where((recipe) => recipe.isFavorite);
    }

    if (query.isNotEmpty) {
      filtered = filtered.where((recipe) {
        return recipe.title.toLowerCase().contains(query) ||
            recipe.description.toLowerCase().contains(query) ||
            recipe.category.label.toLowerCase().contains(query);
      });
    }

    final sorted = filtered.toList()
      ..sort((left, right) {
        if (left.isFavorite != right.isFavorite) {
          return left.isFavorite ? -1 : 1;
        }
        return left.title.toLowerCase().compareTo(right.title.toLowerCase());
      });
    return sorted;
  }

  Future<void> _reloadCurrentUserRecipes() async {
    final uid = context.read<AuthProvider>().currentUser?.uid;
    if (uid == null) {
      return;
    }
    await _loadRecipes(uid);
  }

  Future<void> _loadRecipes(String uid) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final recipes = await context.read<RecipeService>().fetchRecipes(uid: uid);
      if (!mounted) {
        return;
      }
      setState(() {
        _recipes = recipes;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = 'Unable to load recipes for meal assignment.';
      });
    }
  }

  Future<void> _assignRecipe(
    MealPlanAssignmentArgs args,
    Recipe recipe,
  ) async {
    final provider = context.read<MealPlanProvider>();
    final errors = await provider.assignRecipeToSlot(
      date: args.date,
      slotType: args.slotType,
      recipe: recipe,
    );

    if (!mounted) {
      return;
    }

    if (errors.isEmpty) {
      Navigator.of(context).pop(true);
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(errors.first)));
  }
}

class _AssignmentHero extends StatelessWidget {
  const _AssignmentHero({
    required this.args,
    required this.currentRecipeTitle,
  });

  final MealPlanAssignmentArgs args;
  final String? currentRecipeTitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[AppColors.indigo, AppColors.primary],
        ),
        borderRadius: BorderRadius.circular(30),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Assign a recipe to ${args.slotType.label}',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            _formatDay(args.date),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            currentRecipeTitle == null || currentRecipeTitle!.isEmpty
                ? 'Choose a recipe that fits this slot and it will appear in your weekly planner instantly.'
                : 'Currently assigned: $currentRecipeTitle',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 12),
          _HeroPill(
            icon: Icons.schedule,
            label: '${args.slotType.label} slot',
          ),
        ],
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.icon, required this.label});

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

class _InlineStatChip extends StatelessWidget {
  const _InlineStatChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceTint,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 15, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _RecipeSelectionCard extends StatelessWidget {
  const _RecipeSelectionCard({
    required this.recipe,
    required this.isSaving,
    required this.onTap,
  });

  final Recipe recipe;
  final bool isSaving;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AppPanel(
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: isSaving ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: SizedBox(
                  width: 84,
                  height: 84,
                  child: (recipe.imageUrl ?? '').isEmpty
                      ? DecoratedBox(
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                          ),
                          child: Icon(
                            Icons.restaurant_menu,
                            size: 28,
                            color: colorScheme.primary,
                          ),
                        )
                      : Image.network(
                          recipe.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => DecoratedBox(
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                            ),
                            child: Icon(
                              Icons.restaurant_menu,
                              size: 28,
                              color: colorScheme.primary,
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      recipe.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      recipe.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        Chip(
                          label: Text(recipe.category.label),
                          visualDensity: VisualDensity.compact,
                        ),
                        if (recipe.isFavorite)
                          Chip(
                            label: const Text('Favorite'),
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.arrow_forward_ios,
                  size: 18,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      backgroundColor: AppColors.dangerSoft,
      borderColor: AppColors.danger.withValues(alpha: 0.18),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Column(
          children: <Widget>[
            const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
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
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.hasSearchQuery,
    required this.onCreateRecipe,
  });

  final bool hasSearchQuery;
  final VoidCallback onCreateRecipe;

  @override
  Widget build(BuildContext context) {
    final title = hasSearchQuery ? 'No matching recipes' : 'No recipes yet';
    final description = hasSearchQuery
        ? 'Try a different search or turn off the favorites filter.'
        : 'Create a recipe first so you can assign it to a meal slot.';

    return AppPanel(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Column(
          children: <Widget>[
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.menu_book_outlined, color: AppColors.primary),
            ),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              description,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (!hasSearchQuery) ...<Widget>[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onCreateRecipe,
                icon: const Icon(Icons.add),
                label: const Text('Create Recipe'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _formatDay(DateTime date) {
  const dayNames = <String>[
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  const monthNames = <String>[
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
  return '${dayNames[date.weekday - 1]}, ${monthNames[date.month - 1]} ${date.day}';
}
