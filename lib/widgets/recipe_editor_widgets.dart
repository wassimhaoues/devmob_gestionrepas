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
    required this.children,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceTint,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
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
        Row(
          children: <Widget>[
            Expanded(
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
            if (onRemoveImage != null) ...<Widget>[
              const SizedBox(width: 12),
              IconButton(
                onPressed: onRemoveImage,
                tooltip: 'Remove photo',
                icon: const Icon(Icons.delete_outline),
              ),
            ],
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
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFFF2FAF5), Colors.white],
        ),
        borderRadius: BorderRadius.circular(24),
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

class _MemoryPhotoPreview extends StatelessWidget {
  const _MemoryPhotoPreview({required this.bytes});

  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
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
      borderRadius: BorderRadius.circular(24),
      child: Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const _EmptyPhotoPreview(),
      ),
    );
  }
}
