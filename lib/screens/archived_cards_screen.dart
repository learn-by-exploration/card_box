import 'package:flutter/material.dart';

import 'package:card_box/models/wallet_card.dart';
import 'package:card_box/screens/card_detail_screen.dart';
import 'package:card_box/services/app_lock_service.dart';
import 'package:card_box/services/card_repository.dart';
import 'package:card_box/services/category_service.dart';

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
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
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
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: onOpen,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.archive_outlined),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            card.name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            card.issuer.isEmpty
                                ? card.categoryLabel
                                : '${card.issuer} • ${card.categoryLabel}',
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: onRestore,
                  icon: const Icon(Icons.unarchive_outlined),
                  label: const Text('Restore'),
                ),
                OutlinedButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
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
