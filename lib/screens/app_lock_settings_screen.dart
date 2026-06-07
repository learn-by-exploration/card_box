import 'package:flutter/material.dart';

import 'package:card_box/services/app_lock_service.dart';
import 'package:card_box/theme.dart';

class AppLockSettingsScreen extends StatefulWidget {
  const AppLockSettingsScreen({super.key, required this.appLockService});

  final AppLockService appLockService;

  @override
  State<AppLockSettingsScreen> createState() => _AppLockSettingsScreenState();
}

class _AppLockSettingsScreenState extends State<AppLockSettingsScreen> {
  bool _useBiometrics = false;
  bool _lockOnResume = true;

  @override
  void initState() {
    super.initState();
    _useBiometrics = widget.appLockService.biometricEnabled;
    _lockOnResume = widget.appLockService.lockOnResume;
  }

  @override
  Widget build(BuildContext context) {
    final appLock = widget.appLockService;
    final tokens = CardBoxThemeTokens.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('App lock')),
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
                    'Protect your wallet',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: tokens.spaceSmall),
                  Text(
                    appLock.lockEnabled
                        ? 'Card Box is locked with your app PIN${appLock.biometricEnabled ? ' and biometrics' : ''}.'
                        : 'Turn on app lock to protect saved cards with a PIN and optional biometrics.',
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: tokens.spaceMedium),
          if (!appLock.lockEnabled)
            _SetupLockCard(
              biometricAvailable: appLock.biometricAvailable,
              onCreateLock: _createLock,
            )
          else ...[
            SwitchListTile.adaptive(
              title: const Text('Use biometrics'),
              subtitle: Text(
                appLock.biometricAvailable
                    ? 'Use fingerprint or face unlock when available.'
                    : 'Biometrics are not available on this device.',
              ),
              value: _useBiometrics && appLock.biometricAvailable,
              onChanged: appLock.biometricAvailable
                  ? (value) => setState(() => _useBiometrics = value)
                  : null,
            ),
            SwitchListTile.adaptive(
              title: const Text('Lock when app resumes'),
              subtitle: const Text(
                'Require unlock again after leaving and returning to the app.',
              ),
              value: _lockOnResume,
              onChanged: (value) => setState(() => _lockOnResume = value),
            ),
            SizedBox(height: tokens.spaceMedium),
            FilledButton.icon(
              onPressed: _saveSettings,
              icon: const Icon(Icons.save),
              label: const Text('Save lock settings'),
            ),
            SizedBox(height: tokens.spaceSmall),
            OutlinedButton.icon(
              onPressed: _changePin,
              icon: const Icon(Icons.pin),
              label: const Text('Change PIN'),
            ),
            SizedBox(height: tokens.spaceSmall),
            OutlinedButton.icon(
              onPressed: _disableLock,
              icon: const Icon(Icons.lock_open),
              label: const Text('Turn off app lock'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _createLock(
    String pin,
    bool useBiometrics,
    bool lockOnResume,
  ) async {
    await widget.appLockService.enableLock(
      pin: pin,
      useBiometrics: useBiometrics,
      lockOnResume: lockOnResume,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _useBiometrics = useBiometrics;
      _lockOnResume = lockOnResume;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('App lock is enabled.')));
  }

  Future<void> _saveSettings() async {
    await widget.appLockService.updateSettings(
      useBiometrics: _useBiometrics,
      lockOnResume: _lockOnResume,
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Lock settings saved.')));
  }

  Future<void> _changePin() async {
    final pin = await _showPinDialog(
      title: 'Change app PIN',
      actionLabel: 'Save PIN',
    );
    if (pin == null) {
      return;
    }
    await widget.appLockService.changePin(pin);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('PIN changed.')));
  }

  Future<void> _disableLock() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Turn off app lock?'),
        content: const Text(
          'Card Box will stop asking for your PIN or biometrics until you turn app lock back on.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Turn off'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    await widget.appLockService.disableLock();
    if (!mounted) {
      return;
    }
    setState(() {
      _useBiometrics = false;
      _lockOnResume = true;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('App lock turned off.')));
  }

  Future<String?> _showPinDialog({
    required String title,
    required String actionLabel,
  }) async {
    final pinController = TextEditingController();
    final confirmController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final pin = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: pinController,
                decoration: const InputDecoration(labelText: 'PIN'),
                obscureText: true,
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().length < 4) {
                    return 'Use at least 4 digits';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: confirmController,
                decoration: const InputDecoration(labelText: 'Confirm PIN'),
                obscureText: true,
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value != pinController.text) {
                    return 'PINs do not match';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) {
                return;
              }
              Navigator.of(context).pop(pinController.text.trim());
            },
            child: Text(actionLabel),
          ),
        ],
      ),
    );
    pinController.dispose();
    confirmController.dispose();
    return pin;
  }
}

class _SetupLockCard extends StatefulWidget {
  const _SetupLockCard({
    required this.biometricAvailable,
    required this.onCreateLock,
  });

  final bool biometricAvailable;
  final Future<void> Function(String pin, bool useBiometrics, bool lockOnResume)
  onCreateLock;

  @override
  State<_SetupLockCard> createState() => _SetupLockCardState();
}

class _SetupLockCardState extends State<_SetupLockCard> {
  final _pinController = TextEditingController();
  final _confirmController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _useBiometrics = true;
  bool _lockOnResume = true;
  bool _saving = false;

  @override
  void dispose() {
    _pinController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Create your app PIN',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _pinController,
                decoration: const InputDecoration(labelText: 'PIN'),
                obscureText: true,
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().length < 4) {
                    return 'Use at least 4 digits';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirmController,
                decoration: const InputDecoration(labelText: 'Confirm PIN'),
                obscureText: true,
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value != _pinController.text) {
                    return 'PINs do not match';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Use biometrics when available'),
                value: _useBiometrics && widget.biometricAvailable,
                onChanged: widget.biometricAvailable
                    ? (value) => setState(() => _useBiometrics = value)
                    : null,
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Lock when app resumes'),
                value: _lockOnResume,
                onChanged: (value) => setState(() => _lockOnResume = value),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.lock),
                label: Text(_saving ? 'Saving...' : 'Turn on app lock'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.onCreateLock(
        _pinController.text.trim(),
        _useBiometrics && widget.biometricAvailable,
        _lockOnResume,
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }
}
