import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';
import 'package:nfc_manager/nfc_manager_ios.dart';

import 'package:card_box/models/compatibility_status.dart';
import 'package:card_box/models/nfc_scan_result.dart';

abstract class NfcSessionClient {
  Future<NfcAvailability> checkAvailability();

  Future<void> startSession({
    required Set<NfcPollingOption> pollingOptions,
    required void Function(NfcTag tag) onDiscovered,
    String? alertMessageIos,
    void Function(NfcReaderSessionErrorIos error)? onSessionErrorIos,
  });

  Future<void> stopSession({String? alertMessageIos, String? errorMessageIos});
}

class DefaultNfcSessionClient implements NfcSessionClient {
  const DefaultNfcSessionClient();

  @override
  Future<NfcAvailability> checkAvailability() {
    return NfcManager.instance.checkAvailability();
  }

  @override
  Future<void> startSession({
    required Set<NfcPollingOption> pollingOptions,
    required void Function(NfcTag tag) onDiscovered,
    String? alertMessageIos,
    void Function(NfcReaderSessionErrorIos error)? onSessionErrorIos,
  }) {
    return NfcManager.instance.startSession(
      pollingOptions: pollingOptions,
      alertMessageIos: alertMessageIos,
      onSessionErrorIos: onSessionErrorIos,
      onDiscovered: onDiscovered,
    );
  }

  @override
  Future<void> stopSession({String? alertMessageIos, String? errorMessageIos}) {
    return NfcManager.instance.stopSession(
      alertMessageIos: alertMessageIos,
      errorMessageIos: errorMessageIos,
    );
  }
}

class NfcService {
  NfcService({
    NfcSessionClient? sessionClient,
    Duration? sessionTimeout,
    bool? isWeb,
    TargetPlatform? platform,
  }) : _sessionClient = sessionClient ?? const DefaultNfcSessionClient(),
       _sessionTimeout = sessionTimeout ?? const Duration(seconds: 20),
       _isWeb = isWeb ?? kIsWeb,
       _platform = platform ?? defaultTargetPlatform;

  final NfcSessionClient _sessionClient;
  final Duration _sessionTimeout;
  final bool _isWeb;
  final TargetPlatform _platform;

  Future<NfcAvailability> checkAvailability() async {
    if (_isWeb) {
      return NfcAvailability.unsupported;
    }
    try {
      return await _sessionClient.checkAvailability();
    } on UnsupportedError {
      return NfcAvailability.unsupported;
    }
  }

  Future<NfcScanResult> scanTag() async {
    final availability = await checkAvailability();
    if (availability != NfcAvailability.enabled) {
      return NfcScanResult(
        status: CompatibilityStatus.unsupported,
        summary: 'NFC is ${availability.name} on this device.',
        detail: 'No scan was started.',
      );
    }

    final completer = Completer<NfcScanResult>();
    // Single-flight tear-down: every completion path (success,
    // iOS session error, timeout, caller cancel) routes through
    // `_tearDown` and `_tearDown` is idempotent. Without this
    // guard, the iOS NFC sheet can outlive the calling widget
    // when two completion paths race (e.g. timeout fires
    // simultaneously with a discovered-tag callback).
    var stopped = false;
    Future<void> tearDown({
      String? alertMessageIos,
      String? errorMessageIos,
    }) async {
      if (stopped) {
        return;
      }
      stopped = true;
      await _stopSessionSafely(
        alertMessageIos: alertMessageIos,
        errorMessageIos: errorMessageIos,
      );
    }

    try {
      await _sessionClient.startSession(
        pollingOptions: const {
          NfcPollingOption.iso14443,
          NfcPollingOption.iso15693,
          NfcPollingOption.iso18092,
        },
        alertMessageIos: 'Hold your phone near the card.',
        onSessionErrorIos: (error) {
          if (completer.isCompleted) {
            return;
          }
          completer.complete(
            NfcScanResult(
              status: CompatibilityStatus.unsupported,
              summary: 'NFC session error: ${error.message}',
              detail: 'The iOS reader session ended before a tag was saved.',
            ),
          );
          // The iOS sheet must be torn down here too — otherwise it
          // outlives the caller and the user is stuck with a
          // persistent modal after the underlying screen has gone.
          unawaited(tearDown());
        },
        onDiscovered: (tag) async {
          if (completer.isCompleted) {
            // Late tag delivery after a timeout / cancel: drop
            // the work, but still tear down so the iOS sheet
            // dismisses.
            await tearDown();
            return;
          }
          try {
            final result = await _buildResult(tag);
            if (!completer.isCompleted) {
              completer.complete(result);
            }
            await tearDown(alertMessageIos: 'Tag read complete.');
          } catch (error) {
            if (!completer.isCompleted) {
              completer.complete(
                NfcScanResult(
                  status: CompatibilityStatus.nfcDetectedNotReadable,
                  summary: 'Card detected, but the tag summary failed.',
                  detail: 'Error: $error',
                ),
              );
            }
            await tearDown(errorMessageIos: 'Unable to read this card.');
          }
        },
      );

      return completer.future.timeout(
        _sessionTimeout,
        onTimeout: () async {
          if (!completer.isCompleted) {
            completer.complete(
              const NfcScanResult(
                status: CompatibilityStatus.unsupported,
                summary: 'No NFC card was detected in time.',
                detail: 'Try again with the card closer to the phone.',
              ),
            );
          }
          await tearDown(errorMessageIos: 'Timed out waiting for a card.');
          // Returning the same instance the completer was given is
          // safe — both code paths produce the same shape and
          // `completer.future` resolves before this returns.
          return const NfcScanResult(
            status: CompatibilityStatus.unsupported,
            summary: 'No NFC card was detected in time.',
            detail: 'Try again with the card closer to the phone.',
          );
        },
      );
    } catch (error) {
      await tearDown();
      return NfcScanResult(
        status: CompatibilityStatus.unsupported,
        summary: 'The NFC session could not be started.',
        detail: 'Error: $error',
      );
    }
  }

  Future<NfcScanResult> _buildResult(NfcTag tag) async {
    return switch (_platform) {
      TargetPlatform.android => _buildAndroidResult(tag),
      TargetPlatform.iOS => _buildIosResult(tag),
      _ => NfcScanResult(
        status: CompatibilityStatus.unsupported,
        summary: 'NFC is not supported on ${_platform.name}.',
        detail: 'No NFC summary is available on this platform.',
      ),
    };
  }

  Future<NfcScanResult> _buildAndroidResult(NfcTag tag) async {
    final lines = <String>[];
    final androidTag = NfcTagAndroid.from(tag);
    final ndef = NdefAndroid.from(tag);
    final isoDep = IsoDepAndroid.from(tag);
    final nfcF = NfcFAndroid.from(tag);
    final mifareClassic = MifareClassicAndroid.from(tag);
    final mifareUltralight = MifareUltralightAndroid.from(tag);
    final nfcA = NfcAAndroid.from(tag);
    final nfcB = NfcBAndroid.from(tag);
    final nfcV = NfcVAndroid.from(tag);

    if (androidTag != null) {
      lines.add('Android tech: ${androidTag.techList.join(', ')}');
      lines.add('Tag id: ${_hex(androidTag.id)}');
    }

    if (ndef != null) {
      final recordCount = ndef.cachedNdefMessage?.records.length ?? 0;
      lines.add('NDEF type: ${ndef.type}');
      lines.add('NDEF max size: ${ndef.maxSize} bytes');
      lines.add('NDEF writable: ${ndef.isWritable ? 'yes' : 'no'}');
      lines.add('Cached NDEF records: $recordCount');
      if (isoDep != null) {
        lines.add(
          'This also exposes ISO-DEP, which makes it a possible Android HCE investigation candidate.',
        );
      }
      return NfcScanResult(
        status: CompatibilityStatus.nfcReadable,
        summary: 'NFC NDEF readable',
        detail: lines.join('\n'),
      );
    }

    if (isoDep != null) {
      if (isoDep.historicalBytes != null) {
        lines.add('Historical bytes: ${_hex(isoDep.historicalBytes!)}');
      }
      if (isoDep.hiLayerResponse != null) {
        lines.add('HiLayerResponse: ${_hex(isoDep.hiLayerResponse!)}');
      }
      lines.add(
        'Possible Android HCE candidate: ISO-DEP is present, but Card Box does not emulate this card yet.',
      );
      return NfcScanResult(
        status: CompatibilityStatus.androidHceCandidate,
        summary: 'ISO-DEP tag detected',
        detail: lines.join('\n'),
      );
    }

    if (nfcF != null) {
      lines.add('Detected NFC-F / FeliCa style tag.');
      lines.add('Manufacturer: ${_hex(nfcF.manufacturer)}');
      lines.add('System code: ${_hex(nfcF.systemCode)}');
      lines.add(
        'Phones can often detect this family, but many real cards do not expose reusable user data for this app.',
      );
      return NfcScanResult(
        status: CompatibilityStatus.nfcDetectedNotReadable,
        summary: 'FeliCa-style card detected',
        detail: lines.join('\n'),
      );
    }

    if (mifareClassic != null) {
      lines.add(
        'Detected MIFARE Classic (${mifareClassic.type.name}), ${mifareClassic.size} bytes.',
      );
      lines.add(
        'Android can see the card family, but reading secure sectors usually needs card-specific keys.',
      );
      return NfcScanResult(
        status: CompatibilityStatus.nfcDetectedNotReadable,
        summary: 'MIFARE Classic detected',
        detail: lines.join('\n'),
      );
    }

    if (mifareUltralight != null) {
      lines.add('Detected MIFARE Ultralight (${mifareUltralight.type.name}).');
      lines.add(
        'This phone can identify the tag family, but the app did not get readable NDEF content.',
      );
      return NfcScanResult(
        status: CompatibilityStatus.nfcDetectedNotReadable,
        summary: 'MIFARE Ultralight detected',
        detail: lines.join('\n'),
      );
    }

    if (nfcA != null || nfcB != null || nfcV != null) {
      lines.add(
        'The phone detected a low-level NFC tag family, but the app could not read reusable user data.',
      );
      return NfcScanResult(
        status: CompatibilityStatus.nfcDetectedNotReadable,
        summary: 'NFC tag detected',
        detail: lines.join('\n'),
      );
    }

    return NfcScanResult(
      status: CompatibilityStatus.nfcDetectedNotReadable,
      summary: 'NFC detected, but no readable tag details were exposed.',
      detail: lines.isEmpty
          ? 'The tag was discovered but no readable summary was available.'
          : lines.join('\n'),
    );
  }

  Future<NfcScanResult> _buildIosResult(NfcTag tag) async {
    final lines = <String>[];
    final ndef = NdefIos.from(tag);
    final feliCa = FeliCaIos.from(tag);
    final miFare = MiFareIos.from(tag);
    final iso7816 = Iso7816Ios.from(tag);
    final iso15693 = Iso15693Ios.from(tag);

    if (ndef != null) {
      final recordCount = ndef.cachedNdefMessage?.records.length ?? 0;
      lines.add('iOS capacity: ${ndef.capacity} bytes');
      lines.add('iOS NDEF status: ${ndef.status.name}');
      lines.add('Cached NDEF records: $recordCount');
      return NfcScanResult(
        status: CompatibilityStatus.nfcReadable,
        summary: 'NFC NDEF readable',
        detail: lines.join('\n'),
      );
    }

    if (feliCa != null) {
      lines.add('Detected FeliCa tag.');
      lines.add('System code: ${_hex(feliCa.currentSystemCode)}');
      lines.add('IDm: ${_hex(feliCa.currentIDm)}');
      return NfcScanResult(
        status: CompatibilityStatus.nfcDetectedNotReadable,
        summary: 'FeliCa-style card detected',
        detail: lines.join('\n'),
      );
    }

    if (miFare != null) {
      lines.add('Detected MiFare tag (${miFare.mifareFamily.name}).');
      lines.add('Identifier: ${_hex(miFare.identifier)}');
      return NfcScanResult(
        status: CompatibilityStatus.nfcDetectedNotReadable,
        summary: 'MiFare tag detected',
        detail: lines.join('\n'),
      );
    }

    if (iso7816 != null) {
      lines.add('Detected ISO 7816 tag.');
      lines.add('Identifier: ${_hex(iso7816.identifier)}');
      if (iso7816.initialSelectedAID.isNotEmpty) {
        lines.add('Initial selected AID: ${iso7816.initialSelectedAID}');
      }
      return NfcScanResult(
        status: CompatibilityStatus.nfcDetectedNotReadable,
        summary: 'ISO 7816 tag detected',
        detail: lines.join('\n'),
      );
    }

    if (iso15693 != null) {
      lines.add('Detected ISO 15693 tag.');
      lines.add('Identifier: ${_hex(iso15693.identifier)}');
      return NfcScanResult(
        status: CompatibilityStatus.nfcDetectedNotReadable,
        summary: 'ISO 15693 tag detected',
        detail: lines.join('\n'),
      );
    }

    return const NfcScanResult(
      status: CompatibilityStatus.nfcDetectedNotReadable,
      summary: 'NFC detected, but no readable tag details were exposed.',
      detail: 'The iOS tag session found a card without readable NDEF data.',
    );
  }

  String _hex(List<int> bytes) {
    return bytes
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join(':');
  }

  Future<void> _stopSessionSafely({
    String? alertMessageIos,
    String? errorMessageIos,
  }) async {
    try {
      await _sessionClient.stopSession(
        alertMessageIos: alertMessageIos,
        errorMessageIos: errorMessageIos,
      );
    } catch (error) {
      // Session shutdown can race with device state; avoid surfacing that as a
      // user-facing failure when we already have a meaningful result.
      if (kDebugMode) {
        debugPrint('NfcService: stopSession race, ignoring: $error');
      }
    }
  }
}
