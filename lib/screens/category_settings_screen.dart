import 'package:flutter/material.dart';

import 'package:card_box/models/card_category.dart';
import 'package:card_box/services/card_repository.dart';
import 'package:card_box/services/category_service.dart';
import 'package:card_box/theme.dart';

class CategorySettingsScreen extends StatelessWidget {
  const CategorySettingsScreen({
    super.key,
    required this.categoryService,
    required this.repository,
  });

  final CategoryService categoryService;
  final CardRepository repository;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([categoryService, repository]),
      builder: (context, _) {
        final tokens = CardBoxThemeTokens.of(context);
        final customCategories = categoryService.customCategories;
        return Scaffold(
          appBar: AppBar(title: const Text('Categories')),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showAddDialog(context),
            icon: const Icon(Icons.add),
            label: const Text('Add category'),
          ),
          body: ListView(
            padding: EdgeInsets.fromLTRB(
              tokens.spaceLarge,
              tokens.spaceSmall,
              tokens.spaceLarge,
              96,
            ),
            children: [
              Card(
                child: Padding(
                  padding: EdgeInsets.all(tokens.spaceLarge),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Built-in categories',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: tokens.spaceSmall),
                      Text(
                        CardCategory.values
                            .where(
                              (category) =>
                                  category != CardCategory.contact &&
                                  category != CardCategory.other,
                            )
                            .map((category) => category.label)
                            .join(', '),
                      ),
                      SizedBox(height: tokens.spaceMedium - 2),
                      Text(
                        'Custom categories extend these. Built-ins stay fixed so the app remains predictable.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: tokens.spaceMedium),
              Card(
                child: Padding(
                  padding: EdgeInsets.all(tokens.spaceLarge),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Custom categories',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: tokens.spaceSmall),
                      if (customCategories.isEmpty)
                        const Text(
                          'Create custom categories here so they show up directly in the card picker.',
                        )
                      else
                        for (final category in customCategories)
                          _CategoryRow(
                            label: category,
                            usageCount: _usageCount(category),
                            onRename: () => _showRenameDialog(
                              context,
                              currentLabel: category,
                            ),
                            onMigrate: () => _showMigrateDialog(
                              context,
                              sourceLabel: category,
                            ),
                            onDelete: _usageCount(category) == 0
                                ? () => _deleteCategory(context, category)
                                : null,
                          ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  int _usageCount(String label) {
    return repository.cards
            .where(
              (card) =>
                  card.category == CardCategory.other &&
                  card.customCategory?.trim().toLowerCase() ==
                      label.toLowerCase(),
            )
            .length +
        repository.archivedCards
            .where(
              (card) =>
                  card.category == CardCategory.other &&
                  card.customCategory?.trim().toLowerCase() ==
                      label.toLowerCase(),
            )
            .length;
  }

  Future<void> _deleteCategory(BuildContext context, String label) async {
    final removed = await categoryService.removeCategory(label);
    if (!context.mounted || !removed) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Custom category removed')));
  }

  Future<void> _showAddDialog(BuildContext context) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final newLabel = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add custom category'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Category name',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              final trimmed = value?.trim() ?? '';
              if (trimmed.isEmpty) {
                return 'Enter a category name';
              }
              if (categoryService.containsCategory(trimmed)) {
                return 'That category already exists';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) {
                return;
              }
              Navigator.of(context).pop(controller.text.trim());
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (newLabel == null || !context.mounted) {
      return;
    }
    final added = await categoryService.addCategory(newLabel);
    if (added && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Custom category added')));
    }
  }

  Future<void> _showRenameDialog(
    BuildContext context, {
    required String currentLabel,
  }) async {
    final controller = TextEditingController(text: currentLabel);
    final formKey = GlobalKey<FormState>();
    final nextLabel = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename custom category'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Category name',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              final trimmed = value?.trim() ?? '';
              if (trimmed.isEmpty) {
                return 'Enter a category name';
              }
              if (trimmed.toLowerCase() != currentLabel.toLowerCase() &&
                  categoryService.containsCategory(trimmed)) {
                return 'That category already exists';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) {
                return;
              }
              Navigator.of(context).pop(controller.text.trim());
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (nextLabel == null || !context.mounted) {
      return;
    }
    final renamed = await categoryService.renameCategory(
      fromLabel: currentLabel,
      toLabel: nextLabel,
    );
    if (!renamed) {
      return;
    }
    final migratedCount = await repository.migrateCustomCategory(
      fromLabel: currentLabel,
      toCategory: CardCategory.other,
      toCustomCategory: nextLabel,
    );
    if (!context.mounted) {
      return;
    }
    final message = migratedCount == 0
        ? 'Category renamed to $nextLabel.'
        : 'Category renamed and $migratedCount card${migratedCount == 1 ? '' : 's'} updated.';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showMigrateDialog(
    BuildContext context, {
    required String sourceLabel,
  }) async {
    final customLabels =
        categoryService.customCategories
            .where((label) => label.toLowerCase() != sourceLabel.toLowerCase())
            .toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final cardsToMove = _usageCount(sourceLabel);
    var selectedKey = CardCategory.loyalty.name;
    final newCustomController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<_CategoryTarget>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final targetEntries = <DropdownMenuItem<String>>[
            ...CardCategory.values
                .where((category) => category != CardCategory.other)
                .map(
                  (category) => DropdownMenuItem<String>(
                    value: category.name,
                    child: Text(category.label),
                  ),
                ),
            ...customLabels.map(
              (label) => DropdownMenuItem<String>(
                value: 'custom:$label',
                child: Text(label),
              ),
            ),
            const DropdownMenuItem<String>(
              value: 'custom:new',
              child: Text('Create new custom category'),
            ),
          ];
          final needsCustomField = selectedKey == 'custom:new';
          return AlertDialog(
            title: Text('Move cards out of $sourceLabel'),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Choose where the existing cards in this custom category should go.',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$cardsToMove card${cardsToMove == 1 ? '' : 's'} will move from $sourceLabel.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedKey,
                    decoration: const InputDecoration(
                      labelText: 'Move cards to',
                      border: OutlineInputBorder(),
                    ),
                    items: targetEntries,
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setState(() => selectedKey = value);
                    },
                  ),
                  if (needsCustomField) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: newCustomController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'New custom category',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (!needsCustomField) {
                          return null;
                        }
                        final trimmed = value?.trim() ?? '';
                        if (trimmed.isEmpty) {
                          return 'Enter a category name';
                        }
                        if (trimmed.toLowerCase() !=
                                sourceLabel.toLowerCase() &&
                            categoryService.containsCategory(trimmed)) {
                          return 'That category already exists';
                        }
                        return null;
                      },
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  if (!formKey.currentState!.validate()) {
                    return;
                  }
                  final target = _targetFromKey(
                    selectedKey,
                    newCustomController.text.trim(),
                  );
                  if (target == null) {
                    return;
                  }
                  Navigator.of(context).pop(target);
                },
                child: const Text('Move cards'),
              ),
            ],
          );
        },
      ),
    );

    newCustomController.dispose();
    if (result == null || !context.mounted) {
      return;
    }
    if (result.category == CardCategory.other && result.customLabel != null) {
      await categoryService.addCategory(result.customLabel!);
    }
    final migratedCount = await repository.migrateCustomCategory(
      fromLabel: sourceLabel,
      toCategory: result.category,
      toCustomCategory: result.customLabel,
    );
    if (!context.mounted) {
      return;
    }
    final message = migratedCount == 0
        ? 'No cards needed moving.'
        : '$migratedCount card${migratedCount == 1 ? '' : 's'} moved to ${result.label}.';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  _CategoryTarget? _targetFromKey(String key, String newCustomLabel) {
    if (key == 'custom:new') {
      final trimmed = newCustomLabel.trim();
      if (trimmed.isEmpty) {
        return null;
      }
      return _CategoryTarget(
        category: CardCategory.other,
        customLabel: trimmed,
        label: trimmed,
      );
    }
    if (key.startsWith('custom:')) {
      final label = key.substring('custom:'.length).trim();
      if (label.isEmpty) {
        return null;
      }
      return _CategoryTarget(
        category: CardCategory.other,
        customLabel: label,
        label: label,
      );
    }
    final category = CardCategory.fromName(key);
    return _CategoryTarget(category: category, label: category.label);
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.label,
    required this.usageCount,
    required this.onRename,
    required this.onMigrate,
    required this.onDelete,
  });

  final String label;
  final int usageCount;
  final VoidCallback onRename;
  final VoidCallback onMigrate;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: Text(
        usageCount == 0
            ? 'Ready to use'
            : 'Used by $usageCount card${usageCount == 1 ? '' : 's'}',
      ),
      trailing: PopupMenuButton<_CategoryAction>(
        tooltip: 'Category actions',
        onSelected: (action) {
          switch (action) {
            case _CategoryAction.rename:
              onRename();
              break;
            case _CategoryAction.migrate:
              onMigrate();
              break;
            case _CategoryAction.delete:
              onDelete?.call();
              break;
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: _CategoryAction.rename,
            child: Text('Rename'),
          ),
          const PopupMenuItem(
            value: _CategoryAction.migrate,
            child: Text('Move cards'),
          ),
          if (onDelete != null)
            const PopupMenuItem(
              value: _CategoryAction.delete,
              child: Text('Delete'),
            ),
        ],
      ),
    );
  }
}

enum _CategoryAction { rename, migrate, delete }

class _CategoryTarget {
  const _CategoryTarget({
    required this.category,
    required this.label,
    this.customLabel,
  });

  final CardCategory category;
  final String label;
  final String? customLabel;
}
