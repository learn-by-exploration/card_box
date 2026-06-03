import 'package:flutter/material.dart';

import 'package:card_box/models/add_card_preset.dart';
import 'package:card_box/models/card_category.dart';
import 'package:card_box/models/compatibility_status.dart';
import 'package:card_box/models/scanned_code.dart';
import 'package:card_box/models/wallet_card.dart';
import 'package:card_box/screens/barcode_scan_screen.dart';
import 'package:card_box/services/app_lock_service.dart';
import 'package:card_box/services/card_media_manager.dart';
import 'package:card_box/services/card_repository.dart';
import 'package:card_box/services/card_media_service.dart';
import 'package:card_box/widgets/stored_card_image.dart';

class EditCardScreen extends StatefulWidget {
  const EditCardScreen({
    super.key,
    required this.repository,
    required this.appLockService,
    this.existingCard,
    this.preset = AddCardPreset.general,
  });

  final CardRepository repository;
  final AppLockService appLockService;
  final WalletCard? existingCard;
  final AddCardPreset preset;

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
  final _mediaService = CardMediaService();
  final _mediaManager = const DefaultCardMediaManager();

  CardCategory _category = CardCategory.loyalty;
  late String _draftCardId;
  String _frontImagePath = '';
  String _backImagePath = '';
  String _initialFrontImagePath = '';
  String _initialBackImagePath = '';
  bool _busyFrontCapture = false;
  bool _busyBackCapture = false;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    final card = widget.existingCard;
    _draftCardId = card?.id ?? 'draft-${DateTime.now().microsecondsSinceEpoch}';
    if (card == null) {
      _applyPreset();
      return;
    }
    _nameController.text = card.name;
    _issuerController.text = card.issuer;
    _customCategoryController.text = card.customCategory ?? '';
    _notesController.text = card.notes;
    _frontImagePath = card.frontImagePath;
    _backImagePath = card.backImagePath;
    _initialFrontImagePath = card.frontImagePath;
    _initialBackImagePath = card.backImagePath;
    _barcodePayloadController.text = card.barcodePayload;
    _barcodeFormatController.text = card.barcodeFormat;
    _category = card.category;
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existingCard != null;
    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'Edit card' : 'Add card')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _AddFlowGuide(preset: widget.preset),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Card name',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Enter a card name';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _issuerController,
              decoration: const InputDecoration(
                labelText: 'Issuer',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<CardCategory>(
              initialValue: _category,
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
              items: CardCategory.values
                  .map(
                    (category) => DropdownMenuItem(
                      value: category,
                      child: Text(category.label),
                    ),
                  )
                  .toList(),
              onChanged: (value) =>
                  setState(() => _category = value ?? CardCategory.other),
            ),
            if (_category == CardCategory.other) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _customCategoryController,
                decoration: const InputDecoration(
                  labelText: 'Custom category',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 18),
            _PermissionNote(
              icon: Icons.photo_camera,
              text:
                  'For the cleanest card image, start with Scan card. You can still fall back to the camera or choose an existing image.',
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
      customCategory: _category == CardCategory.other
          ? _customCategoryController.text.trim()
          : null,
      notes: _notesController.text.trim(),
      frontImagePath: _frontImagePath,
      backImagePath: _backImagePath,
      barcodePayload: _barcodePayloadController.text.trim(),
      barcodeFormat: _barcodeFormatController.text.trim(),
      compatibilityStatus: nextStatus,
      nfcTagSummary: existing?.nfcTagSummary ?? '',
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

  Future<void> _startScanFlow({required String side}) async {
    final approved = await _confirmInterfaceUse(
      title: 'Scan card with edge detection?',
      message:
          'Card Box will open a card scanning interface and try to capture a cleaner, flatter image of the $side of this card.',
      actionLabel: 'Start scan',
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
      final path = await _mediaService.scanCardPhoto(
        cardId: _draftCardId,
        side: side,
      );
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
    setState(() {
      _barcodePayloadController.text = scannedCode.payload;
      _barcodeFormatController.text = _formatLabel(scannedCode.format);
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
        _category = CardCategory.loyalty;
        return;
      case AddCardPreset.barcode:
        _category = CardCategory.loyalty;
        return;
      case AddCardPreset.nfc:
        _category = CardCategory.access;
        _notesController.text =
            'Use Compatibility test after saving to try NFC reading.';
        return;
      case AddCardPreset.reference:
        _category = CardCategory.id;
        _notesController.text =
            'Reference card: save photos and notes even if the phone cannot read it.';
        return;
    }
  }

  CompatibilityStatus _nextCompatibilityStatus({
    required WalletCard? existing,
    required bool hasBarcode,
  }) {
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
    final initialPath = side == 'front'
        ? _initialFrontImagePath
        : _initialBackImagePath;
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
    if (futures.isNotEmpty) {
      Future.wait(futures);
    }
  }
}

class _PermissionNote extends StatelessWidget {
  const _PermissionNote({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
      ],
    );
  }
}

class _AddFlowGuide extends StatelessWidget {
  const _AddFlowGuide({required this.preset});

  final AddCardPreset preset;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'How to add a card',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Text(_introText(), style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 10),
            const _GuideLine(
              step: '1',
              text: 'Enter the card name and category first.',
            ),
            const SizedBox(height: 8),
            const _GuideLine(
              step: '2',
              text:
                  'Scan the front and back for cleaner edges, or add photos if that is easier.',
            ),
            const SizedBox(height: 8),
            const _GuideLine(
              step: '3',
              text: 'Scan a visible barcode or QR code if the card has one.',
            ),
            const SizedBox(height: 8),
            _GuideLine(step: '4', text: _stepFourText()),
            const SizedBox(height: 8),
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
    }
  }

  String _stepFourText() {
    return switch (preset) {
      AddCardPreset.nfc =>
        'Save the card, then open Compatibility test to try NFC reading for supported cards.',
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            step,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 10),
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
    required this.onScan,
    required this.onCapture,
    required this.onLibrary,
    this.onEdit,
    this.onClear,
  });

  final String title;
  final String imagePath;
  final bool busy;
  final VoidCallback onScan;
  final VoidCallback onCapture;
  final VoidCallback onLibrary;
  final VoidCallback? onEdit;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            AspectRatio(
              aspectRatio: 1.6,
              child: StoredCardImage(
                path: imagePath,
                emptyLabel: '$title not added',
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: busy ? null : onScan,
                  icon: const Icon(Icons.document_scanner_outlined),
                  label: Text(busy ? 'Opening...' : 'Scan card'),
                ),
                OutlinedButton.icon(
                  onPressed: busy ? null : onCapture,
                  icon: const Icon(Icons.photo_camera),
                  label: const Text('Use camera'),
                ),
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
