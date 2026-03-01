import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/ingredient.dart';
import '../../models/recipe_category.dart';
import '../../models/recipe_step.dart';
import '../../providers/recipe_provider.dart';

const String editRecipeRoute = '/recipes/edit';

class EditRecipePage extends StatefulWidget {
  const EditRecipePage({super.key, this.recipeId});

  final String? recipeId;

  @override
  State<EditRecipePage> createState() => _EditRecipePageState();
}

class _EditRecipePageState extends State<EditRecipePage> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _imageUrlController = TextEditingController();
  final _imageStoragePathController = TextEditingController();

  RecipeCategory? _selectedCategory;
  final List<_IngredientDraft> _ingredients = <_IngredientDraft>[];
  final List<TextEditingController> _steps = <TextEditingController>[];
  List<String> _submitErrors = const <String>[];
  String? _editingRecipeId;
  bool _initialized = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _imageUrlController.dispose();
    _imageStoragePathController.dispose();
    for (final ingredient in _ingredients) {
      ingredient.dispose();
    }
    for (final step in _steps) {
      step.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) {
      return;
    }
    _initialized = true;

    final recipeId = _resolveRecipeId(context);
    if (recipeId == null) {
      return;
    }

    final recipe = context.read<RecipeProvider>().recipeById(recipeId);
    if (recipe == null) {
      return;
    }

    _editingRecipeId = recipe.id;
    _titleController.text = recipe.title;
    _descriptionController.text = recipe.description;
    _imageUrlController.text = recipe.imageUrl ?? '';
    _imageStoragePathController.text = recipe.imageStoragePath ?? '';
    _selectedCategory = recipe.category;

    for (final ingredient in recipe.ingredients) {
      _ingredients.add(
        _IngredientDraft(
          name: ingredient.displayName,
          quantity: ingredient.quantity.toString(),
          unit: ingredient.unit,
        ),
      );
    }
    if (_ingredients.isEmpty) {
      _ingredients.add(_IngredientDraft());
    }

    for (final step in recipe.steps) {
      _steps.add(TextEditingController(text: step.text));
    }
    if (_steps.isEmpty) {
      _steps.add(TextEditingController());
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RecipeProvider>();
    final isLoading = provider.isLoading;
    final recipeId = _editingRecipeId;

    if (recipeId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit Recipe')),
        body: const Center(child: Text('Recipe not found.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Recipe')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionCard(
            title: 'Recipe Information',
            children: [
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title'),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
                minLines: 2,
                maxLines: 4,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<RecipeCategory>(
                initialValue: _selectedCategory,
                decoration: const InputDecoration(labelText: 'Category'),
                items: RecipeCategory.values
                    .map(
                      (category) => DropdownMenuItem<RecipeCategory>(
                        value: category,
                        child: Text(category.label),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() => _selectedCategory = value);
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: 'Ingredients',
            trailing: IconButton(
              onPressed: _addIngredient,
              icon: const Icon(Icons.add),
              tooltip: 'Add ingredient',
            ),
            children: [
              for (var i = 0; i < _ingredients.length; i++)
                _IngredientFields(
                  index: i,
                  draft: _ingredients[i],
                  canRemove: _ingredients.length > 1,
                  onRemove: () => _removeIngredient(i),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: 'Preparation Steps',
            trailing: IconButton(
              onPressed: _addStep,
              icon: const Icon(Icons.add),
              tooltip: 'Add step',
            ),
            children: [
              for (var i = 0; i < _steps.length; i++)
                _StepField(
                  index: i,
                  controller: _steps[i],
                  canRemove: _steps.length > 1,
                  onRemove: () => _removeStep(i),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: 'Optional Image Metadata',
            children: [
              TextField(
                controller: _imageUrlController,
                decoration: const InputDecoration(labelText: 'Image URL'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _imageStoragePathController,
                decoration: const InputDecoration(
                  labelText: 'Image storage path',
                ),
              ),
            ],
          ),
          if (_submitErrors.isNotEmpty) ...[
            const SizedBox(height: 12),
            _ErrorPanel(errors: _submitErrors),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: isLoading ? null : () => _submit(recipeId),
            icon: const Icon(Icons.save),
            label: const Text('Update Recipe'),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Future<void> _submit(String recipeId) async {
    final provider = context.read<RecipeProvider>();
    final existing = provider.recipeById(recipeId);
    final ingredients = _ingredients.map((draft) {
      final quantity = double.tryParse(
        draft.quantityController.text.trim().replaceAll(',', '.'),
      );
      return Ingredient(
        displayName: draft.nameController.text,
        canonicalName: '',
        quantity: quantity ?? 0,
        unit: draft.unitController.text,
      );
    }).toList();

    final steps = _steps.asMap().entries.map((entry) {
      return RecipeStep(order: entry.key + 1, text: entry.value.text);
    }).toList();

    final errors = await provider.updateRecipe(
      recipeId: recipeId,
      title: _titleController.text,
      description: _descriptionController.text,
      category: _selectedCategory,
      ingredients: ingredients,
      steps: steps,
      isFavorite: existing?.isFavorite,
      imageUrl: _imageUrlController.text,
      imageStoragePath: _imageStoragePathController.text,
    );

    if (!mounted) {
      return;
    }

    if (errors.isEmpty) {
      Navigator.of(context).pop(true);
      return;
    }

    setState(() => _submitErrors = errors);
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

  void _addIngredient() {
    setState(() => _ingredients.add(_IngredientDraft()));
  }

  void _removeIngredient(int index) {
    final item = _ingredients.removeAt(index);
    item.dispose();
    setState(() {});
  }

  void _addStep() {
    setState(() => _steps.add(TextEditingController()));
  }

  void _removeStep(int index) {
    final controller = _steps.removeAt(index);
    controller.dispose();
    setState(() {});
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.children,
    this.trailing,
  });

  final String title;
  final Widget? trailing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final headerChildren = <Widget>[
      Expanded(
        child: Text(title, style: Theme.of(context).textTheme.titleMedium),
      ),
    ];
    if (trailing != null) {
      headerChildren.add(trailing!);
    }

    return Card(
      elevation: 0,
      color: Theme.of(
        context,
      ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: headerChildren),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _IngredientFields extends StatelessWidget {
  const _IngredientFields({
    required this.index,
    required this.draft,
    required this.canRemove,
    required this.onRemove,
  });

  final int index;
  final _IngredientDraft draft;
  final bool canRemove;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text('Ingredient ${index + 1}'),
                const Spacer(),
                if (canRemove)
                  IconButton(
                    onPressed: onRemove,
                    icon: const Icon(Icons.remove_circle_outline),
                    tooltip: 'Remove ingredient',
                  ),
              ],
            ),
            TextField(
              controller: draft.nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: draft.quantityController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Quantity'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: draft.unitController,
                    decoration: const InputDecoration(labelText: 'Unit'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StepField extends StatelessWidget {
  const _StepField({
    required this.index,
    required this.controller,
    required this.canRemove,
    required this.onRemove,
  });

  final int index;
  final TextEditingController controller;
  final bool canRemove;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text('Step ${index + 1}'),
                const Spacer(),
                if (canRemove)
                  IconButton(
                    onPressed: onRemove,
                    icon: const Icon(Icons.remove_circle_outline),
                    tooltip: 'Remove step',
                  ),
              ],
            ),
            TextField(
              controller: controller,
              decoration: const InputDecoration(labelText: 'Instruction'),
              minLines: 1,
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.errors});

  final List<String> errors;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: errors
              .map(
                (error) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    '• $error',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _IngredientDraft {
  _IngredientDraft({String name = '', String quantity = '', String unit = ''})
    : nameController = TextEditingController(text: name),
      quantityController = TextEditingController(text: quantity),
      unitController = TextEditingController(text: unit);

  final TextEditingController nameController;
  final TextEditingController quantityController;
  final TextEditingController unitController;

  void dispose() {
    nameController.dispose();
    quantityController.dispose();
    unitController.dispose();
  }
}
