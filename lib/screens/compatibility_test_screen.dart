import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';

import 'package:card_box/models/compatibility_status.dart';
import 'package:card_box/models/nfc_scan_result.dart';
import 'package:card_box/models/wallet_card.dart';
import 'package:card_box/services/app_lock_service.dart';
import 'package:card_box/services/card_repository.dart';
import 'package:card_box/services/device_settings_service.dart';
import 'package:card_box/services/nfc_service.dart';
import 'package:card_box/theme.dart';

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
  final _deviceSettingsService = const DeviceSettingsService();
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
    final tokens = CardBoxThemeTokens.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Compatibility test')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          tokens.spaceLarge,
          tokens.spaceSmall,
          tokens.spaceLarge,
          tokens.spaceXLarge + tokens.spaceMedium,
        ),
        children: [
          Card(
            child: Padding(
              padding: EdgeInsets.all(tokens.spaceLarge),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.card.name,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: tokens.spaceSmall),
                  const Text(
                    'Not every RFID/NFC card can be read or emulated. This flow records what this phone can safely test.',
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: tokens.spaceMedium),
          const _PermissionExplainer(),
          SizedBox(height: tokens.spaceMedium),
          SwitchListTile.adaptive(
            title: const Text('Allow NFC test'),
            subtitle: const Text(
              'Used only after you choose to scan the card.',
            ),
            value: _nfcConsent,
            onChanged: (value) => setState(() => _nfcConsent = value),
          ),
          SizedBox(height: tokens.spaceSmall),
          _NfcPanel(
            loadingAvailability: _loadingAvailability,
            availability: _availability,
            consentGranted: _nfcConsent,
            scanning: _scanning,
            onScan: _nfcConsent ? _scanNfc : null,
            onOpenSettings: _openNfcSettings,
          ),
          if (_selectedStatus == CompatibilityStatus.androidHceCandidate) ...[
            SizedBox(height: tokens.spaceMedium),
            const _EmulationNote(),
          ],
          SizedBox(height: tokens.spaceMedium),
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
          SizedBox(height: tokens.spaceMedium),
          TextFormField(
            controller: _summaryController,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Test notes or NFC summary',
              border: OutlineInputBorder(),
            ),
          ),
          SizedBox(height: tokens.spaceLarge + 2),
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
    if (_availability == NfcAvailability.disabled) {
      await _openNfcSettings();
      if (!mounted) {
        return;
      }
      if (_availability == NfcAvailability.enabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('NFC is on now. Tap Scan NFC card to continue.'),
          ),
        );
      }
      return;
    }
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
    } catch (error) {
      if (!mounted) {
        return;
      }
      final result = NfcScanResult(
        status: CompatibilityStatus.unsupported,
        summary: 'The NFC session could not be started.',
        detail: 'Error: $error',
      );
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

  Future<void> _openNfcSettings() async {
    try {
      widget.appLockService.beginTrustedExternalFlow();
      final opened = await _deviceSettingsService.openNfcSettings();
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open NFC settings on this device.'),
          ),
        );
      }
    } finally {
      widget.appLockService.endTrustedExternalFlow();
      await _loadAvailability();
    }
  }
}

class _PermissionExplainer extends StatelessWidget {
  const _PermissionExplainer();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final tokens = CardBoxThemeTokens.of(context);
    return Card(
      child: Padding(
        padding: EdgeInsets.all(tokens.spaceLarge),
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
            SizedBox(height: tokens.spaceMedium - 2),
            const _PermissionLine(
              icon: Icons.photo_camera,
              title: 'Camera',
              detail:
                  'Visible barcode or QR testing happens in the add or edit flow when you open the scanner.',
            ),
            SizedBox(height: tokens.spaceSmall),
            const _PermissionLine(
              icon: Icons.nfc,
              title: 'NFC on Android',
              detail:
                  'NFC is declared in the app manifest and depends on device support. Android usually does not show a separate runtime permission prompt for basic NFC tag reading.',
            ),
            SizedBox(height: tokens.spaceSmall),
            const _PermissionLine(
              icon: Icons.contactless,
              title: 'RFID note',
              detail:
                  'Many everyday RFID cards, especially low-frequency 125 kHz cards, cannot be read by normal phone NFC hardware at all. This is a hardware limit, not a missing permission.',
            ),
            SizedBox(height: tokens.spaceSmall),
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
    final tokens = CardBoxThemeTokens.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: tokens.iconSmall),
        SizedBox(width: tokens.spaceMedium - 2),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              SizedBox(height: tokens.spaceXSmall / 2),
              Text(detail, style: Theme.of(context).textTheme.bodySmall),
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
    required this.onOpenSettings,
  });

  final bool loadingAvailability;
  final NfcAvailability? availability;
  final bool consentGranted;
  final bool scanning;
  final VoidCallback? onScan;
  final Future<void> Function() onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final tokens = CardBoxThemeTokens.of(context);
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
        padding: EdgeInsets.all(tokens.spaceLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'NFC reader',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            SizedBox(height: tokens.spaceSmall),
            Text(availabilityLabel),
            SizedBox(height: tokens.spaceMedium),
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
            if (availability == NfcAvailability.disabled) ...[
              SizedBox(height: tokens.spaceSmall),
              OutlinedButton.icon(
                onPressed: () => onOpenSettings(),
                icon: const Icon(Icons.settings_outlined),
                label: const Text('Turn on NFC'),
              ),
              SizedBox(height: tokens.spaceSmall - 2),
              Text(
                'Android does not show a normal runtime permission prompt for NFC. This opens the system NFC panel instead.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (!consentGranted) ...[
              SizedBox(height: tokens.spaceSmall),
              Text(
                'Turn on "Allow NFC test" before starting a scan.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmulationNote extends StatelessWidget {
  const _EmulationNote();

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
              'Possible Android emulation candidate',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            SizedBox(height: tokens.spaceSmall),
            const Text(
              'This card exposed ISO-DEP style behavior, which is the family Android Host Card Emulation works with. That does not mean the phone can replace this card today. It means the card is worth deeper Android-only investigation later.',
            ),
          ],
        ),
      ),
    );
  }
}
