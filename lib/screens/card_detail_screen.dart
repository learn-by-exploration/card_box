import 'package:flutter/material.dart';

import 'package:card_box/models/compatibility_status.dart';
import 'package:card_box/models/wallet_card.dart';
import 'package:card_box/screens/barcode_present_screen.dart';
import 'package:card_box/screens/compatibility_test_screen.dart';
import 'package:card_box/screens/edit_card_screen.dart';
import 'package:card_box/services/app_lock_service.dart';
import 'package:card_box/services/card_repository.dart';
import 'package:card_box/widgets/barcode_preview.dart';
import 'package:card_box/widgets/stored_card_image.dart';

class CardDetailScreen extends StatelessWidget {
  const CardDetailScreen({
    super.key,
    required this.repository,
    required this.appLockService,
    required this.cardId,
  });

  final CardRepository repository;
  final AppLockService appLockService;
  final String cardId;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: repository,
      builder: (context, _) {
        final card = repository.findById(cardId);
        if (card == null) {
          return const Scaffold(body: Center(child: Text('Card not found')));
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(card.name),
            actions: [
              IconButton(
                tooltip: card.favorite ? 'Remove favorite' : 'Favorite',
                icon: Icon(card.favorite ? Icons.star : Icons.star_border),
                onPressed: () => repository.toggleFavorite(card.id),
              ),
              IconButton(
                tooltip: 'Edit',
                icon: const Icon(Icons.edit),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => EditCardScreen(
                      repository: repository,
                      appLockService: appLockService,
                      existingCard: card,
                    ),
                  ),
                ),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              _ActionHeader(
                card: card,
                repository: repository,
                appLockService: appLockService,
              ),
              const SizedBox(height: 12),
              _PhotoStrip(card: card),
              const SizedBox(height: 12),
              _StatusCard(card: card),
              const SizedBox(height: 12),
              if (card.hasBarcode) _BarcodePanel(card: card),
              if (card.hasBarcode) const SizedBox(height: 12),
              _InfoPanel(card: card),
              const SizedBox(height: 8),
              if (!card.archived)
                OutlinedButton.icon(
                  icon: const Icon(Icons.archive),
                  label: const Text('Archive card'),
                  onPressed: () async {
                    await repository.archive(card.id);
                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                )
              else
                Column(
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.unarchive_outlined),
                      label: const Text('Restore card'),
                      onPressed: () => repository.unarchive(card.id),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Delete permanently'),
                      onPressed: () => _confirmDelete(context, card),
                    ),
                  ],
                ),
            ],
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
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    }
  }
}

class _ActionHeader extends StatelessWidget {
  const _ActionHeader({
    required this.card,
    required this.repository,
    required this.appLockService,
  });

  final WalletCard card;
  final CardRepository repository;
  final AppLockService appLockService;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'What you can do now',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Text(_summaryText()),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (card.hasBarcode)
                  FilledButton.icon(
                    icon: const Icon(Icons.fullscreen),
                    label: const Text('Present code'),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => BarcodePresentScreen(card: card),
                      ),
                    ),
                  ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.sensors),
                  label: Text(
                    card.compatibilityStatus == CompatibilityStatus.untested
                        ? 'Test NFC/RFID'
                        : 'Retest NFC/RFID',
                  ),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CompatibilityTestScreen(
                        repository: repository,
                        appLockService: appLockService,
                        card: card,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _summaryText() {
    if (card.hasBarcode) {
      return 'This card is ready to be shown on screen, and you can still test NFC/RFID compatibility if needed.';
    }
    if (card.compatibilityStatus == CompatibilityStatus.nfcReadable) {
      return 'This card has readable NFC data. Keep the saved summary and retest any time.';
    }
    if (card.compatibilityStatus == CompatibilityStatus.androidHceCandidate) {
      return 'This card exposed ISO-DEP style behavior, so it may be worth later Android-only emulation research. It is not emulated by Card Box today.';
    }
    if (card.compatibilityStatus == CompatibilityStatus.referenceOnly) {
      return 'Use this as a quick visual reference and keep the physical card with you.';
    }
    return 'Use compatibility testing to learn whether this phone can read anything useful from the card.';
  }
}

class _PhotoStrip extends StatelessWidget {
  const _PhotoStrip({required this.card});

  final WalletCard card;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _PhotoPlaceholder(
            label: 'Front photo',
            value: card.frontImagePath,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _PhotoPlaceholder(
            label: 'Back photo',
            value: card.backImagePath,
          ),
        ),
      ],
    );
  }
}

class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.6,
      child: StoredCardImage(path: value, emptyLabel: label),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.card});

  final WalletCard card;

  @override
  Widget build(BuildContext context) {
    final status = card.compatibilityStatus;
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(_icon(status), color: colors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    status.label,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Text(status.description),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _icon(CompatibilityStatus status) {
    return switch (status) {
      CompatibilityStatus.barcodeDisplayable => Icons.qr_code_2,
      CompatibilityStatus.nfcReadable => Icons.nfc,
      CompatibilityStatus.androidHceCandidate => Icons.android,
      CompatibilityStatus.unsupported => Icons.block,
      CompatibilityStatus.referenceOnly => Icons.description,
      CompatibilityStatus.nfcDetectedNotReadable => Icons.warning_amber,
      CompatibilityStatus.untested => Icons.help_outline,
    };
  }
}

class _BarcodePanel extends StatelessWidget {
  const _BarcodePanel({required this.card});

  final WalletCard card;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Presentation',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            Container(
              height: 148,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFE1E7E5)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: BarcodePreview(
                data: card.barcodePayload,
                format: card.barcodeFormat,
                height: 120,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              card.barcodeFormat.isEmpty
                  ? 'Barcode/QR payload'
                  : card.barcodeFormat,
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({required this.card});

  final WalletCard card;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InfoRow(label: 'Category', value: card.categoryLabel),
            _InfoRow(
              label: 'Issuer',
              value: card.issuer.isEmpty ? 'Not set' : card.issuer,
            ),
            _InfoRow(
              label: 'NFC summary',
              value: card.nfcTagSummary.isEmpty
                  ? 'Not tested'
                  : card.nfcTagSummary,
            ),
            _InfoRow(
              label: 'Notes',
              value: card.notes.isEmpty ? 'No notes' : card.notes,
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(value),
        ],
      ),
    );
  }
}
