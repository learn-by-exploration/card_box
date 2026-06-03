import 'package:flutter/material.dart';

import 'package:card_box/models/compatibility_status.dart';
import 'package:card_box/models/wallet_card.dart';

class CardTile extends StatelessWidget {
  const CardTile({super.key, required this.card, required this.onTap});

  final WalletCard card;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(_iconForCard(), color: colors.onPrimaryContainer),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            card.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (card.favorite) const Icon(Icons.star, size: 18),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      card.issuer.isEmpty
                          ? card.categoryLabel
                          : '${card.issuer} • ${card.categoryLabel}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _MiniBadge(
                          label: card.categoryLabel,
                          background: colors.primaryContainer,
                          foreground: colors.onPrimaryContainer,
                        ),
                        _MiniBadge(
                          label: _statusLabel(),
                          background: _statusBackground(colors),
                          foreground: _statusForeground(colors),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconForCard() {
    if (card.hasBarcode) {
      return Icons.qr_code_2;
    }
    if (card.hasPhotos) {
      return Icons.photo_library;
    }
    return Icons.badge;
  }

  String _statusLabel() {
    return switch (card.compatibilityStatus) {
      CompatibilityStatus.barcodeDisplayable => 'Ready to show',
      CompatibilityStatus.nfcReadable => 'NFC readable',
      CompatibilityStatus.referenceOnly => 'Reference',
      CompatibilityStatus.untested => 'Needs test',
      CompatibilityStatus.nfcDetectedNotReadable => 'Detected only',
      CompatibilityStatus.androidHceCandidate => 'Android candidate',
      CompatibilityStatus.unsupported => 'Unsupported',
    };
  }

  Color _statusBackground(ColorScheme colors) {
    return switch (card.compatibilityStatus) {
      CompatibilityStatus.barcodeDisplayable => const Color(0xFFE8F5E9),
      CompatibilityStatus.nfcReadable => const Color(0xFFE4F2FF),
      CompatibilityStatus.referenceOnly => const Color(0xFFF3EEE8),
      CompatibilityStatus.untested => const Color(0xFFFFF3E0),
      CompatibilityStatus.nfcDetectedNotReadable => const Color(0xFFFFF4E5),
      CompatibilityStatus.androidHceCandidate => const Color(0xFFECEAF7),
      CompatibilityStatus.unsupported => const Color(0xFFFDECEC),
    };
  }

  Color _statusForeground(ColorScheme colors) {
    return switch (card.compatibilityStatus) {
      CompatibilityStatus.barcodeDisplayable => const Color(0xFF1B5E20),
      CompatibilityStatus.nfcReadable => const Color(0xFF0D47A1),
      CompatibilityStatus.referenceOnly => const Color(0xFF6D4C41),
      CompatibilityStatus.untested => const Color(0xFF8A5200),
      CompatibilityStatus.nfcDetectedNotReadable => const Color(0xFF8A5200),
      CompatibilityStatus.androidHceCandidate => const Color(0xFF4A3C88),
      CompatibilityStatus.unsupported => const Color(0xFF8E1B1B),
    };
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: foreground,
          ),
        ),
      ),
    );
  }
}
