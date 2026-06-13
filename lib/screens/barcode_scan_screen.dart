import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:card_box/models/scanned_code.dart';
import 'package:card_box/services/device_settings_service.dart';
import 'package:card_box/theme.dart';

enum _ScanMode {
  barcode('Barcode'),
  qr('QR'),
  all('All');

  const _ScanMode(this.label);

  final String label;
}

class BarcodeScanScreen extends StatefulWidget {
  const BarcodeScanScreen({super.key});

  @override
  State<BarcodeScanScreen> createState() => _BarcodeScanScreenState();
}

class _BarcodeScanScreenState extends State<BarcodeScanScreen>
    with WidgetsBindingObserver {
  static const Size _preferredCameraResolution = Size(1920, 1080);

  final DeviceSettingsService _deviceSettingsService =
      const DeviceSettingsService();
  late MobileScannerController _controller;
  _ScanMode _scanMode = _ScanMode.barcode;

  /// Completes when the active controller has finished disposing.
  /// The lifecycle observer (and any pending stop/restart) must
  /// await this before touching the controller, otherwise a fast
  /// in/out of the screen can race `dispose()` and `stop()` and
  /// throw `MobileScannerException(controllerDisposed)`.
  Completer<void>? _controllerDisposed;
  bool _scannerEnabled = false;
  bool _didReturnResult = false;
  bool _switchingMode = false;
  bool _resumeScannerAfterSettings = false;
  bool _resumeScannerAfterBackground = false;
  int _scannerGeneration = 0;
  String? _scannerErrorMessage;
  String? _candidatePayload;
  String? _candidateFormat;
  ScannedCode? _pendingCode;
  String? _lastSeenPayload;
  int _stableHits = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = _buildController(_scanMode);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final completer = Completer<void>();
    _controllerDisposed = completer;
    unawaited(_disposeControllerSafely(_controller, completer));
    super.dispose();
  }

  /// Disposes [controller] and signals completion on [done]. Errors
  /// from the underlying platform call are swallowed — the screen
  /// is already on its way out and there is no recovery path.
  Future<void> _disposeControllerSafely(
    MobileScannerController controller,
    Completer<void> done,
  ) async {
    try {
      await controller.dispose();
    } finally {
      if (!done.isCompleted) {
        done.complete();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) {
      // Hot-restart or fast-back can deliver lifecycle events after
      // dispose. Bail out before touching the controller or calling
      // any setState.
      return;
    }
    switch (state) {
      case AppLifecycleState.resumed:
        if ((!_resumeScannerAfterSettings && !_resumeScannerAfterBackground) ||
            !_scannerEnabled ||
            _didReturnResult ||
            _candidatePayload != null ||
            _switchingMode) {
          return;
        }
        _resumeScannerAfterSettings = false;
        _resumeScannerAfterBackground = false;
        _retryScannerAfterError();
        return;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        if (!_scannerEnabled || _didReturnResult || _switchingMode) {
          return;
        }
        if (_controller.value.isRunning) {
          _resumeScannerAfterBackground = true;
          unawaited(_suspendScannerForBackground());
        }
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = CardBoxThemeTokens.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan barcode or QR'),
        actions: [
          if (_scannerEnabled)
            ValueListenableBuilder<MobileScannerState>(
              valueListenable: _controller,
              builder: (context, state, _) {
                final torchEnabled = state.torchState == TorchState.on;
                final torchUnavailable =
                    !state.isRunning ||
                    state.torchState == TorchState.unavailable ||
                    _candidatePayload != null ||
                    _switchingMode;
                return IconButton(
                  tooltip: torchEnabled ? 'Turn torch off' : 'Turn torch on',
                  onPressed: torchUnavailable ? null : _toggleTorch,
                  icon: Icon(
                    torchEnabled ? Icons.flashlight_off : Icons.flashlight_on,
                  ),
                );
              },
            ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(tokens.spaceLarge),
          child: !_scannerEnabled
              ? _ConsentPanel(
                  selectedMode: _scanMode,
                  onModeChanged: _changeMode,
                  onStart: _enableScanner,
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final scanWindow = _buildScanWindow(
                      constraints: constraints,
                      mode: _scanMode,
                    );
                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(
                            tokens.radiusSmall,
                          ),
                          child: MobileScanner(
                            key: ValueKey(
                              'scanner-${_scanMode.name}-$_scannerGeneration',
                            ),
                            controller: _controller,
                            scanWindow: scanWindow,
                            onDetect: _handleDetection,
                            onDetectError: _handleScannerError,
                            errorBuilder: (context, error) {
                              return _ScannerErrorPanel(
                                message: _friendlyScannerError(
                                  errorMessage:
                                      error.errorDetails?.message ??
                                      error.errorCode.name,
                                  errorCode: error.errorCode,
                                ),
                                primaryLabel: _errorActionLabel(
                                  error.errorCode,
                                ),
                                onPrimary: () =>
                                    _handleScannerErrorAction(error.errorCode),
                                secondaryLabel:
                                    error.errorCode ==
                                        MobileScannerErrorCode.permissionDenied
                                    ? 'Retry scanner'
                                    : null,
                                onSecondary:
                                    error.errorCode ==
                                        MobileScannerErrorCode.permissionDenied
                                    ? _retryScannerAfterError
                                    : null,
                              );
                            },
                          ),
                        ),
                        _ScannerOverlay(scanWindow: scanWindow),
                        Positioned(
                          left: 24,
                          right: 24,
                          top: 24,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Flexible(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.68),
                                    borderRadius: BorderRadius.circular(
                                      tokens.radiusSmall,
                                    ),
                                  ),
                                  child: Padding(
                                    padding: EdgeInsets.all(tokens.spaceXSmall),
                                    child: _ModeChipBar(
                                      selectedMode: _scanMode,
                                      onModeChanged: _switchingMode
                                          ? null
                                          : _changeMode,
                                      compact: true,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_candidatePayload != null)
                          Positioned(
                            left: tokens.spaceLarge,
                            right: tokens.spaceLarge,
                            bottom: tokens.spaceLarge,
                            child: _CandidatePanel(
                              payload: _candidatePayload!,
                              format: _candidateFormat ?? 'Unknown format',
                              onUse: _confirmCandidate,
                              onKeepScanning: _resetCandidate,
                            ),
                          )
                        else
                          Positioned(
                            left: tokens.spaceLarge,
                            right: tokens.spaceLarge,
                            bottom: tokens.spaceLarge,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color:
                                    theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(
                                  tokens.radiusSmall,
                                ),
                              ),
                              child: Padding(
                                padding: EdgeInsets.all(tokens.spaceMedium),
                                child: Text(
                                  _scannerErrorMessage != null
                                      ? _scannerErrorMessage!
                                      : _switchingMode
                                      ? 'Updating the scanner...'
                                      : _stableHits == 0
                                      ? _modeInstruction(_scanMode)
                                      : 'Steady read in progress... '
                                            '$_stableHits/${_requiredStableHits(_scanMode)} matches',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
        ),
      ),
    );
  }

  MobileScannerController _buildController(_ScanMode mode) {
    return MobileScannerController(
      autoStart: false,
      cameraResolution: _preferredCameraResolution,
      detectionSpeed: DetectionSpeed.normal,
      detectionTimeoutMs: mode == _ScanMode.qr ? 250 : 400,
      autoZoom: false,
      formats: _formatsForMode(mode),
      returnImage: true,
    );
  }

  Rect _buildScanWindow({
    required BoxConstraints constraints,
    required _ScanMode mode,
  }) {
    final width = constraints.maxWidth;
    final height = constraints.maxHeight;
    final isBarcode = mode == _ScanMode.barcode;
    final frameWidth = isBarcode ? width * 0.9 : width * 0.74;
    final frameHeight = isBarcode ? height * 0.2 : width * 0.74;
    return Rect.fromCenter(
      center: Offset(width / 2, height / 2 - 8),
      width: frameWidth.clamp(220.0, 420.0),
      height: frameHeight.clamp(132.0, 340.0),
    );
  }

  int _requiredStableHits(_ScanMode mode) {
    return switch (mode) {
      _ScanMode.barcode => 3,
      _ScanMode.qr => 2,
      _ScanMode.all => 3,
    };
  }

  List<BarcodeFormat> _formatsForMode(_ScanMode mode) {
    switch (mode) {
      case _ScanMode.barcode:
        return const [
          BarcodeFormat.code128,
          BarcodeFormat.code39,
          BarcodeFormat.code93,
          BarcodeFormat.codabar,
          BarcodeFormat.ean13,
          BarcodeFormat.ean8,
          BarcodeFormat.itf14,
          BarcodeFormat.itf2of5,
          BarcodeFormat.itf2of5WithChecksum,
          BarcodeFormat.upcA,
          BarcodeFormat.upcE,
          BarcodeFormat.pdf417,
        ];
      case _ScanMode.qr:
        return const [
          BarcodeFormat.qrCode,
          BarcodeFormat.aztec,
          BarcodeFormat.dataMatrix,
        ];
      case _ScanMode.all:
        return const [];
    }
  }

  String _modeInstruction(_ScanMode mode) {
    switch (mode) {
      case _ScanMode.barcode:
        return 'Hold the barcode level inside the wide frame and let the camera settle for a beat.';
      case _ScanMode.qr:
        return 'Center the QR or square code inside the frame.';
      case _ScanMode.all:
        return 'Center the code inside the frame. If a 1D barcode feels jumpy, switch to Barcode mode.';
    }
  }

  Future<void> _changeMode(_ScanMode mode) async {
    if (_scanMode == mode || _switchingMode) {
      return;
    }
    final oldController = _controller;
    final newController = _buildController(mode);
    final oldDisposed = Completer<void>();
    _controllerDisposed = oldDisposed;
    setState(() {
      _switchingMode = true;
      _scanMode = mode;
      _controller = newController;
      _scannerGeneration += 1;
      _candidatePayload = null;
      _candidateFormat = null;
      _pendingCode = null;
      _lastSeenPayload = null;
      _stableHits = 0;
      _scannerErrorMessage = null;
    });
    await Future<void>.delayed(Duration.zero);
    // Wrap the rest in try/finally so `_switchingMode` is always
    // reset, even if dispose() or _startScanner() throws. Leaving
    // the flag stuck at true would freeze the scanner UI on
    // "Updating the scanner…".
    try {
      await _disposeControllerSafely(oldController, oldDisposed);

      if (!mounted) {
        await newController.dispose();
        return;
      }

      if (_scannerEnabled) {
        await _startScanner();
      }

      if (!mounted) {
        return;
      }
    } finally {
      if (mounted) {
        setState(() {
          _switchingMode = false;
        });
      } else {
        _switchingMode = false;
      }
    }
  }

  void _handleDetection(BarcodeCapture capture) {
    if (_didReturnResult || _candidatePayload != null || _switchingMode) {
      return;
    }
    final barcode = capture.barcodes.firstWhere(
      (item) => (item.rawValue ?? '').trim().isNotEmpty,
      orElse: () => capture.barcodes.first,
    );
    final rawValue = barcode.rawValue?.trim();
    if (rawValue == null || rawValue.isEmpty) {
      return;
    }

    if (_lastSeenPayload == rawValue) {
      _stableHits += 1;
    } else {
      _lastSeenPayload = rawValue;
      _stableHits = 1;
    }

    if (_stableHits < _requiredStableHits(_scanMode)) {
      if (mounted) {
        setState(() {});
      }
      return;
    }

    setState(() {
      _candidatePayload = rawValue;
      _candidateFormat = barcode.format.name;
      _pendingCode = _buildScannedCode(barcode, rawValue, capture.image);
      _stableHits = 0;
      _lastSeenPayload = null;
    });
  }

  void _handleScannerError(Object error, StackTrace stackTrace) {
    if (!mounted || _didReturnResult || _candidatePayload != null) {
      return;
    }
    setState(() {
      _scannerErrorMessage = _friendlyScannerError(
        errorMessage: error.toString(),
      );
      _candidatePayload = null;
      _candidateFormat = null;
      _pendingCode = null;
      _lastSeenPayload = null;
      _stableHits = 0;
    });
  }

  String _friendlyScannerError({
    required String errorMessage,
    MobileScannerErrorCode? errorCode,
  }) {
    if (errorCode == MobileScannerErrorCode.permissionDenied) {
      return 'Card Box needs camera access before it can scan visible codes.';
    }
    if (errorCode == MobileScannerErrorCode.unsupported) {
      return 'This device could not start the live camera scanner.';
    }

    final message = errorMessage.toLowerCase();
    if (message.contains('attempt to invoke a virtual method') ||
        message.contains('null object reference')) {
      return 'The live scanner hit a device-level Android camera error. Close and reopen the scanner, or switch modes if needed.';
    }
    return 'The live scanner ran into a camera error. Close and reopen the scanner if it stays stuck.';
  }

  String _errorActionLabel(MobileScannerErrorCode errorCode) {
    switch (errorCode) {
      case MobileScannerErrorCode.permissionDenied:
        return 'Open settings';
      case MobileScannerErrorCode.unsupported:
        return 'Close scanner';
      default:
        return 'Retry scanner';
    }
  }

  Future<void> _handleScannerErrorAction(
    MobileScannerErrorCode errorCode,
  ) async {
    switch (errorCode) {
      case MobileScannerErrorCode.permissionDenied:
        _resumeScannerAfterSettings = true;
        final opened = await _deviceSettingsService.openAppSettings();
        if (!mounted) {
          return;
        }
        if (!opened) {
          _resumeScannerAfterSettings = false;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not open app settings on this device.'),
            ),
          );
        }
        return;
      case MobileScannerErrorCode.unsupported:
        if (mounted) {
          await Navigator.of(context).maybePop();
        }
        return;
      default:
        await _retryScannerAfterError();
        return;
    }
  }

  void _confirmCandidate() {
    if (_didReturnResult || _candidatePayload == null || _pendingCode == null) {
      return;
    }
    _didReturnResult = true;
    _resumeScannerAfterSettings = false;
    _resumeScannerAfterBackground = false;
    final result = _pendingCode!;
    unawaited(_closeScannerWithResult(result));
  }

  Future<void> _resetCandidate() async {
    setState(() {
      _scannerErrorMessage = null;
      _candidatePayload = null;
      _candidateFormat = null;
      _pendingCode = null;
      _lastSeenPayload = null;
      _stableHits = 0;
    });
    if (_controller.value.isRunning) {
      return;
    }
    await _startScanner();
  }

  Future<void> _retryScannerAfterError() async {
    setState(() {
      _scannerErrorMessage = null;
      _candidatePayload = null;
      _candidateFormat = null;
      _pendingCode = null;
      _lastSeenPayload = null;
      _stableHits = 0;
    });
    await _startScanner(restart: true);
  }

  Future<void> _enableScanner() async {
    setState(() {
      _scannerEnabled = true;
      _scannerErrorMessage = null;
      _candidatePayload = null;
      _candidateFormat = null;
      _pendingCode = null;
      _lastSeenPayload = null;
      _stableHits = 0;
    });
    await Future<void>.delayed(Duration.zero);
    await _startScanner();
  }

  ScannedCode _buildScannedCode(
    Barcode barcode,
    String rawValue,
    Uint8List? imageBytes,
  ) {
    return ScannedCode(
      payload: rawValue,
      format: barcode.format.name,
      displayValue: (barcode.displayValue ?? '').trim(),
      valueType: barcode.type.name,
      structuredData: _structuredSummaryForBarcode(barcode),
      rawBytesHex: _hexBytesForBarcode(barcode),
      capturedAt: DateTime.now(),
      imageBytes: imageBytes,
    );
  }

  String _structuredSummaryForBarcode(Barcode barcode) {
    final lines = <String>[];
    if (barcode.url != null) {
      lines.add('URL: ${barcode.url!.url}');
      final title = barcode.url!.title?.trim();
      if (title != null && title.isNotEmpty) {
        lines.add('Title: $title');
      }
    }
    if (barcode.phone?.number?.trim().isNotEmpty == true) {
      lines.add('Phone: ${barcode.phone!.number!.trim()}');
    }
    if (barcode.email != null) {
      final address = barcode.email!.address?.trim();
      final subject = barcode.email!.subject?.trim();
      final body = barcode.email!.body?.trim();
      if (address != null && address.isNotEmpty) {
        lines.add('Email: $address');
      }
      if (subject != null && subject.isNotEmpty) {
        lines.add('Subject: $subject');
      }
      if (body != null && body.isNotEmpty) {
        lines.add('Body: $body');
      }
    }
    if (barcode.sms != null) {
      lines.add('SMS number: ${barcode.sms!.phoneNumber}');
      final message = barcode.sms!.message?.trim();
      if (message != null && message.isNotEmpty) {
        lines.add('SMS message: $message');
      }
    }
    if (barcode.wifi != null) {
      final ssid = barcode.wifi!.ssid?.trim();
      if (ssid != null && ssid.isNotEmpty) {
        lines.add('Wi-Fi SSID: $ssid');
      }
      final password = barcode.wifi!.password?.trim();
      if (password != null && password.isNotEmpty) {
        lines.add('Wi-Fi password stored');
      }
      lines.add('Wi-Fi encryption: ${barcode.wifi!.encryptionType.name}');
    }
    if (barcode.contactInfo != null) {
      final contact = barcode.contactInfo!;
      final fullName = contact.name?.formattedName?.trim();
      if (fullName != null && fullName.isNotEmpty) {
        lines.add('Contact: $fullName');
      }
      final organization = contact.organization?.trim();
      if (organization != null && organization.isNotEmpty) {
        lines.add('Organization: $organization');
      }
      final title = contact.title?.trim();
      if (title != null && title.isNotEmpty) {
        lines.add('Title: $title');
      }
      for (final phone in contact.phones) {
        final number = phone.number?.trim();
        if (number != null && number.isNotEmpty) {
          lines.add('Phone: $number');
        }
      }
      for (final email in contact.emails) {
        final address = email.address?.trim();
        if (address != null && address.isNotEmpty) {
          lines.add('Email: $address');
        }
      }
      for (final url in contact.urls) {
        final trimmed = url.trim();
        if (trimmed.isNotEmpty) {
          lines.add('URL: $trimmed');
        }
      }
    }
    if (barcode.calendarEvent != null) {
      final event = barcode.calendarEvent!;
      final summary = event.summary?.trim();
      if (summary != null && summary.isNotEmpty) {
        lines.add('Event: $summary');
      }
      final location = event.location?.trim();
      if (location != null && location.isNotEmpty) {
        lines.add('Location: $location');
      }
    }
    return lines.join('\n');
  }

  String _hexBytesForBarcode(Barcode barcode) {
    final raw = barcode.rawDecodedBytes;
    Uint8List? bytes;
    switch (raw) {
      case DecodedBarcodeBytes():
        bytes = raw.bytes;
      case DecodedVisionBarcodeBytes():
        bytes = raw.bytes ?? raw.rawBytes;
      case null:
        bytes = null;
    }
    if (bytes == null || bytes.isEmpty) {
      return '';
    }
    return bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join(' ');
  }

  Future<void> _startScanner({bool restart = false}) async {
    try {
      if (restart && _controller.value.isRunning) {
        await _controller.stop();
      }
      await _controller.start();
      final error = _controller.value.error;
      if (!mounted || error == null) {
        return;
      }
      setState(() {
        _scannerErrorMessage = _friendlyScannerError(
          errorMessage: error.errorDetails?.message ?? error.errorCode.message,
          errorCode: error.errorCode,
        );
      });
    } on MobileScannerException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _scannerErrorMessage = _friendlyScannerError(
          errorMessage: error.errorDetails?.message ?? error.errorCode.message,
          errorCode: error.errorCode,
        );
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _scannerErrorMessage = _friendlyScannerError(
          errorMessage: error.toString(),
        );
      });
    }
  }

  Future<void> _toggleTorch() async {
    try {
      await _controller.toggleTorch();
    } on MobileScannerException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _scannerErrorMessage = _friendlyScannerError(
          errorMessage: error.errorDetails?.message ?? error.errorCode.message,
          errorCode: error.errorCode,
        );
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _scannerErrorMessage =
            'The torch is not available right now. Try reopening the scanner.';
      });
    }
  }

  Future<void> _closeScannerWithResult(ScannedCode result) async {
    try {
      if (_controller.value.isRunning) {
        await _controller.stop();
      }
    } catch (_) {
      // The route is closing anyway; ignore shutdown errors here.
    }
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(result);
  }

  Future<void> _suspendScannerForBackground() async {
    // Wait for any in-progress dispose() to finish so we do not
    // call stop() on a controller that has already been torn down.
    final disposed = _controllerDisposed;
    if (disposed != null) {
      await disposed.future;
    }
    try {
      await _controller.stop();
    } catch (_) {
      // Best-effort camera release for lifecycle transitions.
    }
  }
}

class _ConsentPanel extends StatelessWidget {
  const _ConsentPanel({
    required this.selectedMode,
    required this.onModeChanged,
    required this.onStart,
  });

  final _ScanMode selectedMode;
  final ValueChanged<_ScanMode> onModeChanged;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = CardBoxThemeTokens.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(tokens.spaceXLarge),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Camera permission',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: tokens.spaceMedium - 2),
                Text(
                  'Choose the kind of code you want to scan, then start the camera when you are ready.',
                  style: theme.textTheme.bodyMedium,
                ),
                SizedBox(height: tokens.spaceLarge),
                _ModeChipBar(
                  selectedMode: selectedMode,
                  onModeChanged: onModeChanged,
                ),
                SizedBox(height: tokens.spaceLarge),
                FilledButton.icon(
                  onPressed: onStart,
                  icon: Icon(Icons.qr_code_scanner, size: tokens.iconMedium),
                  label: const Text('Start scanner'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeChipBar extends StatelessWidget {
  const _ModeChipBar({
    required this.selectedMode,
    required this.onModeChanged,
    this.compact = false,
  });

  final _ScanMode selectedMode;
  final ValueChanged<_ScanMode>? onModeChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tokens = CardBoxThemeTokens.of(context);
    return Wrap(
      spacing: compact ? tokens.spaceXSmall : tokens.spaceSmall,
      runSpacing: compact ? tokens.spaceXSmall : tokens.spaceSmall,
      children: [
        for (final mode in _ScanMode.values)
          ChoiceChip(
            label: Text(mode.label),
            visualDensity: compact ? VisualDensity.compact : null,
            selected: mode == selectedMode,
            onSelected: onModeChanged == null
                ? null
                : (selected) {
                    if (selected) {
                      onModeChanged!(mode);
                    }
                  },
          ),
      ],
    );
  }
}

class _CandidatePanel extends StatelessWidget {
  const _CandidatePanel({
    required this.payload,
    required this.format,
    required this.onUse,
    required this.onKeepScanning,
  });

  final String payload;
  final String format;
  final VoidCallback onUse;
  final VoidCallback onKeepScanning;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = CardBoxThemeTokens.of(context);
    return Card(
      child: Padding(
        padding: EdgeInsets.all(tokens.spaceLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Stable read found',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: tokens.spaceSmall),
            Align(
              alignment: Alignment.centerLeft,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: tokens.spaceSmall,
                    vertical: tokens.spaceXSmall,
                  ),
                  child: Text(format, style: theme.textTheme.labelMedium),
                ),
              ),
            ),
            SizedBox(height: tokens.spaceSmall),
            Text(payload, maxLines: 2, overflow: TextOverflow.ellipsis),
            SizedBox(height: tokens.spaceMedium),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onKeepScanning,
                    child: const Text('Keep scanning'),
                  ),
                ),
                SizedBox(width: tokens.spaceMedium),
                Expanded(
                  child: FilledButton(
                    onPressed: onUse,
                    child: const Text('Use this code'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ScannerOverlay extends StatelessWidget {
  const _ScannerOverlay({required this.scanWindow});

  final Rect scanWindow;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _ScannerOverlayPainter(scanWindow: scanWindow),
      ),
    );
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  const _ScannerOverlayPainter({required this.scanWindow});

  final Rect scanWindow;

  @override
  void paint(Canvas canvas, Size size) {
    final overlayPaint = Paint()..color = Colors.black.withValues(alpha: 0.46);
    final clearPaint = Paint()..blendMode = BlendMode.clear;
    final overlayPath = Path()..addRect(Offset.zero & size);
    final cutout = RRect.fromRectAndRadius(
      scanWindow,
      const Radius.circular(18),
    );
    final cutoutPath = Path()..addRRect(cutout);

    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawPath(overlayPath, overlayPaint);
    canvas.drawPath(cutoutPath, clearPaint);
    canvas.restore();

    final framePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawRRect(cutout, framePaint);
  }

  @override
  bool shouldRepaint(covariant _ScannerOverlayPainter oldDelegate) {
    return oldDelegate.scanWindow != scanWindow;
  }
}

class _ScannerErrorPanel extends StatelessWidget {
  const _ScannerErrorPanel({
    required this.message,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  final String message;
  final String primaryLabel;
  final Future<void> Function() onPrimary;
  final String? secondaryLabel;
  final Future<void> Function()? onSecondary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = CardBoxThemeTokens.of(context);
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(tokens.spaceXLarge),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.qr_code_scanner_outlined,
                    size: tokens.iconLarge + 12,
                  ),
                  SizedBox(height: tokens.spaceMedium),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                  SizedBox(height: tokens.spaceLarge),
                  Wrap(
                    spacing: tokens.spaceMedium,
                    runSpacing: tokens.spaceMedium,
                    alignment: WrapAlignment.center,
                    children: [
                      FilledButton(
                        onPressed: onPrimary,
                        child: Text(primaryLabel),
                      ),
                      if (secondaryLabel != null && onSecondary != null)
                        OutlinedButton(
                          onPressed: onSecondary,
                          child: Text(secondaryLabel!),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
