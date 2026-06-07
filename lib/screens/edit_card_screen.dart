import 'dart:async';

import 'package:flutter/material.dart';

import 'package:card_box/models/add_card_preset.dart';
import 'package:card_box/models/card_category.dart';
import 'package:card_box/models/card_type.dart';
import 'package:card_box/models/compatibility_status.dart';
import 'package:card_box/models/recovered_media_draft.dart';
import 'package:card_box/models/scanned_code.dart';
import 'package:card_box/models/wallet_card.dart';
import 'package:card_box/screens/barcode_scan_screen.dart';
import 'package:card_box/screens/card_image_viewer_screen.dart';
import 'package:card_box/screens/visiting_card_review_screen.dart';
import 'package:card_box/services/app_lock_service.dart';
import 'package:card_box/services/card_media_exception.dart';
import 'package:card_box/services/card_media_manager.dart';
import 'package:card_box/services/card_repository.dart';
import 'package:card_box/services/card_media_service.dart';
import 'package:card_box/services/category_service.dart';
import 'package:card_box/services/media_recovery_service.dart';
import 'package:card_box/services/visiting_card_ocr_service.dart';
import 'package:card_box/theme.dart';
import 'package:card_box/widgets/stored_card_image.dart';

class EditCardScreen extends StatefulWidget {
  const EditCardScreen({
    super.key,
    required this.repository,
    required this.appLockService,
    required this.categoryService,
    required this.mediaRecoveryService,
    this.existingCard,
    this.preset = AddCardPreset.general,
    this.recoveredMediaDraft,
    this.autoStartFrontScan = false,
  });

  final CardRepository repository;
  final AppLockService appLockService;
  final CategoryService categoryService;
  final MediaRecoveryService mediaRecoveryService;
  final WalletCard? existingCard;
  final AddCardPreset preset;
  final RecoveredMediaDraft? recoveredMediaDraft;
  final bool autoStartFrontScan;

  @override
  State<EditCardScreen> createState() => _EditCardScreenState();
}

class _EditCardScreenState extends State<EditCardScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _issuerController = TextEditingController();
  final _customCategoryController = TextEditingController();
  final _notesController = TextEditingController();
  final _barcodePayloadController = TextEditingController();
  final _barcodeFormatController = TextEditingController();
  final _contactTitleController = TextEditingController();
  final _contactPhonesController = TextEditingController();
  final _contactEmailsController = TextEditingController();
  final _contactWebsitesController = TextEditingController();
  final _contactAddressController = TextEditingController();
  final _mediaService = CardMediaService();
  final _mediaManager = const DefaultCardMediaManager();
  final _visitingCardOcrService = VisitingCardOcrService();

  CardCategory _category = CardCategory.loyalty;
  String _selectedCategoryKey = CardCategory.loyalty.name;
  CardType _cardType = CardType.standard;
  late String _draftCardId;
  String _frontImagePath = '';
  String _backImagePath = '';
  String _barcodeImagePath = '';
  String _initialFrontImagePath = '';
  String _initialBackImagePath = '';
  String _initialBarcodeImagePath = '';
  String _rawOcrText = '';
  String _barcodeDisplayValue = '';
  String _barcodeValueType = '';
  String _barcodeStructuredData = '';
  String _barcodeRawBytesHex = '';
  DateTime? _barcodeCapturedAt;
  String _barcodeMetadataPayload = '';
  String _barcodeMetadataFormat = '';
  bool _busyFrontCapture = false;
  bool _busyBackCapture = false;
  bool _extractingDetails = false;
  bool _saved = false;
  bool _didScheduleAutoFrontScan = false;

  @override
  void initState() {
    super.initState();
    _barcodePayloadController.addListener(_handleBarcodeFieldsEdited);
    _barcodeFormatController.addListener(_handleBarcodeFieldsEdited);
    final card = widget.existingCard;
    _draftCardId =
        widget.recoveredMediaDraft?.draftCardId ??
        card?.id ??
        'draft-${DateTime.now().microsecondsSinceEpoch}';
    if (card == null) {
      _applyPreset();
      _applyRecoveredMediaDraft();
      _scheduleAutoFrontScanIfNeeded();
      return;
    }
    _nameController.text = card.name;
    _issuerController.text = card.issuer;
    _customCategoryController.text = card.customCategory ?? '';
    _notesController.text = card.notes;
    _frontImagePath = card.frontImagePath;
    _backImagePath = card.backImagePath;
    _barcodeImagePath = card.barcodeImagePath;
    _initialFrontImagePath = card.frontImagePath;
    _initialBackImagePath = card.backImagePath;
    _initialBarcodeImagePath = card.barcodeImagePath;
    _barcodePayloadController.text = card.barcodePayload;
    _barcodeFormatController.text = card.barcodeFormat;
    _barcodeDisplayValue = card.barcodeDisplayValue;
    _barcodeValueType = card.barcodeValueType;
    _barcodeStructuredData = card.barcodeStructuredData;
    _barcodeRawBytesHex = card.barcodeRawBytesHex;
    _barcodeCapturedAt = card.barcodeCapturedAt;
    _barcodeMetadataPayload = card.barcodePayload.trim();
    _barcodeMetadataFormat = card.barcodeFormat.trim();
    _category = card.category;
    _selectedCategoryKey = _categorySelectionKeyForCard(card);
    _cardType = card.cardType;
    _contactTitleController.text = card.contactTitle;
    _contactPhonesController.text = card.contactPhones.join('\n');
    _contactEmailsController.text = card.contactEmails.join('\n');
    _contactWebsitesController.text = card.contactWebsites.join('\n');
    _contactAddressController.text = card.contactAddress;
    _rawOcrText = card.rawOcrText;
    _applyRecoveredMediaDraft();
    _scheduleAutoFrontScanIfNeeded();
  }

  @override
  void dispose() {
    if (!_saved) {
      _cleanupUnsavedMedia();
    }
    _nameController.dispose();
    _issuerController.dispose();
    _customCategoryController.dispose();
    _notesController.dispose();
    _barcodePayloadController.dispose();
    _barcodeFormatController.dispose();
    _contactTitleController.dispose();
    _contactPhonesController.dispose();
    _contactEmailsController.dispose();
    _contactWebsitesController.dispose();
    _contactAddressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existingCard != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _cardType == CardType.visitingCard
              ? (editing ? 'Edit visiting card' : 'Add visiting card')
              : (editing ? 'Edit card' : 'Add card'),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _AddFlowGuide(preset: widget.preset),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: _cardType == CardType.visitingCard
                    ? 'Person name'
                    : 'Card name',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return _cardType == CardType.visitingCard
                      ? 'Enter a person name'
                      : 'Enter a card name';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _issuerController,
              decoration: InputDecoration(
                labelText: _cardType == CardType.visitingCard
                    ? 'Company'
                    : 'Issuer',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _selectedCategoryKey,
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
              items: _categoryEntries(),
              onChanged: _handleCategorySelected,
            ),
            if (_category == CardCategory.other) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _customCategoryController,
                decoration: const InputDecoration(
                  labelText: 'Custom category',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (_category != CardCategory.other) {
                    return null;
                  }
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter a custom category';
                  }
                  return null;
                },
              ),
            ],
            const SizedBox(height: 18),
            _PermissionNote(
              icon: Icons.photo_camera,
              text:
                  'For the cleanest card image, start with Smart scan. You can still fall back to the camera or choose an existing image.',
            ),
            const SizedBox(height: 12),
            _PhotoEditor(
              title: 'Front photo',
              imagePath: _frontImagePath,
              busy: _busyFrontCapture,
              onScan: () => _startScanFlow(side: 'front'),
              onCapture: () => _startPhotoFlow(side: 'front', fromCamera: true),
              onLibrary: () =>
                  _startPhotoFlow(side: 'front', fromCamera: false),
              onEdit: _frontImagePath.isEmpty
                  ? null
                  : () => _editPhoto(side: 'front'),
              onClear: _frontImagePath.isEmpty
                  ? null
                  : () => _clearPhoto(side: 'front'),
            ),
            const SizedBox(height: 12),
            _PhotoEditor(
              title: 'Back photo',
              imagePath: _backImagePath,
              busy: _busyBackCapture,
              onScan: () => _startScanFlow(side: 'back'),
              onCapture: () => _startPhotoFlow(side: 'back', fromCamera: true),
              onLibrary: () => _startPhotoFlow(side: 'back', fromCamera: false),
              onEdit: _backImagePath.isEmpty
                  ? null
                  : () => _editPhoto(side: 'back'),
              onClear: _backImagePath.isEmpty
                  ? null
                  : () => _clearPhoto(side: 'back'),
            ),
            if (_cardType == CardType.visitingCard) ...[
              const SizedBox(height: 18),
              _PermissionNote(
                icon: Icons.manage_search,
                text:
                    'Use Extract details after adding at least the front image. Card Box will suggest contact fields, and you decide what to keep.',
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: _canExtractDetails
                      ? _extractVisitingCardDetails
                      : null,
                  icon: Icon(
                    _extractingDetails
                        ? Icons.hourglass_top
                        : Icons.auto_awesome,
                  ),
                  label: Text(
                    _extractingDetails ? 'Extracting...' : 'Extract details',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _contactTitleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _contactPhonesController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Phone numbers',
                  helperText: 'One phone number per line',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _contactEmailsController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Emails',
                  helperText: 'One email per line',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _contactWebsitesController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Websites',
                  helperText: 'One website per line',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _contactAddressController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Address',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            if (_cardType != CardType.visitingCard) ...[
              const SizedBox(height: 18),
              _PermissionNote(
                icon: Icons.qr_code_scanner,
                text:
                    'Barcode and QR scanning asks before using the camera. Manual entry still works when scanning is not practical.',
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: _startBarcodeScanFlow,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Scan code'),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _barcodePayloadController,
                decoration: const InputDecoration(
                  labelText: 'Barcode/QR payload',
                  helperText:
                      'A card can keep this visible code together with photos and NFC details.',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _barcodeFormatController,
                decoration: const InputDecoration(
                  labelText: 'Barcode/QR format',
                  border: OutlineInputBorder(),
                ),
              ),
              if (_hasStoredCodeMetadata) ...[
                const SizedBox(height: 12),
                _MetadataHintCard(
                  title: 'Stored code details',
                  lines: [
                    if (_barcodeDisplayValue.trim().isNotEmpty)
                      'Display value: ${_barcodeDisplayValue.trim()}',
                    if (_barcodeValueType.trim().isNotEmpty)
                      'Detected type: ${_humanizeBarcodeValueType(_barcodeValueType)}',
                    if (_barcodeStructuredData.trim().isNotEmpty)
                      'Structured details captured',
                    if (_barcodeRawBytesHex.trim().isNotEmpty)
                      'Raw bytes captured',
                    if (_barcodeCapturedAt != null)
                      'Scanned: ${_barcodeCapturedAt!.toLocal()}',
                  ],
                ),
                if (_barcodeImagePath.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _PhotoEditor(
                    title: 'Stored code image',
                    imagePath: _barcodeImagePath,
                    busy: false,
                    onScan: null,
                    onCapture: null,
                    onLibrary: null,
                    onEdit: null,
                    onClear: null,
                  ),
                ],
              ],
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesController,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Notes',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              icon: const Icon(Icons.save),
              label: const Text('Save card'),
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final customCategory = _category == CardCategory.other
        ? _customCategoryController.text.trim()
        : '';
    if (customCategory.isNotEmpty) {
      await widget.categoryService.addCategory(customCategory);
    }
    final existing = widget.existingCard;
    final now = DateTime.now();
    final hasBarcode = _barcodePayloadController.text.trim().isNotEmpty;
    final nextStatus = _nextCompatibilityStatus(
      existing: existing,
      hasBarcode: hasBarcode,
    );
    final card = WalletCard(
      id: existing?.id ?? 'card-${now.microsecondsSinceEpoch}',
      name: _nameController.text.trim(),
      issuer: _issuerController.text.trim(),
      category: _category,
      customCategory: customCategory.isEmpty ? null : customCategory,
      notes: _notesController.text.trim(),
      frontImagePath: _frontImagePath,
      backImagePath: _backImagePath,
      barcodeImagePath: _barcodeImagePath,
      barcodePayload: _barcodePayloadController.text.trim(),
      barcodeFormat: _barcodeFormatController.text.trim(),
      barcodeDisplayValue: _barcodeDisplayValue,
      barcodeValueType: _barcodeValueType,
      barcodeStructuredData: _barcodeStructuredData,
      barcodeRawBytesHex: _barcodeRawBytesHex,
      barcodeCapturedAt: _barcodeCapturedAt,
      compatibilityStatus: nextStatus,
      nfcTagSummary: existing?.nfcTagSummary ?? '',
      cardType: _cardType,
      rawOcrText: _rawOcrText,
      contactTitle: _contactTitleController.text.trim(),
      contactPhones: _splitLines(_contactPhonesController.text),
      contactEmails: _splitLines(_contactEmailsController.text),
      contactWebsites: _splitLines(_contactWebsitesController.text),
      contactAddress: _contactAddressController.text.trim(),
      favorite: existing?.favorite ?? false,
      archived: existing?.archived ?? false,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    await widget.repository.upsert(card);
    if (mounted) {
      _saved = true;
      Navigator.of(context).pop();
    }
  }

  bool get _canExtractDetails =>
      !_extractingDetails && _frontImagePath.trim().isNotEmpty;

  Future<void> _extractVisitingCardDetails() async {
    if (_frontImagePath.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add the front image first, then extract details.'),
        ),
      );
      return;
    }
    setState(() => _extractingDetails = true);
    try {
      final extraction = await _visitingCardOcrService.extractFromImages(
        frontImagePath: _frontImagePath,
        backImagePath: _backImagePath.trim().isEmpty ? null : _backImagePath,
      );
      if (!mounted) {
        return;
      }
      final reviewed = await Navigator.of(context)
          .push<VisitingCardReviewResult>(
            MaterialPageRoute(
              builder: (_) => VisitingCardReviewScreen(
                extraction: extraction,
                frontImagePath: _frontImagePath,
                backImagePath: _backImagePath,
                currentName: _nameController.text.trim(),
                currentCompany: _issuerController.text.trim(),
                currentTitle: _contactTitleController.text.trim(),
                currentPhones: _splitLines(_contactPhonesController.text),
                currentEmails: _splitLines(_contactEmailsController.text),
                currentWebsites: _splitLines(_contactWebsitesController.text),
                currentAddress: _contactAddressController.text.trim(),
              ),
            ),
          );
      if (reviewed == null || !mounted) {
        return;
      }
      setState(() {
        _nameController.text = reviewed.name;
        _issuerController.text = reviewed.company;
        _contactTitleController.text = reviewed.title;
        _contactPhonesController.text = reviewed.phones.join('\n');
        _contactEmailsController.text = reviewed.emails.join('\n');
        _contactWebsitesController.text = reviewed.websites.join('\n');
        _contactAddressController.text = reviewed.address;
        _rawOcrText = reviewed.rawOcrText;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not extract details: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _extractingDetails = false);
      }
    }
  }

  Future<void> _startPhotoFlow({
    required String side,
    required bool fromCamera,
  }) async {
    final approved = await _confirmInterfaceUse(
      title: fromCamera ? 'Use camera?' : 'Use photo library?',
      message: fromCamera
          ? 'Card Box will open the camera so you can capture the $side of this card.'
          : 'Card Box will open the photo library so you can choose the $side image for this card.',
      actionLabel: fromCamera ? 'Open camera' : 'Open library',
    );
    if (!approved) {
      return;
    }
    await _pickPhoto(side: side, fromCamera: fromCamera);
  }

  Future<void> _pickPhoto({
    required String side,
    required bool fromCamera,
  }) async {
    widget.appLockService.beginTrustedExternalFlow();
    setState(() {
      if (side == 'front') {
        _busyFrontCapture = true;
      } else {
        _busyBackCapture = true;
      }
    });
    try {
      await widget.mediaRecoveryService.markPendingPhotoRequest(
        draftCardId: _draftCardId,
        preset: widget.preset,
        side: side,
        existingCardId: widget.existingCard?.id,
      );
      final path = fromCamera
          ? await _mediaService.capturePhoto(cardId: _draftCardId, side: side)
          : await _mediaService.selectPhoto(cardId: _draftCardId, side: side);
      if (path == null || !mounted) {
        return;
      }
      final previousPath = side == 'front' ? _frontImagePath : _backImagePath;
      await _deleteIfTemporary(previousPath, side: side);
      setState(() {
        if (side == 'front') {
          _frontImagePath = path;
        } else {
          _backImagePath = path;
        }
      });
    } finally {
      await widget.mediaRecoveryService.clearPendingPhotoRequest();
      if (mounted) {
        setState(() {
          if (side == 'front') {
            _busyFrontCapture = false;
          } else {
            _busyBackCapture = false;
          }
        });
      }
      widget.appLockService.endTrustedExternalFlow();
    }
  }

  void _applyRecoveredMediaDraft() {
    final recovered = widget.recoveredMediaDraft;
    if (recovered == null) {
      return;
    }
    if (recovered.frontImagePath.isNotEmpty) {
      _frontImagePath = recovered.frontImagePath;
    }
    if (recovered.backImagePath.isNotEmpty) {
      _backImagePath = recovered.backImagePath;
    }
  }

  void _scheduleAutoFrontScanIfNeeded() {
    if (_didScheduleAutoFrontScan ||
        !widget.autoStartFrontScan ||
        widget.existingCard != null ||
        _cardType != CardType.visitingCard ||
        _frontImagePath.isNotEmpty) {
      return;
    }
    _didScheduleAutoFrontScan = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_startScanFlow(side: 'front'));
    });
  }

  Future<void> _startScanFlow({required String side}) async {
    final approved = await _confirmInterfaceUse(
      title: 'Use smart card scan?',
      message:
          'Card Box will open the guided card scanner for the $side of this card. If that scanner is unavailable on this device, Card Box will fall back to the camera and let you crop the image before saving it.',
      actionLabel: 'Start smart scan',
    );
    if (!approved) {
      return;
    }
    await _scanCardPhoto(side: side);
  }

  Future<void> _scanCardPhoto({required String side}) async {
    widget.appLockService.beginTrustedExternalFlow();
    setState(() {
      if (side == 'front') {
        _busyFrontCapture = true;
      } else {
        _busyBackCapture = true;
      }
    });
    try {
      await widget.mediaRecoveryService.markPendingPhotoRequest(
        draftCardId: _draftCardId,
        preset: widget.preset,
        side: side,
        existingCardId: widget.existingCard?.id,
      );
      final result = await _mediaService.scanCardPhoto(
        cardId: _draftCardId,
        side: side,
      );
      if (result == null || !mounted) {
        return;
      }
      final previousPath = side == 'front' ? _frontImagePath : _backImagePath;
      await _deleteIfTemporary(previousPath, side: side);
      setState(() {
        if (side == 'front') {
          _frontImagePath = result.path;
        } else {
          _backImagePath = result.path;
        }
      });
      final notice = result.noticeMessage?.trim();
      if (notice != null && notice.isNotEmpty && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(notice)));
      }
    } on CardMediaException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          action: SnackBarAction(
            label: 'Use camera',
            onPressed: () => _pickPhoto(side: side, fromCamera: true),
          ),
        ),
      );
    } finally {
      await widget.mediaRecoveryService.clearPendingPhotoRequest();
      if (mounted) {
        setState(() {
          if (side == 'front') {
            _busyFrontCapture = false;
          } else {
            _busyBackCapture = false;
          }
        });
      }
      widget.appLockService.endTrustedExternalFlow();
    }
  }

  Future<void> _startBarcodeScanFlow() async {
    final approved = await _confirmInterfaceUse(
      title: 'Use camera scanner?',
      message:
          'Card Box will open the camera to scan a visible barcode or QR code on this card.',
      actionLabel: 'Start scanner',
    );
    if (!approved) {
      return;
    }
    await _scanCode();
  }

  Future<void> _scanCode() async {
    widget.appLockService.beginTrustedExternalFlow();
    ScannedCode? result;
    try {
      result = await Navigator.of(context).push<ScannedCode>(
        MaterialPageRoute(builder: (_) => const BarcodeScanScreen()),
      );
    } finally {
      widget.appLockService.endTrustedExternalFlow();
    }
    if (result == null || !mounted) {
      return;
    }
    final scannedCode = result;
    final previousBarcodeImagePath = _barcodeImagePath;
    var nextBarcodeImagePath = '';
    if (scannedCode.imageBytes != null && scannedCode.imageBytes!.isNotEmpty) {
      nextBarcodeImagePath = await _mediaManager.storeImportedImage(
        cardId: _draftCardId,
        side: 'barcode',
        bytes: scannedCode.imageBytes!,
        extension: '.jpg',
      );
    }
    await _deleteIfTemporary(previousBarcodeImagePath, side: 'barcode');
    setState(() {
      _barcodePayloadController.text = scannedCode.payload;
      _barcodeFormatController.text = _formatLabel(scannedCode.format);
      _barcodeImagePath = nextBarcodeImagePath;
      _barcodeDisplayValue = scannedCode.displayValue.trim();
      _barcodeValueType = scannedCode.valueType.trim();
      _barcodeStructuredData = scannedCode.structuredData.trim();
      _barcodeRawBytesHex = scannedCode.rawBytesHex.trim();
      _barcodeCapturedAt = scannedCode.capturedAt;
      _barcodeMetadataPayload = scannedCode.payload.trim();
      _barcodeMetadataFormat = _formatLabel(scannedCode.format).trim();
    });
  }

  Future<void> _editPhoto({required String side}) async {
    final currentPath = side == 'front' ? _frontImagePath : _backImagePath;
    if (currentPath.isEmpty) {
      return;
    }
    widget.appLockService.beginTrustedExternalFlow();
    setState(() {
      if (side == 'front') {
        _busyFrontCapture = true;
      } else {
        _busyBackCapture = true;
      }
    });
    try {
      final editedPath = await _mediaService.editPhoto(
        existingPath: currentPath,
        cardId: _draftCardId,
        side: side,
      );
      if (editedPath == null || !mounted) {
        return;
      }
      await _deleteIfTemporary(currentPath, side: side);
      setState(() {
        if (side == 'front') {
          _frontImagePath = editedPath;
        } else {
          _backImagePath = editedPath;
        }
      });
    } on CardMediaException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          action: SnackBarAction(
            label: 'Choose again',
            onPressed: () => _pickPhoto(side: side, fromCamera: false),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          if (side == 'front') {
            _busyFrontCapture = false;
          } else {
            _busyBackCapture = false;
          }
        });
      }
      widget.appLockService.endTrustedExternalFlow();
    }
  }

  String _formatLabel(String rawFormat) {
    switch (rawFormat.toLowerCase()) {
      case 'qrCode':
      case 'qrcode':
        return 'QRCode';
      case 'ean13':
        return 'EAN13';
      case 'ean8':
        return 'EAN8';
      case 'upca':
        return 'UPCA';
      case 'upce':
        return 'UPCE';
      case 'code39':
        return 'Code39';
      case 'code93':
        return 'Code93';
      case 'code128':
        return 'Code128';
      default:
        return rawFormat;
    }
  }

  Future<bool> _confirmInterfaceUse({
    required String title,
    required String message,
    required String actionLabel,
  }) async {
    final decision = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
    return decision ?? false;
  }

  void _applyPreset() {
    switch (widget.preset) {
      case AddCardPreset.general:
        _cardType = CardType.standard;
        _category = CardCategory.loyalty;
        _selectedCategoryKey = CardCategory.loyalty.name;
        return;
      case AddCardPreset.barcode:
        _cardType = CardType.standard;
        _category = CardCategory.loyalty;
        _selectedCategoryKey = CardCategory.loyalty.name;
        return;
      case AddCardPreset.nfc:
        _cardType = CardType.standard;
        _category = CardCategory.access;
        _selectedCategoryKey = CardCategory.access.name;
        _notesController.text =
            'Use Compatibility test after saving to try NFC reading.';
        return;
      case AddCardPreset.reference:
        _cardType = CardType.standard;
        _category = CardCategory.id;
        _selectedCategoryKey = CardCategory.id.name;
        _notesController.text =
            'Reference card: save photos and notes even if the phone cannot read it.';
        return;
      case AddCardPreset.visiting:
        _cardType = CardType.visitingCard;
        _category = CardCategory.contact;
        _selectedCategoryKey = CardCategory.contact.name;
        _notesController.text =
            'Scan the card, extract likely contact details, and review them before saving.';
        return;
    }
  }

  String _categorySelectionKeyForCard(WalletCard card) {
    if (card.category == CardCategory.other &&
        card.customCategory?.trim().isNotEmpty == true) {
      return 'custom:${card.customCategory!.trim()}';
    }
    return card.category.name;
  }

  List<DropdownMenuItem<String>> _categoryEntries() {
    final customLabels = <String>{
      ...widget.categoryService.customCategories,
      if (_customCategoryController.text.trim().isNotEmpty)
        _customCategoryController.text.trim(),
    }.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return [
      ...CardCategory.values.map(
        (category) => DropdownMenuItem<String>(
          value: category.name,
          child: Text(category.label),
        ),
      ),
      ...customLabels.map(
        (label) => DropdownMenuItem<String>(
          value: 'custom:$label',
          child: Text(label),
        ),
      ),
      const DropdownMenuItem<String>(
        value: 'custom:new',
        child: Text('Create custom category'),
      ),
    ];
  }

  void _handleCategorySelected(String? value) {
    if (value == null) {
      return;
    }
    setState(() {
      _selectedCategoryKey = value;
      if (value == 'custom:new') {
        _category = CardCategory.other;
        if (_customCategoryController.text.trim().isEmpty) {
          _customCategoryController.clear();
        }
        return;
      }
      if (value.startsWith('custom:')) {
        _category = CardCategory.other;
        _customCategoryController.text = value.substring('custom:'.length);
        return;
      }
      _category = CardCategory.fromName(value);
    });
  }

  CompatibilityStatus _nextCompatibilityStatus({
    required WalletCard? existing,
    required bool hasBarcode,
  }) {
    if (_cardType == CardType.visitingCard) {
      return CompatibilityStatus.referenceOnly;
    }
    final existingStatus = existing?.compatibilityStatus;
    if (hasBarcode) {
      return switch (existingStatus) {
        null => CompatibilityStatus.barcodeDisplayable,
        CompatibilityStatus.untested ||
        CompatibilityStatus.referenceOnly ||
        CompatibilityStatus.unsupported ||
        CompatibilityStatus.barcodeDisplayable =>
          CompatibilityStatus.barcodeDisplayable,
        _ => existingStatus,
      };
    }
    if (existingStatus == CompatibilityStatus.barcodeDisplayable) {
      return CompatibilityStatus.untested;
    }
    if (existingStatus != null) {
      return existingStatus;
    }
    return CompatibilityStatus.untested;
  }

  List<String> _splitLines(String value) {
    return value
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }

  bool get _hasStoredCodeMetadata =>
      _barcodeImagePath.trim().isNotEmpty ||
      _barcodeDisplayValue.trim().isNotEmpty ||
      _barcodeValueType.trim().isNotEmpty ||
      _barcodeStructuredData.trim().isNotEmpty ||
      _barcodeRawBytesHex.trim().isNotEmpty ||
      _barcodeCapturedAt != null;

  void _handleBarcodeFieldsEdited() {
    if (!_hasStoredCodeMetadata) {
      _barcodeMetadataPayload = _barcodePayloadController.text.trim();
      _barcodeMetadataFormat = _barcodeFormatController.text.trim();
      return;
    }
    if (_barcodePayloadController.text.trim() == _barcodeMetadataPayload &&
        _barcodeFormatController.text.trim() == _barcodeMetadataFormat) {
      return;
    }
    final previousBarcodeImagePath = _barcodeImagePath;
    setState(() {
      _barcodeDisplayValue = '';
      _barcodeValueType = '';
      _barcodeStructuredData = '';
      _barcodeRawBytesHex = '';
      _barcodeCapturedAt = null;
      _barcodeImagePath = '';
      _barcodeMetadataPayload = _barcodePayloadController.text.trim();
      _barcodeMetadataFormat = _barcodeFormatController.text.trim();
    });
    unawaited(_deleteIfTemporary(previousBarcodeImagePath, side: 'barcode'));
  }

  String _humanizeBarcodeValueType(String valueType) {
    final normalized = valueType.trim();
    if (normalized.isEmpty) {
      return 'Unknown';
    }
    return normalized
        .replaceAllMapped(
          RegExp(r'([a-z0-9])([A-Z])'),
          (match) => '${match.group(1)} ${match.group(2)}',
        )
        .replaceAll('_', ' ')
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map(
          (part) =>
              '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
        )
        .join(' ');
  }

  Future<void> _clearPhoto({required String side}) async {
    final currentPath = side == 'front' ? _frontImagePath : _backImagePath;
    await _deleteIfTemporary(currentPath, side: side);
    if (!mounted) {
      return;
    }
    setState(() {
      if (side == 'front') {
        _frontImagePath = '';
      } else {
        _backImagePath = '';
      }
    });
  }

  Future<void> _deleteIfTemporary(String path, {required String side}) async {
    if (path.isEmpty) {
      return;
    }
    final initialPath = switch (side) {
      'front' => _initialFrontImagePath,
      'back' => _initialBackImagePath,
      'barcode' => _initialBarcodeImagePath,
      _ => '',
    };
    if (path != initialPath) {
      await _mediaManager.deleteImage(path);
    }
  }

  void _cleanupUnsavedMedia() {
    final futures = <Future<void>>[];
    if (_frontImagePath.isNotEmpty &&
        _frontImagePath != _initialFrontImagePath) {
      futures.add(_mediaManager.deleteImage(_frontImagePath));
    }
    if (_backImagePath.isNotEmpty && _backImagePath != _initialBackImagePath) {
      futures.add(_mediaManager.deleteImage(_backImagePath));
    }
    if (_barcodeImagePath.isNotEmpty &&
        _barcodeImagePath != _initialBarcodeImagePath) {
      futures.add(_mediaManager.deleteImage(_barcodeImagePath));
    }
    if (futures.isNotEmpty) {
      unawaited(Future.wait(futures));
    }
  }
}

class _PermissionNote extends StatelessWidget {
  const _PermissionNote({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = CardBoxThemeTokens.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: tokens.iconMedium,
          color: Theme.of(context).colorScheme.primary,
        ),
        SizedBox(width: tokens.spaceSmall),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodySmall),
        ),
      ],
    );
  }
}

class _MetadataHintCard extends StatelessWidget {
  const _MetadataHintCard({required this.title, required this.lines});

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final tokens = CardBoxThemeTokens.of(context);
    return Card(
      child: Padding(
        padding: EdgeInsets.all(tokens.spaceMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            SizedBox(height: tokens.spaceSmall),
            for (final line in lines)
              Padding(
                padding: EdgeInsets.only(bottom: tokens.spaceXSmall),
                child: Text(line),
              ),
          ],
        ),
      ),
    );
  }
}

class _AddFlowGuide extends StatelessWidget {
  const _AddFlowGuide({required this.preset});

  final AddCardPreset preset;

  @override
  Widget build(BuildContext context) {
    final tokens = CardBoxThemeTokens.of(context);
    return Card(
      child: Padding(
        padding: EdgeInsets.all(tokens.spaceLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'How to add a card',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            SizedBox(height: tokens.spaceMedium - 2),
            Text(_introText(), style: Theme.of(context).textTheme.bodySmall),
            SizedBox(height: tokens.spaceMedium - 2),
            const _GuideLine(
              step: '1',
              text: 'Enter the card name and category first.',
            ),
            SizedBox(height: tokens.spaceSmall),
            const _GuideLine(
              step: '2',
              text:
                  'Scan the front and back for cleaner edges, or add photos if that is easier.',
            ),
            SizedBox(height: tokens.spaceSmall),
            const _GuideLine(
              step: '3',
              text: 'Scan a visible barcode or QR code if the card has one.',
            ),
            SizedBox(height: tokens.spaceSmall),
            _GuideLine(step: '4', text: _stepFourText()),
            SizedBox(height: tokens.spaceSmall),
            const _GuideLine(
              step: '5',
              text:
                  'If the card is unsupported by phone hardware, keep it as a reference card with photos and notes.',
            ),
          ],
        ),
      ),
    );
  }

  String _introText() {
    switch (preset) {
      case AddCardPreset.general:
        return 'Start with the card basics, then use only the tools this card actually needs.';
      case AddCardPreset.barcode:
        return 'Best for loyalty, membership, library, and gift cards with visible codes.';
      case AddCardPreset.nfc:
        return 'Best for access, transit, or other tap-style cards. Save the record first, then test NFC.';
      case AddCardPreset.reference:
        return 'Best when the phone may not read the card at all and you mainly want photos and notes.';
      case AddCardPreset.visiting:
        return 'Best for business cards and contact cards. Scan the card, extract details, then review what should be saved.';
    }
  }

  String _stepFourText() {
    return switch (preset) {
      AddCardPreset.nfc =>
        'Save the card, then open Compatibility test to try NFC reading for supported cards.',
      AddCardPreset.visiting =>
        'Run Extract details after scanning so you can review suggested contact fields before saving.',
      _ =>
        'Save the card when the important details are in place. You can test compatibility later if needed.',
    };
  }
}

class _GuideLine extends StatelessWidget {
  const _GuideLine({required this.step, required this.text});

  final String step;
  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = CardBoxThemeTokens.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(tokens.radiusSmall - 2),
          ),
          child: Text(
            step,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        SizedBox(width: tokens.spaceMedium - 2),
        Expanded(child: Text(text)),
      ],
    );
  }
}

class _PhotoEditor extends StatelessWidget {
  const _PhotoEditor({
    required this.title,
    required this.imagePath,
    required this.busy,
    this.onScan,
    this.onCapture,
    this.onLibrary,
    this.onEdit,
    this.onClear,
  });

  final String title;
  final String imagePath;
  final bool busy;
  final VoidCallback? onScan;
  final VoidCallback? onCapture;
  final VoidCallback? onLibrary;
  final VoidCallback? onEdit;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final tokens = CardBoxThemeTokens.of(context);
    final canOpen = imagePath.trim().isNotEmpty;
    return Card(
      child: Padding(
        padding: EdgeInsets.all(tokens.spaceMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            SizedBox(height: tokens.spaceMedium - 2),
            InkWell(
              borderRadius: BorderRadius.circular(tokens.radiusSmall),
              onTap: canOpen
                  ? () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CardImageViewerScreen(
                          imagePath: imagePath,
                          title: title,
                        ),
                      ),
                    )
                  : null,
              child: AspectRatio(
                aspectRatio: 1.6,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: StoredCardImage(
                        path: imagePath,
                        emptyLabel: '$title not added',
                      ),
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
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.open_in_full,
                                  size: 14,
                                  color: Colors.white,
                                ),
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
            ),
            SizedBox(height: tokens.spaceMedium - 2),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (onScan != null)
                  FilledButton.icon(
                    onPressed: busy ? null : onScan,
                    icon: const Icon(Icons.document_scanner_outlined),
                    label: Text(busy ? 'Opening...' : 'Smart scan'),
                  ),
                if (onCapture != null)
                  OutlinedButton.icon(
                    onPressed: busy ? null : onCapture,
                    icon: const Icon(Icons.photo_camera),
                    label: const Text('Use camera'),
                  ),
                if (onLibrary != null)
                  OutlinedButton.icon(
                    onPressed: busy ? null : onLibrary,
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Choose photo'),
                  ),
                if (onEdit != null)
                  OutlinedButton.icon(
                    onPressed: busy ? null : onEdit,
                    icon: const Icon(Icons.crop_rotate),
                    label: const Text('Edit photo'),
                  ),
                if (onClear != null)
                  IconButton(
                    tooltip: 'Remove photo',
                    onPressed: onClear,
                    icon: const Icon(Icons.delete_outline),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
