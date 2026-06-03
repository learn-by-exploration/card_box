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

    await NfcManager.instance.startSession(
      pollingOptions: const {
        NfcPollingOption.iso14443,
        NfcPollingOption.iso15693,
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
          await NfcManager.instance.stopSession(
            alertMessageIos: 'Tag read complete.',
          );
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
          await NfcManager.instance.stopSession(
            errorMessageIos: 'Unable to read this card.',
          );
        }
      },
    );

    return completer.future.timeout(
      const Duration(seconds: 20),
      onTimeout: () async {
        await NfcManager.instance.stopSession(
          errorMessageIos: 'Timed out waiting for a card.',
        );
        return const NfcScanResult(
          status: CompatibilityStatus.unsupported,
          summary: 'No NFC card was detected in time.',
          detail: 'Try again with the card closer to the phone.',
        );
      },
    );
  }

  Future<NfcScanResult> _buildResult(NfcTag tag) async {
    final lines = <String>[];

    if (defaultTargetPlatform == TargetPlatform.android) {
      final androidTag = NfcTagAndroid.from(tag);
      final ndef = NdefAndroid.from(tag);
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
        return NfcScanResult(
          status: CompatibilityStatus.nfcReadable,
          summary: 'NFC NDEF readable',
          detail: lines.join('\n'),
        );
      }
      return NfcScanResult(
        status: CompatibilityStatus.nfcDetectedNotReadable,
        summary: 'NFC detected, but no NDEF payload was exposed.',
        detail: lines.isEmpty
            ? 'The tag was discovered but no readable summary was available.'
            : lines.join('\n'),
      );
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final ndef = NdefIos.from(tag);
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
      return const NfcScanResult(
        status: CompatibilityStatus.nfcDetectedNotReadable,
        summary: 'NFC detected, but no readable NDEF payload was exposed.',
        detail: 'The iOS tag session found a card without readable NDEF data.',
      );
    }

    return NfcScanResult(
      status: CompatibilityStatus.unsupported,
      summary: 'NFC is not supported on ${defaultTargetPlatform.name}.',
      detail: 'No NFC summary is available on this platform.',
    );
  }

  String _hex(List<int> bytes) {
    return bytes
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join(':');
  }
}
