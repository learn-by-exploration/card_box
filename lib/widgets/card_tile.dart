import 'package:flutter/material.dart';

import 'package:card_box/models/compatibility_status.dart';
import 'package:card_box/models/wallet_card.dart';
import 'package:card_box/theme.dart';

enum CardTileLayout { list, grid }

class CardTile extends StatelessWidget {
  const CardTile({
    super.key,
    required this.card,
    required this.onTap,
    this.layout = CardTileLayout.list,
    this.onShowCode,
    this.onShowImages,
  });

  final WalletCard card;
  final VoidCallback onTap;
  final CardTileLayout layout;
  final VoidCallback? onShowCode;
  final VoidCallback? onShowImages;

  @override
  Widget build(BuildContext context) {
    return switch (layout) {
      CardTileLayout.list => _buildListTile(context),
      CardTileLayout.grid => _buildGridTile(context),
    };
  }

  Widget _buildListTile(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final tokens = CardBoxThemeTokens.of(context);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(tokens.radiusSmall),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(tokens.spaceMedium),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(tokens.radiusSmall),
                ),
                child: Icon(_iconForCard(), color: colors.onPrimaryContainer),
              ),
              SizedBox(width: tokens.spaceMedium),
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
                        if (card.favorite)
                          Icon(Icons.star, size: tokens.iconSmall),
                        if (card.favorite &&
                            (onShowCode != null || onShowImages != null))
                          SizedBox(width: tokens.spaceXSmall),
                        _QuickActionRow(
                          onShowCode: onShowCode,
                          onShowImages: onShowImages,
                        ),
                      ],
                    ),
                    SizedBox(height: tokens.spaceXSmall),
                    Text(
                      card.issuer.isEmpty
                          ? card.categoryLabel
                          : '${card.issuer} • ${card.categoryLabel}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: tokens.spaceSmall - 2),
                    Row(
                      children: [
                        Flexible(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: _MiniBadge(
                              label: _statusLabel(),
                              background: _statusTone(tokens).background,
                              foreground: _statusTone(tokens).foreground,
                            ),
                          ),
                        ),
                        SizedBox(width: tokens.spaceSmall),
                        Text(
                          card.hasBarcode
                              ? 'Tap for code'
                              : card.isVisitingCard
                              ? 'Tap for contact'
                              : 'Tap for actions',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGridTile(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final tokens = CardBoxThemeTokens.of(context);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(tokens.radiusSmall),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(tokens.spaceMedium),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      borderRadius: BorderRadius.circular(tokens.radiusSmall),
                    ),
                    child: Icon(
                      _iconForCard(),
                      color: colors.onPrimaryContainer,
                    ),
                  ),
                  const Spacer(),
                  _QuickActionRow(
                    onShowCode: onShowCode,
                    onShowImages: onShowImages,
                    compact: true,
                  ),
                  if ((onShowCode != null || onShowImages != null) &&
                      card.favorite)
                    SizedBox(width: tokens.spaceXSmall),
                  if (card.favorite)
                    Icon(Icons.star, size: tokens.iconSmall),
                ],
              ),
              SizedBox(height: tokens.spaceMedium),
              Text(
                card.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              SizedBox(height: tokens.spaceSmall - 2),
              Text(
                card.issuer.isEmpty ? card.categoryLabel : card.issuer,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _MiniBadge(
                    label: _statusLabel(),
                    background: _statusTone(tokens).background,
                    foreground: _statusTone(tokens).foreground,
                  ),
                ),
              ),
              SizedBox(height: tokens.spaceSmall),
              Text(
                _gridActionHint(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconForCard() {
    if (card.isVisitingCard) {
      return Icons.contact_page_outlined;
    }
    if (card.hasBarcode) {
      return Icons.qr_code_2;
    }
    if (card.hasPhotos) {
      return Icons.photo_library;
    }
    return Icons.badge;
  }

  String _statusLabel() {
    if (card.isVisitingCard) {
      return 'Contact saved';
    }
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

  String _gridActionHint() {
    if (card.hasBarcode) {
      return 'Code';
    }
    if (card.isVisitingCard) {
      return 'Contact';
    }
    return 'Card';
  }

  CardBoxStatusTone _statusTone(CardBoxThemeTokens tokens) {
    return tokens.statusToneFor(
      card.compatibilityStatus,
      isVisitingCard: card.isVisitingCard,
    );
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
        padding: EdgeInsets.symmetric(
          horizontal: CardBoxThemeTokens.of(context).spaceSmall,
          vertical: CardBoxThemeTokens.of(context).spaceXSmall,
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: foreground,
          ),
        ),
      ),
    );
  }
}

class _QuickActionRow extends StatelessWidget {
  const _QuickActionRow({
    required this.onShowCode,
    required this.onShowImages,
    this.compact = false,
  });

  final VoidCallback? onShowCode;
  final VoidCallback? onShowImages;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (onShowCode == null && onShowImages == null) {
      return const SizedBox.shrink();
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onShowCode != null)
          _QuickActionButton(
            tooltip: 'Show code',
            icon: Icons.qr_code_scanner_outlined,
            onPressed: onShowCode!,
            compact: compact,
          ),
        if (onShowImages != null)
          _QuickActionButton(
            tooltip: 'Show saved images',
            icon: Icons.photo_library_outlined,
            onPressed: onShowImages!,
            compact: compact,
          ),
      ],
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    required this.compact,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tokens = CardBoxThemeTokens.of(context);
    return SizedBox(
      width: compact ? 28 : 32,
      height: compact ? 28 : 32,
      child: IconButton(
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        iconSize: compact ? tokens.iconSmall : tokens.iconMedium,
        onPressed: onPressed,
        icon: Icon(icon),
      ),
    );
  }
}
