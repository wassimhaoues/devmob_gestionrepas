import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:provider/provider.dart';

import '../../models/ingredient.dart';
import '../../models/recipe_category.dart';
import '../../models/recipe_image_selection.dart';
import '../../models/recipe_step.dart';
import '../../providers/recipe_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/recipe_editor_widgets.dart';

const String addRecipeRoute = '/recipes/add';

class AddRecipePage extends StatefulWidget {
  const AddRecipePage({super.key});

  @override
  State<AddRecipePage> createState() => _AddRecipePageState();
}

class _AddRecipePageState extends State<AddRecipePage> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  RecipeCategory? _selectedCategory = RecipeCategory.breakfast;
  final List<_IngredientDraft> _ingredients = <_IngredientDraft>[
    _IngredientDraft(),
  ];
  final List<TextEditingController> _steps = <TextEditingController>[
    TextEditingController(),
  ];
  List<String> _submitErrors = const <String>[];
  RecipeImageSelection? _selectedImage;

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

  Future<void> _submit() async {
    final provider = context.read<RecipeProvider>();
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

    final errors = await provider.createRecipe(
      title: _titleController.text,
      description: _descriptionController.text,
      category: _selectedCategory,
      ingredients: ingredients,
      steps: steps,
      imageSelection: _selectedImage,
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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RecipeProvider>();
    final isLoading = provider.isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Add recipe')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: <Widget>[
          const _EditorIntro(
            title: 'Build a recipe worth reusing',
            description:
                'Capture the essentials now so planning and shopping stay easy later.',
          ),
          const SizedBox(height: 16),
          RecipeEditorSection(
            title: 'Recipe information',
            subtitle: 'Start with the core details for this dish.',
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
            subtitle: 'Use clear names so the shopping list stays readable.',
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
            subtitle: 'Keep each instruction short and actionable.',
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
            title: 'Optional recipe photo',
            subtitle: 'A photo makes the recipe easier to spot while planning.',
            children: <Widget>[
              RecipeEditorPhotoField(
                selectedBytes: _selectedImage?.bytes,
                existingImageUrl: null,
                onPickImage: isLoading ? null : _pickImage,
                onRemoveImage: _selectedImage == null
                    ? null
                    : () => setState(() => _selectedImage = null),
              ),
            ],
          ),
          if (_submitErrors.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            RecipeEditorErrorPanel(errors: _submitErrors),
          ],
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: isLoading ? null : _submit,
            icon: const Icon(Icons.save),
            label: Text(isLoading ? 'Saving recipe...' : 'Save recipe'),
          ),
        ],
      ),
    );
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
      _submitErrors = const <String>[];
    });
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
  _IngredientDraft()
    : nameController = TextEditingController(),
      quantityController = TextEditingController(),
      unitController = TextEditingController();

  final TextEditingController nameController;
  final TextEditingController quantityController;
  final TextEditingController unitController;

  void dispose() {
    nameController.dispose();
    quantityController.dispose();
    unitController.dispose();
  }
}
