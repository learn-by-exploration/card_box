import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:card_box/models/compatibility_status.dart';
import 'package:card_box/models/wallet_card.dart';
import 'package:card_box/screens/barcode_present_screen.dart';
import 'package:card_box/screens/card_image_viewer_screen.dart';
import 'package:card_box/screens/compatibility_test_screen.dart';
import 'package:card_box/screens/edit_card_screen.dart';
import 'package:card_box/services/app_lock_service.dart';
import 'package:card_box/services/backup_file_service.dart';
import 'package:card_box/services/card_repository.dart';
import 'package:card_box/services/contact_action_service.dart';
import 'package:card_box/services/vcard_export_service.dart';
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
  final BackupFileService _fileService = const BackupFileService();
  final ContactActionService _contactActionService =
      const ContactActionService();
  final VCardExportService _vCardExportService = const VCardExportService();

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
                if (card.isVisitingCard)
                  FilledButton.icon(
                    icon: const Icon(Icons.copy_all_outlined),
                    label: const Text('Copy contact'),
                    onPressed: () => _copyContactBlock(context),
                  ),
                if (card.isVisitingCard && card.contactPhones.isNotEmpty)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.call_outlined),
                    label: const Text('Call'),
                    onPressed: () => _launchContactValue(
                      context,
                      title: 'Choose phone number',
                      values: card.contactPhones,
                      uriBuilder: _contactActionService.phoneUri,
                      unsupportedMessage: 'This phone number cannot be opened.',
                    ),
                  ),
                if (card.isVisitingCard && card.contactEmails.isNotEmpty)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.email_outlined),
                    label: const Text('Email'),
                    onPressed: () => _launchContactValue(
                      context,
                      title: 'Choose email address',
                      values: card.contactEmails,
                      uriBuilder: _contactActionService.emailUri,
                      unsupportedMessage:
                          'This email address cannot be opened.',
                    ),
                  ),
                if (card.isVisitingCard && card.contactWebsites.isNotEmpty)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.language_outlined),
                    label: const Text('Website'),
                    onPressed: () => _launchContactValue(
                      context,
                      title: 'Choose website',
                      values: card.contactWebsites,
                      uriBuilder: _contactActionService.websiteUri,
                      unsupportedMessage: 'This website cannot be opened.',
                    ),
                  ),
                if (card.isVisitingCard)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.perm_contact_calendar_outlined),
                    label: const Text('Export vCard'),
                    onPressed: () => _exportVCard(context),
                  ),
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
                if (!card.isVisitingCard)
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
    if (card.isVisitingCard) {
      return 'This visiting card keeps the original scan and the contact details together. Open Edit any time to re-extract or refine the saved fields.';
    }
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

  Future<void> _copyContactBlock(BuildContext context) async {
    final lines = <String>[
      card.name,
      if (card.issuer.isNotEmpty) card.issuer,
      if (card.contactTitle.isNotEmpty) card.contactTitle,
      ...card.contactPhones,
      ...card.contactEmails,
      ...card.contactWebsites,
      if (card.contactAddress.isNotEmpty) card.contactAddress,
      if (card.notes.isNotEmpty) card.notes,
    ];
    await Clipboard.setData(ClipboardData(text: lines.join('\n')));
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Contact details copied')));
    }
  }

  Future<void> _exportVCard(BuildContext context) async {
    try {
      appLockService.beginTrustedExternalFlow();
      final fileInfo = await _fileService.createTextFile(
        content: _vCardExportService.buildVCard(card),
        fileNamePrefix: _vCardExportService.suggestedFileName(card),
        extension: 'vcf',
      );
      if (!context.mounted) {
        return;
      }
      if (fileInfo == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('vCard export canceled')));
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('vCard saved as ${fileInfo.fileName}')),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not export vCard: $error')));
    } finally {
      appLockService.endTrustedExternalFlow();
    }
  }

  Future<void> _launchContactValue(
    BuildContext context, {
    required String title,
    required List<String> values,
    required Uri? Function(String value) uriBuilder,
    required String unsupportedMessage,
  }) async {
    final selected = await _pickContactValue(
      context,
      title: title,
      values: values,
    );
    if (selected == null || !context.mounted) {
      return;
    }
    final uri = uriBuilder(selected);
    if (uri == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(unsupportedMessage)));
      return;
    }
    try {
      appLockService.beginTrustedExternalFlow();
      final opened = await _contactActionService.open(uri);
      if (!opened && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(unsupportedMessage)));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not open link: $error')));
      }
    } finally {
      appLockService.endTrustedExternalFlow();
    }
  }

  Future<String?> _pickContactValue(
    BuildContext context, {
    required String title,
    required List<String> values,
  }) async {
    final cleanValues = values
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
    if (cleanValues.isEmpty) {
      return null;
    }
    if (cleanValues.length == 1) {
      return cleanValues.first;
    }
    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              for (final value in cleanValues)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(value),
                  onTap: () => Navigator.of(sheetContext).pop(value),
                ),
            ],
          ),
        ),
      ),
    );
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
            cardName: card.name,
            label: 'Front photo',
            value: card.frontImagePath,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _PhotoPlaceholder(
            cardName: card.name,
            label: 'Back photo',
            value: card.backImagePath,
          ),
        ),
      ],
    );
  }
}

class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder({
    required this.cardName,
    required this.label,
    required this.value,
  });

  final String cardName;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final canOpen = value.trim().isNotEmpty;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: canOpen
          ? () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => CardImageViewerScreen(
                  imagePath: value,
                  title: '$cardName • $label',
                ),
              ),
            )
          : null,
      child: AspectRatio(
        aspectRatio: 1.6,
        child: Stack(
          children: [
            Positioned.fill(
              child: StoredCardImage(path: value, emptyLabel: label),
            ),
            if (canOpen)
              Positioned(
                right: 8,
                bottom: 8,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.62),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.open_in_full, size: 14, color: Colors.white),
                        SizedBox(width: 4),
                        Text(
                          'Open',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
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
    final label = card.isVisitingCard ? 'Contact saved' : status.label;
    final description = card.isVisitingCard
        ? 'This visiting card is saved with its images and extracted contact details.'
        : status.description;
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
                    label,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Text(description),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _icon(CompatibilityStatus status) {
    if (card.isVisitingCard) {
      return Icons.contact_page_outlined;
    }
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
            _buildInfoRow(
              context,
              label: 'Issuer',
              value: card.issuer.isEmpty ? 'Not set' : card.issuer,
              copyValue: card.issuer,
            ),
            if (card.isVisitingCard) ...[
              _buildInfoRow(
                context,
                label: 'Title',
                value: card.contactTitle.isEmpty
                    ? 'Not set'
                    : card.contactTitle,
                copyValue: card.contactTitle,
              ),
              _buildInfoRow(
                context,
                label: 'Phone numbers',
                value: card.contactPhones.isEmpty
                    ? 'Not set'
                    : card.contactPhones.join('\n'),
                copyValue: card.contactPhones.join('\n'),
              ),
              _buildInfoRow(
                context,
                label: 'Emails',
                value: card.contactEmails.isEmpty
                    ? 'Not set'
                    : card.contactEmails.join('\n'),
                copyValue: card.contactEmails.join('\n'),
              ),
              _buildInfoRow(
                context,
                label: 'Websites',
                value: card.contactWebsites.isEmpty
                    ? 'Not set'
                    : card.contactWebsites.join('\n'),
                copyValue: card.contactWebsites.join('\n'),
              ),
              _buildInfoRow(
                context,
                label: 'Address',
                value: card.contactAddress.isEmpty
                    ? 'Not set'
                    : card.contactAddress,
                copyValue: card.contactAddress,
              ),
              if (card.rawOcrText.isNotEmpty)
                _buildInfoRow(
                  context,
                  label: 'Extracted text',
                  value: card.rawOcrText,
                  copyValue: card.rawOcrText,
                ),
            ] else ...[
              _InfoRow(
                label: 'NFC summary',
                value: card.nfcTagSummary.isEmpty
                    ? 'Not tested'
                    : card.nfcTagSummary,
              ),
            ],
            _InfoRow(
              label: 'Notes',
              value: card.notes.isEmpty ? 'No notes' : card.notes,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context, {
    required String label,
    required String value,
    required String copyValue,
  }) {
    final trimmedCopy = copyValue.trim();
    if (trimmedCopy.isEmpty) {
      return _InfoRow(label: label, value: value);
    }
    return _CopyableInfoRow(
      label: label,
      value: value,
      onCopy: () async {
        await Clipboard.setData(ClipboardData(text: trimmedCopy));
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('$label copied')));
        }
      },
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

class _CopyableInfoRow extends StatelessWidget {
  const _CopyableInfoRow({
    required this.label,
    required this.value,
    required this.onCopy,
  });

  final String label;
  final String value;
  final Future<void> Function() onCopy;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Copy $label',
                onPressed: onCopy,
                icon: const Icon(Icons.copy_rounded, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(value),
        ],
      ),
    );
  }
}
