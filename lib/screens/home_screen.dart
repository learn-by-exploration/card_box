import 'package:flutter/material.dart';

import 'package:card_box/models/add_card_preset.dart';
import 'package:card_box/models/card_category.dart';
import 'package:card_box/models/compatibility_status.dart';
import 'package:card_box/models/wallet_card.dart';
import 'package:card_box/screens/archived_cards_screen.dart';
import 'package:card_box/screens/app_lock_settings_screen.dart';
import 'package:card_box/screens/card_detail_screen.dart';
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
              IconButton(
                tooltip: archivedCount == 0
                    ? 'Archived cards'
                    : 'Archived cards ($archivedCount)',
                icon: Badge.count(
                  isLabelVisible: archivedCount > 0,
                  count: archivedCount,
                  child: const Icon(Icons.archive_outlined),
                ),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ArchivedCardsScreen(
                      repository: widget.repository,
                      appLockService: widget.appLockService,
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'App lock',
                icon: Icon(
                  widget.appLockService.lockEnabled
                      ? Icons.lock_outline
                      : Icons.shield_outlined,
                ),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AppLockSettingsScreen(
                      appLockService: widget.appLockService,
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Export or import',
                icon: const Icon(Icons.ios_share),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ExportImportScreen(
                      repository: widget.repository,
                      appLockService: widget.appLockService,
                    ),
                  ),
                ),
              ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Column(
                    children: [
                      _OverviewPanel(cards: allCards),
                      const SizedBox(height: 12),
                      TextField(
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: 'Search cards, issuers, notes, or codes',
                        ),
                        onChanged: (value) => setState(() => _query = value),
                      ),
                      const SizedBox(height: 10),
                      _QuickActionRow(
                        onGeneral: () => _openAddCard(AddCardPreset.general),
                        onBarcode: () => _openAddCard(AddCardPreset.barcode),
                        onNfc: () => _openAddCard(AddCardPreset.nfc),
                        onReference: () =>
                            _openAddCard(AddCardPreset.reference),
                      ),
                      const SizedBox(height: 10),
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
                        height: 40,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            FilterChip(
                              label: const Text('All'),
                              selected: _category == null,
                              onSelected: (_) =>
                                  setState(() => _category = null),
                            ),
                            const SizedBox(width: 8),
                            for (final category in CardCategory.values) ...[
                              FilterChip(
                                label: Text(category.label),
                                selected: _category == category,
                                onSelected: (_) =>
                                    setState(() => _category = category),
                              ),
                              const SizedBox(width: 8),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: cards.isEmpty
                      ? _EmptyState(
                          onAddCard: () => _openAddCard(AddCardPreset.general),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                          itemBuilder: (context, index) {
                            final card = cards[index];
                            return CardTile(
                              card: card,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => CardDetailScreen(
                                    repository: widget.repository,
                                    appLockService: widget.appLockService,
                                    cardId: card.id,
                                  ),
                                ),
                              ),
                            );
                          },
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemCount: cards.length,
                        ),
                ),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            icon: const Icon(Icons.add),
            label: const Text('Add card'),
            onPressed: () => _openAddCard(AddCardPreset.general),
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

  List<WalletCard> _filteredCards(List<WalletCard> cards) {
    final normalizedQuery = _query.trim().toLowerCase();
    return cards.where((card) {
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
  }
}

enum _StatusFilter { all, ready, needsTest, reference }

class _OverviewPanel extends StatelessWidget {
  const _OverviewPanel({required this.cards});

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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE8F3F0), Color(0xFFF7EEE6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your everyday card wallet',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            cards.isEmpty
                ? 'Start by adding the cards you reach for most often.'
                : '$readyToShow ready to show, $nfcReadable NFC-readable, $untested still untested.',
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MetricTile(label: 'Cards', value: '${cards.length}'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricTile(label: 'Ready', value: '$readyToShow'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricTile(label: 'Need test', value: '$untested'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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

class _QuickActionRow extends StatelessWidget {
  const _QuickActionRow({
    required this.onGeneral,
    required this.onBarcode,
    required this.onNfc,
    required this.onReference,
  });

  final VoidCallback onGeneral;
  final VoidCallback onBarcode;
  final VoidCallback onNfc;
  final VoidCallback onReference;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          FilledButton.icon(
            onPressed: onBarcode,
            icon: const Icon(Icons.qr_code_2, size: 18),
            label: const Text('Barcode card'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: onNfc,
            icon: const Icon(Icons.nfc, size: 18),
            label: const Text('NFC / RFID card'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: onReference,
            icon: const Icon(Icons.badge, size: 18),
            label: const Text('Reference card'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: onGeneral,
            icon: const Icon(Icons.add_card, size: 18),
            label: const Text('General'),
          ),
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
