import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:provider/provider.dart';

import '../../models/ingredient.dart';
import '../../models/recipe.dart';
import '../../models/recipe_category.dart';
import '../../models/recipe_image_selection.dart';
import '../../models/recipe_step.dart';
import '../../providers/recipe_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/recipe_editor_widgets.dart';

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

  RecipeCategory? _selectedCategory;
  final List<_IngredientDraft> _ingredients = <_IngredientDraft>[];
  final List<TextEditingController> _steps = <TextEditingController>[];
  List<String> _submitErrors = const <String>[];
  String? _editingRecipeId;
  bool _initialized = false;
  bool _isBootstrapping = true;
  RecipeImageSelection? _selectedImage;
  String? _existingImageUrl;
  bool _removeExistingImage = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    for (final _IngredientDraft ingredient in _ingredients) {
      ingredient.dispose();
    }
    for (final TextEditingController step in _steps) {
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
      _isBootstrapping = false;
      return;
    }

    final provider = context.read<RecipeProvider>();
    final cachedRecipe = provider.recipeById(recipeId);
    if (cachedRecipe != null) {
      _hydrateForm(cachedRecipe);
      _isBootstrapping = false;
      return;
    }

    unawaited(_loadRecipe(provider, recipeId));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RecipeProvider>();
    final isLoading = provider.isLoading;
    final recipeId = _editingRecipeId;

    if (_isBootstrapping) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (recipeId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit recipe')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: RecipeEditorErrorPanel(
              errors: <String>[provider.errorMessage ?? 'Recipe not found.'],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Edit recipe')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: <Widget>[
          const _EditorIntro(
            title: 'Refine your recipe',
            description:
                'Tighten the details so the rest of your planning flow stays accurate.',
          ),
          const SizedBox(height: 16),
          RecipeEditorSection(
            title: 'Recipe information',
            subtitle: 'Keep the basics clear and easy to scan.',
            children: <Widget>[
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  hintText: 'Ex: Olive toast with herbs',
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'A short description for your future self',
                ),
                minLines: 2,
                maxLines: 4,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<RecipeCategory>(
                initialValue: _selectedCategory,
                decoration: const InputDecoration(labelText: 'Category'),
                items: RecipeCategory.values
                    .map(
                      (RecipeCategory category) =>
                          DropdownMenuItem<RecipeCategory>(
                            value: category,
                            child: Text(category.label),
                          ),
                    )
                    .toList(),
                onChanged: (RecipeCategory? value) {
                  setState(() => _selectedCategory = value);
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          RecipeEditorSection(
            title: 'Ingredients',
            subtitle: 'These values drive the shopping list output.',
            trailing: IconButton(
              onPressed: _addIngredient,
              icon: const Icon(Icons.add),
              tooltip: 'Add ingredient',
            ),
            children: <Widget>[
              for (int i = 0; i < _ingredients.length; i++)
                _IngredientFields(
                  index: i,
                  draft: _ingredients[i],
                  canRemove: _ingredients.length > 1,
                  onRemove: () => _removeIngredient(i),
                ),
            ],
          ),
          const SizedBox(height: 12),
          RecipeEditorSection(
            title: 'Preparation steps',
            subtitle: 'Make the sequence easy to follow at a glance.',
            trailing: IconButton(
              onPressed: _addStep,
              icon: const Icon(Icons.add),
              tooltip: 'Add step',
            ),
            children: <Widget>[
              for (int i = 0; i < _steps.length; i++)
                _StepField(
                  index: i,
                  controller: _steps[i],
                  canRemove: _steps.length > 1,
                  onRemove: () => _removeStep(i),
                ),
            ],
          ),
          const SizedBox(height: 12),
          RecipeEditorSection(
            title: 'Recipe photo',
            subtitle: 'Replace or remove the current image whenever needed.',
            children: <Widget>[
              RecipeEditorPhotoField(
                selectedBytes: _selectedImage?.bytes,
                existingImageUrl: _removeExistingImage
                    ? null
                    : _existingImageUrl,
                onPickImage: isLoading ? null : _pickImage,
                onRemoveImage: _buildRemoveImageCallback(),
              ),
            ],
          ),
          if (_submitErrors.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            RecipeEditorErrorPanel(errors: _submitErrors),
          ],
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: isLoading ? null : () => _submit(recipeId),
            icon: const Icon(Icons.save),
            label: Text(isLoading ? 'Updating recipe...' : 'Update recipe'),
          ),
        ],
      ),
    );
  }

  Future<void> _submit(String recipeId) async {
    final provider = context.read<RecipeProvider>();
    final existing = provider.recipeById(recipeId);
    final ingredients = _ingredients.map((_IngredientDraft draft) {
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
      imageSelection: _selectedImage,
      removeImage: _removeExistingImage,
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

  Future<void> _loadRecipe(
    RecipeProvider provider,
    String recipeId, {
    bool forceRefresh = false,
  }) async {
    final recipe = await provider.loadRecipeById(
      recipeId,
      forceRefresh: forceRefresh,
    );
    if (!mounted) {
      return;
    }

    if (recipe != null) {
      _hydrateForm(recipe);
    }

    setState(() => _isBootstrapping = false);
  }

  void _hydrateForm(Recipe recipe) {
    _editingRecipeId = recipe.id;
    _titleController.text = recipe.title;
    _descriptionController.text = recipe.description;
    _selectedCategory = recipe.category;
    _selectedImage = null;
    _existingImageUrl = recipe.imageUrl;
    _removeExistingImage = false;

    for (final _IngredientDraft ingredient in _ingredients) {
      ingredient.dispose();
    }
    _ingredients.clear();
    for (final Ingredient ingredient in recipe.ingredients) {
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

    for (final TextEditingController step in _steps) {
      step.dispose();
    }
    _steps.clear();
    for (final RecipeStep step in recipe.steps) {
      _steps.add(TextEditingController(text: step.text));
    }
    if (_steps.isEmpty) {
      _steps.add(TextEditingController());
    }
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

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null || !mounted) {
      return;
    }

    final bytes = await file.readAsBytes();
    if (!mounted) {
      return;
    }

    setState(() {
      _selectedImage = RecipeImageSelection(
        bytes: bytes,
        fileName: file.name,
        mimeType: lookupMimeType(file.name, headerBytes: bytes),
      );
      _removeExistingImage = false;
      _submitErrors = const <String>[];
    });
  }

  VoidCallback? _buildRemoveImageCallback() {
    if (_selectedImage != null) {
      return () {
        setState(() {
          _selectedImage = null;
          _submitErrors = const <String>[];
        });
      };
    }

    if ((_existingImageUrl ?? '').isNotEmpty && !_removeExistingImage) {
      return () {
        setState(() {
          _removeExistingImage = true;
          _submitErrors = const <String>[];
        });
      };
    }

    return null;
  }
}

class _EditorIntro extends StatelessWidget {
  const _EditorIntro({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[AppColors.primary, AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: const Color(0xFFE4F4EA)),
          ),
        ],
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
    return RecipeEditorBlock(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
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
          const SizedBox(height: 8),
          TextField(
            controller: draft.nameController,
            decoration: const InputDecoration(
              labelText: 'Name',
              hintText: 'Ex: Black olives',
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: draft.quantityController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Quantity',
                    hintText: '1',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: draft.unitController,
                  decoration: const InputDecoration(
                    labelText: 'Unit',
                    hintText: 'cup, g, tbsp',
                  ),
                ),
              ),
            ],
          ),
        ],
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
    return RecipeEditorBlock(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
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
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Instruction',
              hintText: 'Describe this step clearly',
            ),
            minLines: 2,
            maxLines: 4,
          ),
        ],
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
