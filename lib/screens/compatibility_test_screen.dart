import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';

import 'package:card_box/models/compatibility_status.dart';
import 'package:card_box/models/nfc_scan_result.dart';
import 'package:card_box/models/wallet_card.dart';
import 'package:card_box/services/app_lock_service.dart';
import 'package:card_box/services/card_repository.dart';
import 'package:card_box/services/nfc_service.dart';

class CompatibilityTestScreen extends StatefulWidget {
  const CompatibilityTestScreen({
    super.key,
    required this.repository,
    required this.appLockService,
    required this.card,
  });

  final CardRepository repository;
  final AppLockService appLockService;
  final WalletCard card;

  @override
  State<CompatibilityTestScreen> createState() =>
      _CompatibilityTestScreenState();
}

class _CompatibilityTestScreenState extends State<CompatibilityTestScreen> {
  bool _nfcConsent = false;
  CompatibilityStatus _selectedStatus = CompatibilityStatus.untested;
  final _summaryController = TextEditingController();
  final _nfcService = NfcService();
  NfcAvailability? _availability;
  bool _loadingAvailability = true;
  bool _scanning = false;

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.card.compatibilityStatus;
    _summaryController.text = widget.card.nfcTagSummary;
    _loadAvailability();
  }

  @override
  void dispose() {
    _summaryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Compatibility test')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.card.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Not every RFID/NFC card can be read or emulated. This flow records what this phone can safely test.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const _PermissionExplainer(),
          const SizedBox(height: 12),
          SwitchListTile.adaptive(
            title: const Text('Allow NFC test'),
            subtitle: const Text(
              'Used only after you choose to scan the card.',
            ),
            value: _nfcConsent,
            onChanged: (value) => setState(() => _nfcConsent = value),
          ),
          const SizedBox(height: 8),
          _NfcPanel(
            loadingAvailability: _loadingAvailability,
            availability: _availability,
            consentGranted: _nfcConsent,
            scanning: _scanning,
            onScan: _nfcConsent ? _scanNfc : null,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<CompatibilityStatus>(
            initialValue: _selectedStatus,
            decoration: const InputDecoration(
              labelText: 'Compatibility result',
              border: OutlineInputBorder(),
            ),
            items: CompatibilityStatus.values
                .map(
                  (status) => DropdownMenuItem(
                    value: status,
                    child: Text(status.label),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(
              () => _selectedStatus = value ?? CompatibilityStatus.untested,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _summaryController,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Test notes or NFC summary',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            icon: const Icon(Icons.check),
            label: const Text('Save result'),
            onPressed: _save,
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final summary = _summaryController.text.trim();
    final card = widget.card.copyWith(
      compatibilityStatus: _selectedStatus,
      nfcTagSummary: summary,
    );
    await widget.repository.upsert(card);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _loadAvailability() async {
    final availability = await _nfcService.checkAvailability();
    if (!mounted) {
      return;
    }
    setState(() {
      _availability = availability;
      _loadingAvailability = false;
    });
  }

  Future<void> _scanNfc() async {
    final approved = await _confirmInterfaceUse();
    if (!approved) {
      return;
    }
    widget.appLockService.beginTrustedExternalFlow();
    setState(() => _scanning = true);
    try {
      final result = await _nfcService.scanTag();
      if (!mounted) {
        return;
      }
      _applyResult(result);
    } finally {
      widget.appLockService.endTrustedExternalFlow();
      if (mounted) {
        setState(() => _scanning = false);
      }
    }
  }

  void _applyResult(NfcScanResult result) {
    setState(() {
      _selectedStatus = result.status;
      _summaryController.text = result.detail;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(result.summary)));
  }

  Future<bool> _confirmInterfaceUse() async {
    final decision = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Use NFC reader?'),
        content: const Text(
          'Card Box will open the phone NFC reader and wait for you to hold a card near the device. Some RFID cards still cannot be read because of phone hardware limits.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Start NFC'),
          ),
        ],
      ),
    );
    return decision ?? false;
  }
}

class _PermissionExplainer extends StatelessWidget {
  const _PermissionExplainer();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Permissions and support',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: colors.primary,
              ),
            ),
            const SizedBox(height: 10),
            const _PermissionLine(
              icon: Icons.photo_camera,
              title: 'Camera',
              detail:
                  'Visible barcode or QR testing happens in the add or edit flow when you open the scanner.',
            ),
            const SizedBox(height: 8),
            const _PermissionLine(
              icon: Icons.nfc,
              title: 'NFC on Android',
              detail:
                  'NFC is declared in the app manifest and depends on device support. Android usually does not show a separate runtime permission prompt for basic NFC tag reading.',
            ),
            const SizedBox(height: 8),
            const _PermissionLine(
              icon: Icons.contactless,
              title: 'RFID note',
              detail:
                  'Many everyday RFID cards, especially low-frequency 125 kHz cards, cannot be read by normal phone NFC hardware at all. This is a hardware limit, not a missing permission.',
            ),
            const SizedBox(height: 8),
            const _PermissionLine(
              icon: Icons.phone_iphone,
              title: 'iPhone note',
              detail:
                  'Core NFC requires an NFC usage description and, for some tag types, extra entitlements. Card Box is currently Android-first for NFC validation.',
            ),
          ],
        ),
      ),
    );
  }
}

class _PermissionLine extends StatelessWidget {
  const _PermissionLine({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(detail, style: const TextStyle(fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }
}

class _NfcPanel extends StatelessWidget {
  const _NfcPanel({
    required this.loadingAvailability,
    required this.availability,
    required this.consentGranted,
    required this.scanning,
    required this.onScan,
  });

  final bool loadingAvailability;
  final NfcAvailability? availability;
  final bool consentGranted;
  final bool scanning;
  final VoidCallback? onScan;

  @override
  Widget build(BuildContext context) {
    final availabilityLabel = loadingAvailability
        ? 'Checking NFC availability...'
        : switch (availability) {
            NfcAvailability.enabled => 'NFC is available on this device.',
            NfcAvailability.disabled => 'NFC exists but is currently disabled.',
            NfcAvailability.unsupported => 'This device does not support NFC.',
            null => 'NFC status unavailable.',
          };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'NFC reader',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(availabilityLabel),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed:
                  scanning ||
                      loadingAvailability ||
                      availability != NfcAvailability.enabled ||
                      !consentGranted
                  ? null
                  : onScan,
              icon: const Icon(Icons.nfc),
              label: Text(scanning ? 'Scanning...' : 'Scan NFC card'),
            ),
            if (!consentGranted) ...[
              const SizedBox(height: 8),
              const Text(
                'Turn on "Allow NFC test" before starting a scan.',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
