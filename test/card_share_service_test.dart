// Tests for `CardShareService.shareCard`.
// The service has three branches: visiting card → vCard
// file, image-bearing non-visiting card → image share,
// text-only non-visiting card → text summary. The
// existing `models_and_service_unit_test.dart` covers
// the happy path. This file pins down the file-name
// derivation, the share cancellation path, and the
// image-selection priority (barcode > front > back).

import 'package:flutter_test/flutter_test.dart';

import 'package:card_box/models/card_category.dart';
import 'package:card_box/models/card_type.dart';
import 'package:card_box/models/exported_file_info.dart';
import 'package:card_box/models/wallet_card.dart';
import 'package:card_box/services/backup_file_service.dart';
import 'package:card_box/services/card_share_service.dart';
import 'package:card_box/services/file_share_service.dart';

class _FakeBackupFileService extends BackupFileService {
  _FakeBackupFileService({this.exportedFile});

  ExportedFileInfo? exportedFile;
  String? lastContent;
  String? lastPrefix;
  String? lastExtension;

  @override
  Future<ExportedFileInfo?> createTextFile({
    required String content,
    required String fileNamePrefix,
    required String extension,
  }) async {
    lastContent = content;
    lastPrefix = fileNamePrefix;
    lastExtension = extension;
    return exportedFile;
  }
}

class _FakeFileShareService extends FileShareService {
  _FakeFileShareService({required this.result});

  bool result;
  String? lastPath;
  String? lastSubject;
  String? lastText;

  @override
  Future<bool> shareFile({
    required String path,
    required String subject,
    String? text,
  }) async {
    lastPath = path;
    lastSubject = subject;
    lastText = text;
    return result;
  }
}

WalletCard visitingCard() => WalletCard(
  id: 'v1',
  name: 'Jane Doe',
  cardType: CardType.visitingCard,
  category: CardCategory.contact,
  contactPhones: const ['+1 555 123 4567'],
  contactEmails: const ['jane@example.test'],
  createdAt: DateTime.utc(2024, 1, 1),
  updatedAt: DateTime.utc(2024, 1, 1),
);

WalletCard loyaltyCard({
  String front = '',
  String back = '',
  String barcode = '',
}) => WalletCard(
  id: 'l1',
  name: 'ACME',
  cardType: CardType.standard,
  category: CardCategory.loyalty,
  frontImagePath: front,
  backImagePath: back,
  barcodeImagePath: barcode,
  barcodePayload: '1234',
  createdAt: DateTime.utc(2024, 1, 1),
  updatedAt: DateTime.utc(2024, 1, 1),
);

ExportedFileInfo _file(String name) => ExportedFileInfo(
  path: '/tmp/$name',
  fileName: name,
  createdAt: DateTime.utc(2024, 1, 1),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CardShareService.shareCard — visiting card branch', () {
    test('exports a vCard and reports the file name', () async {
      final backup = _FakeBackupFileService(
        exportedFile: _file('jane_doe.vcf'),
      );
      final share = _FakeFileShareService(result: true);
      final service = CardShareService(
        backupFileService: backup,
        fileShareService: share,
      );

      final result = await service.shareCard(visitingCard());

      expect(result.status, ShareCardResultStatus.shared);
      expect(result.fileName, 'jane_doe.vcf');
      // The vCard content was written to the temp file.
      expect(backup.lastExtension, 'vcf');
      expect(backup.lastPrefix, 'jane_doe');
      expect(backup.lastContent, contains('BEGIN:VCARD'));
      expect(share.lastPath, '/tmp/jane_doe.vcf');
      expect(share.lastSubject, 'Share contact Jane Doe');
    });

    test('returns canceled when the user dismisses the share sheet', () async {
      final backup = _FakeBackupFileService(
        exportedFile: _file('jane_doe.vcf'),
      );
      final share = _FakeFileShareService(result: false);
      // Inject the fakes via a custom service.
      final service = CardShareService(
        backupFileService: backup,
        fileShareService: share,
      );

      final result = await service.shareCard(visitingCard());

      expect(result.status, ShareCardResultStatus.canceled);
      expect(result.message, 'Share canceled.');
    });

    test('returns unavailable when the temp file cannot be created', () async {
      // The backup service returned null (e.g. disk full).
      // The service must NOT crash, and must return a
      // clear "unavailable" status.
      final backup = _FakeBackupFileService(exportedFile: null);
      final service = CardShareService(
        backupFileService: backup,
        fileShareService: _FakeFileShareService(result: true),
      );

      final result = await service.shareCard(visitingCard());

      expect(result.status, ShareCardResultStatus.unavailable);
      expect(result.message, contains('Could not prepare'));
    });
  });

  group('CardShareService.shareCard — image-bearing non-visiting card', () {
    test('prefers the barcode image over front and back', () async {
      // The selection order is barcode > front > back.
      // Even with all three set, the barcode is shared.
      final share = _FakeFileShareService(result: true);
      final service = CardShareService(fileShareService: share);
      final card = loyaltyCard(
        front: '/front.jpg',
        back: '/back.jpg',
        barcode: '/barcode.jpg',
      );

      final result = await service.shareCard(card);

      expect(result.status, ShareCardResultStatus.shared);
      expect(share.lastPath, '/barcode.jpg');
    });

    test(
      'falls back to the front image when no barcode image is set',
      () async {
        final share = _FakeFileShareService(result: true);
        final service = CardShareService(fileShareService: share);
        final card = loyaltyCard(front: '/front.jpg', back: '/back.jpg');

        await service.shareCard(card);

        expect(share.lastPath, '/front.jpg');
      },
    );

    test(
      'falls back to the back image when no barcode or front image is set',
      () async {
        final share = _FakeFileShareService(result: true);
        final service = CardShareService(fileShareService: share);
        final card = loyaltyCard(back: '/back.jpg');

        await service.shareCard(card);

        expect(share.lastPath, '/back.jpg');
      },
    );

    test('includes a text summary in the share intent', () async {
      // The image-bearing branch passes a text body to
      // the share sheet so the receiving app can preview
      // the card's metadata without opening the image.
      final share = _FakeFileShareService(result: true);
      final service = CardShareService(fileShareService: share);
      final card = loyaltyCard(front: '/front.jpg');

      await service.shareCard(card);

      expect(share.lastText, contains('Category:'));
      expect(share.lastText, contains('Visible code: 1234'));
      expect(share.lastSubject, 'Share ACME');
    });
  });

  group('CardShareService.shareCard — text-only non-visiting card', () {
    test('writes a .txt file with a sanitized card_box_ prefix', () async {
      final backup = _FakeBackupFileService(
        exportedFile: _file('card_box_acme.txt'),
      );
      final share = _FakeFileShareService(result: true);
      final service = CardShareService(
        backupFileService: backup,
        fileShareService: share,
      );

      final result = await service.shareCard(loyaltyCard());

      expect(result.status, ShareCardResultStatus.shared);
      expect(backup.lastExtension, 'txt');
      expect(backup.lastPrefix, 'card_box_acme');
      // The summary includes the name and category.
      expect(backup.lastContent, contains('ACME'));
      expect(backup.lastContent, contains('Category:'));
      expect(share.lastPath, '/tmp/card_box_acme.txt');
    });

    test('falls back to card_box_card when the name is empty', () async {
      final backup = _FakeBackupFileService(
        exportedFile: _file('card_box_card.txt'),
      );
      final share = _FakeFileShareService(result: true);
      final service = CardShareService(
        backupFileService: backup,
        fileShareService: share,
      );
      final card = WalletCard(
        id: 'x',
        name: '',
        cardType: CardType.standard,
        category: CardCategory.loyalty,
        createdAt: DateTime.utc(2024, 1, 1),
        updatedAt: DateTime.utc(2024, 1, 1),
      );

      await service.shareCard(card);

      expect(backup.lastPrefix, 'card_box_card');
    });

    test('returns unavailable when the temp file cannot be created', () async {
      final backup = _FakeBackupFileService(exportedFile: null);
      // Inject a different null-returning service:
      final svc = CardShareService(
        backupFileService: backup,
        fileShareService: _FakeFileShareService(result: true),
      );

      final result = await svc.shareCard(loyaltyCard());

      expect(result.status, ShareCardResultStatus.unavailable);
      expect(result.message, 'Could not prepare a share file.');
    });
  });
}
