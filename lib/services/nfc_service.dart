import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';
import 'package:nfc_manager/nfc_manager_ios.dart';

import 'package:card_box/models/compatibility_status.dart';
import 'package:card_box/models/nfc_scan_result.dart';

class NfcService {
  Future<NfcAvailability> checkAvailability() async {
    if (kIsWeb) {
      return NfcAvailability.unsupported;
    }
    try {
      return await NfcManager.instance.checkAvailability();
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
    try {
      await NfcManager.instance.startSession(
        pollingOptions: const {
          NfcPollingOption.iso14443,
          NfcPollingOption.iso15693,
          NfcPollingOption.iso18092,
        },
        alertMessageIos: 'Hold your phone near the card.',
        onSessionErrorIos: (error) {
          if (!completer.isCompleted) {
            completer.complete(
              NfcScanResult(
                status: CompatibilityStatus.unsupported,
                summary: 'NFC session error: ${error.message}',
                detail: 'The iOS reader session ended before a tag was saved.',
              ),
            );
          }
        },
        onDiscovered: (tag) async {
          try {
            final result = await _buildResult(tag);
            if (!completer.isCompleted) {
              completer.complete(result);
            }
            await _stopSessionSafely(alertMessageIos: 'Tag read complete.');
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
            await _stopSessionSafely(
              errorMessageIos: 'Unable to read this card.',
            );
          }
        },
      );

      return completer.future.timeout(
        const Duration(seconds: 20),
        onTimeout: () async {
          await _stopSessionSafely(
            errorMessageIos: 'Timed out waiting for a card.',
          );
          return const NfcScanResult(
            status: CompatibilityStatus.unsupported,
            summary: 'No NFC card was detected in time.',
            detail: 'Try again with the card closer to the phone.',
          );
        },
      );
    } catch (error) {
      await _stopSessionSafely();
      return NfcScanResult(
        status: CompatibilityStatus.unsupported,
        summary: 'The NFC session could not be started.',
        detail: 'Error: $error',
      );
    }
  }

  Future<NfcScanResult> _buildResult(NfcTag tag) async {
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => _buildAndroidResult(tag),
      TargetPlatform.iOS => _buildIosResult(tag),
      _ => NfcScanResult(
        status: CompatibilityStatus.unsupported,
        summary: 'NFC is not supported on ${defaultTargetPlatform.name}.',
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
      await NfcManager.instance.stopSession(
        alertMessageIos: alertMessageIos,
        errorMessageIos: errorMessageIos,
      );
    } catch (_) {
      // Session shutdown can race with device state; avoid surfacing that as a
      // user-facing failure when we already have a meaningful result.
    }
  }
}
