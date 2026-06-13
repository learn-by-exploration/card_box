import 'package:flutter/material.dart';

import 'package:card_box/services/app_lock_service.dart';
import 'package:card_box/theme.dart';

class AppLockScreen extends StatefulWidget {
  const AppLockScreen({super.key, required this.appLockService});

  final AppLockService appLockService;

  @override
  State<AppLockScreen> createState() => AppLockScreenState();
}

class AppLockScreenState extends State<AppLockScreen> {
  final _pinController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String _message = '';
  bool _submitting = false;
  bool _autoTried = false;

  /// Wall-clock of the last biometric retry we actually fired.
  /// Used to debounce the retry button so a frantic user cannot
  /// hammer the local_auth API in a tight loop. Visible for
  /// tests so the debounce window can be exercised deterministically.
  DateTime? _lastBiometricAttempt;

  /// Minimum spacing between biometric attempts. 500ms is short
  /// enough to feel responsive on a real retry but long enough
  /// to coalesce a triple-tap. The local_auth plugin queues
  /// prompts; without this guard the queue grows and the OS
  /// eventually shows the wrong prompt on top of the wrong state.
  static const _biometricDebounce = Duration(milliseconds: 500);

  /// Test seam: lets widget tests inject a clock.
  @visibleForTesting
  DateTime Function() now = DateTime.now;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_autoTried) {
      _autoTried = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _tryBiometrics(auto: true);
      });
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appLock = widget.appLockService;
    final theme = Theme.of(context);
    final tokens = CardBoxThemeTokens.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: EdgeInsets.all(tokens.spaceXLarge + tokens.spaceXSmall),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(tokens.radiusLarge),
                    ),
                    child: Icon(
                      Icons.lock,
                      size: 36,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  SizedBox(height: tokens.spaceXLarge),
                  Text(
                    'Unlock Card Box',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: tokens.spaceSmall),
                  Text(
                    'Use your app PIN. If biometrics are enabled, you can unlock with your device sensor too.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                  SizedBox(height: tokens.spaceXLarge + tokens.spaceXSmall),
                  Form(
                    key: _formKey,
                    child: TextFormField(
                      controller: _pinController,
                      decoration: const InputDecoration(labelText: 'App PIN'),
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      validator: (value) {
                        if (value == null || value.trim().length < 4) {
                          return 'Enter your 4-digit PIN';
                        }
                        return null;
                      },
                      onFieldSubmitted: (_) => _submitPin(),
                    ),
                  ),
                  SizedBox(height: tokens.spaceMedium),
                  FilledButton(
                    onPressed: _submitting ? null : _submitPin,
                    child: Text(_submitting ? 'Unlocking...' : 'Unlock'),
                  ),
                  if (appLock.biometricEnabled &&
                      appLock.biometricAvailable) ...[
                    SizedBox(height: tokens.spaceSmall),
                    OutlinedButton.icon(
                      onPressed: appLock.authenticating
                          ? null
                          : () => _tryBiometrics(auto: false),
                      icon: Icon(Icons.fingerprint, size: tokens.iconMedium),
                      label: Text(
                        appLock.authenticating
                            ? 'Waiting for biometrics...'
                            : 'Use biometrics',
                      ),
                    ),
                  ],
                  if (_message.isNotEmpty) ...[
                    SizedBox(height: tokens.spaceMedium),
                    Text(
                      _message,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: theme.colorScheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submitPin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _submitting = true;
      _message = '';
    });
    final success = await widget.appLockService.unlockWithPin(
      _pinController.text.trim(),
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _submitting = false;
      _message = success ? '' : 'That PIN did not match.';
    });
  }

  Future<void> _tryBiometrics({required bool auto}) async {
    final appLock = widget.appLockService;
    if (!appLock.biometricEnabled || !appLock.biometricAvailable) {
      return;
    }
    // Skip the debounce on the auto-triggered first attempt —
    // the screen just opened, the user has not had a chance to
    // hammer the button. Spamming-tap protection matters for
    // explicit retry only.
    if (!auto) {
      final now = this.now();
      final last = _lastBiometricAttempt;
      if (last != null && now.difference(last) < _biometricDebounce) {
        return;
      }
      _lastBiometricAttempt = now;
    }
    final success = await appLock.unlockWithBiometrics();
    if (!mounted || success || auto) {
      return;
    }
    setState(() => _message = 'Biometric unlock was canceled or failed.');
  }
}
