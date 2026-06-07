import 'package:flutter/material.dart';

import 'package:card_box/models/wallet_card.dart';
import 'package:card_box/screens/card_detail_screen.dart';
import 'package:card_box/services/app_lock_service.dart';
import 'package:card_box/services/card_repository.dart';
import 'package:card_box/services/category_service.dart';
import 'package:card_box/theme.dart';

class ArchivedCardsScreen extends StatelessWidget {
  const ArchivedCardsScreen({
    super.key,
    required this.repository,
    required this.appLockService,
    required this.categoryService,
  });

  final CardRepository repository;
  final AppLockService appLockService;
  final CategoryService categoryService;

  @override
  Widget build(BuildContext context) {
    final tokens = CardBoxThemeTokens.of(context);
    return AnimatedBuilder(
      animation: repository,
      builder: (context, _) {
        final cards = repository.archivedCards;
        return Scaffold(
          appBar: AppBar(title: const Text('Archived cards')),
          body: cards.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Archived cards will appear here so they can be restored or deleted later.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: EdgeInsets.fromLTRB(
                    tokens.spaceLarge,
                    tokens.spaceMedium,
                    tokens.spaceLarge,
                    tokens.spaceXLarge + 12,
                  ),
                  itemBuilder: (context, index) {
                    final card = cards[index];
                    return _ArchivedCardRow(
                      card: card,
                      onOpen: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CardDetailScreen(
                            repository: repository,
                            appLockService: appLockService,
                            categoryService: categoryService,
                            cardId: card.id,
                          ),
                        ),
                      ),
                      onRestore: () => repository.unarchive(card.id),
                      onDelete: () => _confirmDelete(context, card),
                    );
                  },
                  separatorBuilder: (_, _) =>
                      SizedBox(height: tokens.spaceMedium - 2),
                  itemCount: cards.length,
                ),
        );
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context, WalletCard card) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete permanently?'),
        content: Text(
          '${card.name} and its saved images will be removed from this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await repository.deleteCard(card.id);
    }
  }
}

class _ArchivedCardRow extends StatelessWidget {
  const _ArchivedCardRow({
    required this.card,
    required this.onOpen,
    required this.onRestore,
    required this.onDelete,
  });

  final WalletCard card;
  final VoidCallback onOpen;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = CardBoxThemeTokens.of(context);
    return Card(
      child: Padding(
        padding: EdgeInsets.all(tokens.spaceMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(tokens.radiusSmall),
              onTap: onOpen,
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: tokens.spaceXSmall),
                child: Row(
                  children: [
                    Icon(Icons.archive_outlined, size: tokens.iconMedium),
                    SizedBox(width: tokens.spaceMedium),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            card.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: tokens.spaceXSmall),
                          Text(
                            card.issuer.isEmpty
                                ? card.categoryLabel
                                : '${card.issuer} • ${card.categoryLabel}',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, size: tokens.iconMedium),
                  ],
                ),
              ),
            ),
            SizedBox(height: tokens.spaceMedium),
            Wrap(
              spacing: tokens.spaceSmall,
              runSpacing: tokens.spaceSmall,
              children: [
                OutlinedButton.icon(
                  onPressed: onRestore,
                  icon: Icon(Icons.unarchive_outlined, size: tokens.iconMedium),
                  label: const Text('Restore'),
                ),
                OutlinedButton.icon(
                  onPressed: onDelete,
                  icon: Icon(Icons.delete_outline, size: tokens.iconMedium),
                  label: const Text('Delete'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
