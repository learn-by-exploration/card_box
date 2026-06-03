import 'package:flutter/material.dart';

import 'package:card_box/models/add_card_preset.dart';
import 'package:card_box/models/card_category.dart';
import 'package:card_box/models/compatibility_status.dart';
import 'package:card_box/models/wallet_card.dart';
import 'package:card_box/screens/archived_cards_screen.dart';
import 'package:card_box/screens/app_lock_settings_screen.dart';
import 'package:card_box/screens/barcode_present_screen.dart';
import 'package:card_box/screens/card_detail_screen.dart';
import 'package:card_box/screens/compatibility_test_screen.dart';
import 'package:card_box/screens/edit_card_screen.dart';
import 'package:card_box/screens/export_import_screen.dart';
import 'package:card_box/services/app_lock_service.dart';
import 'package:card_box/services/card_repository.dart';
import 'package:card_box/widgets/card_tile.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.repository,
    required this.appLockService,
  });

  final CardRepository repository;
  final AppLockService appLockService;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _query = '';
  CardCategory? _category;
  _StatusFilter _statusFilter = _StatusFilter.all;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.repository,
      builder: (context, _) {
        final allCards = widget.repository.cards;
        final archivedCount = widget.repository.archivedCards.length;
        final cards = _filteredCards(allCards);
        return Scaffold(
          appBar: AppBar(
            title: const Text('Card Box'),
            actions: [
              PopupMenuButton<_HomeMenuAction>(
                tooltip: 'More',
                onSelected: _handleMenuAction,
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: _HomeMenuAction.archived,
                    child: Row(
                      children: [
                        const Icon(Icons.archive_outlined, size: 18),
                        const SizedBox(width: 10),
                        Text(
                          archivedCount == 0
                              ? 'Archived cards'
                              : 'Archived cards ($archivedCount)',
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: _HomeMenuAction.summary,
                    child: Row(
                      children: [
                        Icon(Icons.space_dashboard_outlined, size: 18),
                        SizedBox(width: 10),
                        Text('Wallet summary'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: _HomeMenuAction.backup,
                    child: const Row(
                      children: [
                        Icon(Icons.ios_share, size: 18),
                        SizedBox(width: 10),
                        Text('Backup and import'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: _HomeMenuAction.lock,
                    child: Row(
                      children: [
                        Icon(
                          widget.appLockService.lockEnabled
                              ? Icons.lock_outline
                              : Icons.shield_outlined,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        const Text('App lock'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search cards, issuers, notes, or codes',
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
                const SizedBox(height: 16),
                _SectionLabel(
                  title: 'Your cards',
                  trailing: Text(
                    '${cards.length} shown',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<_StatusFilter>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: _StatusFilter.all,
                        label: Text('All'),
                      ),
                      ButtonSegment(
                        value: _StatusFilter.ready,
                        label: Text('Ready'),
                      ),
                      ButtonSegment(
                        value: _StatusFilter.needsTest,
                        label: Text('Needs test'),
                      ),
                      ButtonSegment(
                        value: _StatusFilter.reference,
                        label: Text('Reference'),
                      ),
                    ],
                    selected: {_statusFilter},
                    onSelectionChanged: (selection) {
                      setState(() => _statusFilter = selection.first);
                    },
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: DropdownButtonFormField<CardCategory?>(
                    initialValue: _category,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<CardCategory?>(
                        value: null,
                        child: Text('All categories'),
                      ),
                      ...CardCategory.values.map(
                        (category) => DropdownMenuItem<CardCategory?>(
                          value: category,
                          child: Text(category.label),
                        ),
                      ),
                    ],
                    onChanged: (value) => setState(() => _category = value),
                  ),
                ),
                const SizedBox(height: 12),
                if (cards.isEmpty)
                  _EmptyState(onAddCard: _openAddCardPicker)
                else ...[
                  for (var index = 0; index < cards.length; index++) ...[
                    CardTile(
                      card: cards[index],
                      onTap: () => _openCardActions(cards[index]),
                    ),
                    if (index != cards.length - 1) const SizedBox(height: 10),
                  ],
                ],
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            icon: const Icon(Icons.add),
            label: const Text('Add card'),
            onPressed: _openAddCardPicker,
          ),
        );
      },
    );
  }

  void _openAddCard(AddCardPreset preset) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EditCardScreen(
          repository: widget.repository,
          appLockService: widget.appLockService,
          preset: preset,
        ),
      ),
    );
  }

  Future<void> _openAddCardPicker() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'How do you want to add it?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                'Pick the path that matches the card you are holding. You can still edit everything afterward.',
              ),
              const SizedBox(height: 12),
              _AddPathTile(
                icon: Icons.qr_code_2,
                title: 'Barcode card',
                subtitle: 'Great for loyalty, library, and membership cards',
                onTap: () {
                  Navigator.of(context).pop();
                  _openAddCard(AddCardPreset.barcode);
                },
              ),
              _AddPathTile(
                icon: Icons.nfc,
                title: 'NFC / RFID card',
                subtitle: 'Save it first, then test what this phone can read',
                onTap: () {
                  Navigator.of(context).pop();
                  _openAddCard(AddCardPreset.nfc);
                },
              ),
              _AddPathTile(
                icon: Icons.badge_outlined,
                title: 'Reference card',
                subtitle: 'Photos and notes for cards that stay physical',
                onTap: () {
                  Navigator.of(context).pop();
                  _openAddCard(AddCardPreset.reference);
                },
              ),
              _AddPathTile(
                icon: Icons.add_card,
                title: 'General card',
                subtitle: 'Start blank and decide the details yourself',
                onTap: () {
                  Navigator.of(context).pop();
                  _openAddCard(AddCardPreset.general);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openCardActions(WalletCard card) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(card.name, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                card.issuer.isEmpty ? card.categoryLabel : card.issuer,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              if (card.hasBarcode)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.fullscreen),
                  title: const Text('Show code'),
                  subtitle: const Text(
                    'Open the full-screen barcode or QR view',
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(this.context).push(
                      MaterialPageRoute(
                        builder: (_) => BarcodePresentScreen(card: card),
                      ),
                    );
                  },
                ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit card'),
                subtitle: const Text('Update details, photos, notes, or codes'),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(this.context).push(
                    MaterialPageRoute(
                      builder: (_) => EditCardScreen(
                        repository: widget.repository,
                        appLockService: widget.appLockService,
                        existingCard: card,
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.visibility_outlined),
                title: const Text('View details'),
                subtitle: const Text('Open the full card detail screen'),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(this.context).push(
                    MaterialPageRoute(
                      builder: (_) => CardDetailScreen(
                        repository: widget.repository,
                        appLockService: widget.appLockService,
                        cardId: card.id,
                      ),
                    ),
                  );
                },
              ),
              if (!card.hasBarcode)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.nfc),
                  title: const Text('Test NFC / RFID'),
                  subtitle: const Text(
                    'Check whether this phone can read the card',
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(this.context).push(
                      MaterialPageRoute(
                        builder: (_) => CompatibilityTestScreen(
                          repository: widget.repository,
                          appLockService: widget.appLockService,
                          card: card,
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleMenuAction(_HomeMenuAction action) {
    switch (action) {
      case _HomeMenuAction.archived:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ArchivedCardsScreen(
              repository: widget.repository,
              appLockService: widget.appLockService,
            ),
          ),
        );
      case _HomeMenuAction.summary:
        _showWalletSummary();
      case _HomeMenuAction.backup:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ExportImportScreen(
              repository: widget.repository,
              appLockService: widget.appLockService,
            ),
          ),
        );
      case _HomeMenuAction.lock:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                AppLockSettingsScreen(appLockService: widget.appLockService),
          ),
        );
    }
  }

  List<WalletCard> _filteredCards(List<WalletCard> cards) {
    final normalizedQuery = _query.trim().toLowerCase();
    final filtered = cards.where((card) {
      final categoryMatches = _category == null || card.category == _category;
      final statusMatches = switch (_statusFilter) {
        _StatusFilter.all => true,
        _StatusFilter.ready =>
          card.compatibilityStatus == CompatibilityStatus.barcodeDisplayable ||
              card.compatibilityStatus == CompatibilityStatus.nfcReadable,
        _StatusFilter.needsTest =>
          card.compatibilityStatus == CompatibilityStatus.untested,
        _StatusFilter.reference =>
          card.compatibilityStatus == CompatibilityStatus.referenceOnly,
      };
      final queryMatches =
          normalizedQuery.isEmpty ||
          [
            card.name,
            card.issuer,
            card.categoryLabel,
            card.notes,
            card.barcodePayload,
          ].any((value) => value.toLowerCase().contains(normalizedQuery));
      return categoryMatches && statusMatches && queryMatches;
    }).toList();
    filtered.sort((a, b) {
      if (a.favorite != b.favorite) {
        return a.favorite ? -1 : 1;
      }
      if (a.hasBarcode != b.hasBarcode) {
        return a.hasBarcode ? -1 : 1;
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return filtered;
  }

  Future<void> _showWalletSummary() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: _CompactOverviewPanel(cards: widget.repository.cards),
        ),
      ),
    );
  }
}

enum _StatusFilter { all, ready, needsTest, reference }

enum _HomeMenuAction { archived, summary, backup, lock }

class _CompactOverviewPanel extends StatelessWidget {
  const _CompactOverviewPanel({required this.cards});

  final List<WalletCard> cards;

  @override
  Widget build(BuildContext context) {
    final readyToShow = cards.where((card) => card.hasBarcode).length;
    final nfcReadable = cards
        .where(
          (card) => card.compatibilityStatus == CompatibilityStatus.nfcReadable,
        )
        .length;
    final untested = cards
        .where(
          (card) => card.compatibilityStatus == CompatibilityStatus.untested,
        )
        .length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your wallet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              cards.isEmpty
                  ? 'Start with the cards you actually use every week.'
                  : '$readyToShow ready to show, $nfcReadable NFC-readable, $untested still untested.',
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _MetricTile(
                    label: 'Cards',
                    value: '${cards.length}',
                    icon: Icons.wallet_outlined,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MetricTile(
                    label: 'Ready',
                    value: '$readyToShow',
                    icon: Icons.qr_code_2,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MetricTile(
                    label: 'Need test',
                    value: '$untested',
                    icon: Icons.nfc,
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
        trailing ?? const SizedBox.shrink(),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: colors.primary),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAddCard});

  final VoidCallback onAddCard;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'No cards found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add a barcode card, NFC/RFID card, or a simple reference card with photos and notes.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onAddCard,
              icon: const Icon(Icons.add),
              label: const Text('Add your first card'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddPathTile extends StatelessWidget {
  const _AddPathTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(radius: 20, child: Icon(icon, size: 20)),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
