import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_panels.dart';

class RecipeEditorSection extends StatelessWidget {
  const RecipeEditorSection({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.icon = Icons.tune,
    this.accentColor = AppColors.primary,
    required this.children,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final IconData icon;
  final Color accentColor;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: accentColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(title, style: Theme.of(context).textTheme.titleLarge),
                    if (subtitle case final String subtitle) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing case final Widget trailing) trailing,
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class RecipeEditorBlock extends StatelessWidget {
  const RecipeEditorBlock({
    super.key,
    required this.child,
    this.margin = const EdgeInsets.only(bottom: 10),
  });

  final Widget child;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.card,
      ),
      child: child,
    );
  }
}

class RecipeEditorErrorPanel extends StatelessWidget {
  const RecipeEditorErrorPanel({super.key, required this.errors});

  final List<String> errors;

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      backgroundColor: AppColors.dangerSoft,
      borderColor: AppColors.danger.withValues(alpha: 0.2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: errors
            .map(
              (String error) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text(
                  '• $error',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF9F2E2E),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class RecipeEditorPhotoField extends StatelessWidget {
  const RecipeEditorPhotoField({
    super.key,
    required this.selectedBytes,
    required this.existingImageUrl,
    required this.onPickImage,
    required this.onRemoveImage,
  });

  final Uint8List? selectedBytes;
  final String? existingImageUrl;
  final Future<void> Function()? onPickImage;
  final VoidCallback? onRemoveImage;

  @override
  Widget build(BuildContext context) {
    Widget preview;
    if (selectedBytes != null) {
      preview = _MemoryPhotoPreview(bytes: selectedBytes!);
    } else if ((existingImageUrl ?? '').isNotEmpty) {
      preview = _NetworkPhotoPreview(imageUrl: existingImageUrl!);
    } else {
      preview = const _EmptyPhotoPreview();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(height: 210, child: preview),
        const SizedBox(height: 12),
        Text(
          'Supported: JPG, PNG, WEBP. Source image must be 10 MB or smaller.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: <Widget>[
            SizedBox(
              width: 180,
              child: OutlinedButton.icon(
                onPressed: onPickImage == null ? null : () => onPickImage!(),
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(
                  selectedBytes == null && (existingImageUrl ?? '').isEmpty
                      ? 'Choose photo'
                      : 'Replace photo',
                ),
              ),
            ),
            if (onRemoveImage != null)
              SizedBox(
                width: 140,
                child: OutlinedButton.icon(
                  onPressed: onRemoveImage,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Remove'),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _EmptyPhotoPreview extends StatelessWidget {
  const _EmptyPhotoPreview();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[AppColors.surfaceTint, AppColors.primarySoft],
        ),
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppColors.borderStrong, width: 1.5),
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.image_outlined, size: 42, color: AppColors.primary),
            SizedBox(height: 10),
            Text('No photo selected'),
          ],
        ),
      ),
    );
  }
}

class RecipeEditorWorkspaceIntro extends StatelessWidget {
  const RecipeEditorWorkspaceIntro({
    super.key,
    required this.title,
    required this.description,
    required this.highlights,
  });

  final String title;
  final String description;
  final List<String> highlights;

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
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: highlights
                .map(
                  (highlight) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Text(
                      highlight,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.white),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class RecipeEditorWorkspaceSummary extends StatelessWidget {
  const RecipeEditorWorkspaceSummary({super.key, required this.items});

  final List<RecipeWorkspaceStat> items;

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      backgroundColor: AppColors.surfaceTint,
      child: Row(
        children: items
            .map(
              (item) => Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: item == items.last ? 0 : 10),
                  child: _RecipeWorkspaceStatTile(item: item),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class RecipeWorkspaceStat {
  const RecipeWorkspaceStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.backgroundColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color backgroundColor;
}

class _RecipeWorkspaceStatTile extends StatelessWidget {
  const _RecipeWorkspaceStatTile({required this.item});

  final RecipeWorkspaceStat item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: item.color,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(item.icon, color: Colors.white, size: 18),
          ),
          const SizedBox(height: 10),
          Text(
            item.value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: item.color,
            ),
          ),
          const SizedBox(height: 2),
          Text(item.label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _MemoryPhotoPreview extends StatelessWidget {
  const _MemoryPhotoPreview({required this.bytes});

  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.lg),
      child: Image.memory(bytes, fit: BoxFit.cover),
    );
  }
}

class _NetworkPhotoPreview extends StatelessWidget {
  const _NetworkPhotoPreview({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.lg),
      child: Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const _EmptyPhotoPreview(),
      ),
    );
  }
}
