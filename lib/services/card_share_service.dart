import 'package:card_box/models/wallet_card.dart';
import 'package:card_box/services/backup_file_service.dart';
import 'package:card_box/services/file_share_service.dart';
import 'package:card_box/services/vcard_export_service.dart';

enum ShareCardResultStatus { shared, canceled, unavailable }

class ShareCardResult {
  const ShareCardResult({
    required this.status,
    this.message = '',
    this.fileName,
  });

  final ShareCardResultStatus status;
  final String message;
  final String? fileName;
}

class CardShareService {
  const CardShareService({
    BackupFileService? backupFileService,
    FileShareService? fileShareService,
    VCardExportService? vCardExportService,
  }) : _backupFileService = backupFileService ?? const BackupFileService(),
       _fileShareService = fileShareService ?? const FileShareService(),
       _vCardExportService = vCardExportService ?? const VCardExportService();

  final BackupFileService _backupFileService;
  final FileShareService _fileShareService;
  final VCardExportService _vCardExportService;

  Future<ShareCardResult> shareCard(WalletCard card) async {
    if (card.isVisitingCard) {
      return _shareVisitingCard(card);
    }

    final shareableImagePath = _shareableImagePath(card);
    if (shareableImagePath != null) {
      final shared = await _fileShareService.shareFile(
        path: shareableImagePath,
        subject: 'Share ${card.name}',
        text: _buildSummary(card),
      );
      return ShareCardResult(
        status: shared
            ? ShareCardResultStatus.shared
            : ShareCardResultStatus.canceled,
        message: shared ? 'Card shared.' : 'Share canceled.',
      );
    }

    final exported = await _backupFileService.createTextFile(
      content: _buildSummary(card),
      fileNamePrefix: _suggestedFileName(card),
      extension: 'txt',
    );
    if (exported == null) {
      return const ShareCardResult(
        status: ShareCardResultStatus.unavailable,
        message: 'Could not prepare a share file.',
      );
    }
    final shared = await _fileShareService.shareFile(
      path: exported.path,
      subject: 'Share ${card.name}',
      text: 'Shared from Card Box',
    );
    return ShareCardResult(
      status: shared
          ? ShareCardResultStatus.shared
          : ShareCardResultStatus.canceled,
      message: shared ? 'Card shared.' : 'Share canceled.',
      fileName: exported.fileName,
    );
  }

  Future<ShareCardResult> _shareVisitingCard(WalletCard card) async {
    final exported = await _backupFileService.createTextFile(
      content: _vCardExportService.buildVCard(card),
      fileNamePrefix: _vCardExportService.suggestedFileName(card),
      extension: 'vcf',
    );
    if (exported == null) {
      return const ShareCardResult(
        status: ShareCardResultStatus.unavailable,
        message: 'Could not prepare the contact for sharing.',
      );
    }
    final shared = await _fileShareService.shareFile(
      path: exported.path,
      subject: 'Share contact ${card.name}',
      text: 'Shared from Card Box',
    );
    return ShareCardResult(
      status: shared
          ? ShareCardResultStatus.shared
          : ShareCardResultStatus.canceled,
      message: shared ? 'Contact shared.' : 'Share canceled.',
      fileName: exported.fileName,
    );
  }

  String? _shareableImagePath(WalletCard card) {
    final barcodeImage = card.barcodeImagePath.trim();
    if (barcodeImage.isNotEmpty) {
      return barcodeImage;
    }
    final frontImage = card.frontImagePath.trim();
    if (frontImage.isNotEmpty) {
      return frontImage;
    }
    final backImage = card.backImagePath.trim();
    if (backImage.isNotEmpty) {
      return backImage;
    }
    return null;
  }

  String _buildSummary(WalletCard card) {
    final lines = <String>[
      card.name,
      if (card.issuer.trim().isNotEmpty) 'Issuer: ${card.issuer.trim()}',
      'Category: ${card.categoryLabel}',
      if (card.barcodePayload.trim().isNotEmpty)
        'Visible code: ${card.barcodePayload.trim()}',
      if (card.barcodeFormat.trim().isNotEmpty)
        'Code format: ${card.barcodeFormat.trim()}',
      if (card.nfcTagSummary.trim().isNotEmpty)
        'NFC/RFID: ${card.nfcTagSummary.trim()}',
      if (card.notes.trim().isNotEmpty) 'Notes: ${card.notes.trim()}',
    ];
    return lines.join('\n');
  }

  String _suggestedFileName(WalletCard card) {
    final sanitized = card.name
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return sanitized.isEmpty ? 'card_box_card' : 'card_box_$sanitized';
  }
}
