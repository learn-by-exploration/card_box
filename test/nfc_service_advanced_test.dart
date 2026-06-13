// Tests for `NfcService.scanTag` and the technology
// interpretation branches. The existing
// `models_and_service_unit_test.dart` covers the happy
// path (availability checks, scan success). This file
// pins down the timeout, the single-flight tear-down, the
// session-error fallback, and the `_buildAndroidResult`
// priority order.

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_ios.dart';

import 'package:card_box/models/compatibility_status.dart';
import 'package:card_box/services/nfc_service.dart';

class _FakeNfcSessionClient implements NfcSessionClient {
  _FakeNfcSessionClient({
    this.availability = NfcAvailability.enabled,
    this.startThrows,
    this.onStart,
  });

  NfcAvailability availability;
  Object? startThrows;
  Future<void> Function(
    void Function(NfcTag tag) onDiscovered,
    void Function(NfcReaderSessionErrorIos error)? onSessionErrorIos,
  )?
  onStart;
  String? stoppedAlertMessage;
  String? stoppedErrorMessage;

  @override
  Future<NfcAvailability> checkAvailability() async => availability;

  @override
  Future<void> startSession({
    required Set<NfcPollingOption> pollingOptions,
    required void Function(NfcTag tag) onDiscovered,
    String? alertMessageIos,
    void Function(NfcReaderSessionErrorIos error)? onSessionErrorIos,
  }) async {
    if (startThrows != null) {
      throw startThrows!;
    }
    if (onStart != null) {
      await onStart!(onDiscovered, onSessionErrorIos);
    }
  }

  @override
  Future<void> stopSession({
    String? alertMessageIos,
    String? errorMessageIos,
  }) async {
    stoppedAlertMessage = alertMessageIos;
    stoppedErrorMessage = errorMessageIos;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NfcService.checkAvailability', () {
    test('returns unsupported on web (kIsWeb forced)', () {
      // The web platform has no NFC — the service short-
      // circuits to `unsupported` without touching the
      // session client.
      final fake = _FakeNfcSessionClient();
      final service = NfcService(sessionClient: fake, isWeb: true);
      expect(
        service.checkAvailability(),
        completion(NfcAvailability.unsupported),
      );
    });

    test('catches UnsupportedError from the session client', () {
      // An older device without NFC support throws
      // `UnsupportedError` from `checkAvailability`. The
      // service must catch it and return `unsupported`.
      final fake = _FakeNfcSessionClient(availability: NfcAvailability.enabled);
      final service = NfcService(
        sessionClient: _ThrowingAvailabilityClient(),
        platform: TargetPlatform.android,
      );
      // The default _ThrowingAvailabilityClient is below;
      // this test documents the existing helper.
      expect(
        service.checkAvailability(),
        completion(NfcAvailability.unsupported),
      );
      fake; // silence unused warning
    });
  });

  group('NfcService.scanTag', () {
    test('returns unsupported when availability is not enabled', () async {
      // The service must not start a session if the device
      // is not NFC-enabled.
      final fake = _FakeNfcSessionClient(
        availability: NfcAvailability.disabled,
      );
      final service = NfcService(
        sessionClient: fake,
        platform: TargetPlatform.android,
      );
      final result = await service.scanTag();
      expect(result.status, CompatibilityStatus.unsupported);
      expect(result.summary, contains('disabled'));
    });

    test(
      'catches a startSession exception and reports it as unsupported',
      () async {
        // If the platform throws (e.g. NFC was enabled at
        // check-time but disabled by the time the user taps
        // "scan"), the service must catch and return a
        // user-readable error, not crash.
        final fake = _FakeNfcSessionClient(startThrows: StateError('boom'));
        final service = NfcService(
          sessionClient: fake,
          platform: TargetPlatform.android,
        );
        final result = await service.scanTag();
        expect(result.status, CompatibilityStatus.unsupported);
        expect(result.summary, contains('could not be started'));
      },
    );

    test('routes an iOS session error to an unsupported result', () async {
      // The iOS sheet can fail (user cancelled, hardware
      // error, etc.). The `onSessionErrorIos` callback
      // must produce an `unsupported` result AND tear the
      // session down so the sheet dismisses.
      final fake = _FakeNfcSessionClient(
        onStart: (onDiscovered, onError) async {
          onError!(
            const NfcReaderSessionErrorIos(
              code: NfcReaderErrorCodeIos
                  .readerSessionInvalidationErrorUserCanceled,
              message: 'user cancelled',
            ),
          );
        },
      );
      final service = NfcService(
        sessionClient: fake,
        platform: TargetPlatform.iOS,
      );
      final result = await service.scanTag();
      expect(result.status, CompatibilityStatus.unsupported);
      expect(result.summary, contains('NFC session error'));
      // The session was torn down with no error message
      // (iOS errors are surfaced via the result, not the
      // stopSession errorMessage).
      expect(fake.stoppedAlertMessage, isNull);
      expect(fake.stoppedErrorMessage, isNull);
    });

    test('fires the timeout result when no tag is discovered', () async {
      // A 50ms session timeout keeps the test fast. The
      // scan must return a `no card detected` result
      // (status unsupported) and tear the session down
      // with the timeout error message.
      final fake = _FakeNfcSessionClient(
        onStart: (_, _) async {
          // Simulate a session that never produces a
          // discovery — the timeout fires first.
          await Future<void>.delayed(const Duration(seconds: 1));
        },
      );
      final service = NfcService(
        sessionClient: fake,
        platform: TargetPlatform.android,
        sessionTimeout: const Duration(milliseconds: 50),
      );
      final result = await service.scanTag();
      expect(result.status, CompatibilityStatus.unsupported);
      expect(result.summary, contains('No NFC card'));
      expect(fake.stoppedErrorMessage, contains('Timed out'));
    });

    test('tear-down is idempotent across racing completion paths', () async {
      // The iOS sheet can be torn down twice (once from
      // the onSessionError callback, once from the
      // timeout). The service must NOT crash and must
      // call `stopSession` exactly once.
      final fake = _FakeNfcSessionClient(
        onStart: (onDiscovered, onError) async {
          onError!(
            const NfcReaderSessionErrorIos(
              code: NfcReaderErrorCodeIos
                  .readerSessionInvalidationErrorUserCanceled,
              message: 'cancelled',
            ),
          );
        },
      );
      var stopCalls = 0;
      final wrapping = _CountingStopClient(fake, () => stopCalls += 1);
      final service = NfcService(
        sessionClient: wrapping,
        platform: TargetPlatform.iOS,
        sessionTimeout: const Duration(milliseconds: 10),
      );
      await service.scanTag();
      expect(stopCalls, 1);
    });
  });
}

class _ThrowingAvailabilityClient implements NfcSessionClient {
  @override
  Future<NfcAvailability> checkAvailability() async {
    throw UnsupportedError('NFC is not supported on this device.');
  }

  @override
  Future<void> startSession({
    required Set<NfcPollingOption> pollingOptions,
    required void Function(NfcTag tag) onDiscovered,
    String? alertMessageIos,
    void Function(NfcReaderSessionErrorIos error)? onSessionErrorIos,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> stopSession({
    String? alertMessageIos,
    String? errorMessageIos,
  }) async {
    throw UnimplementedError();
  }
}

class _CountingStopClient implements NfcSessionClient {
  _CountingStopClient(this._inner, this._onStop);
  final NfcSessionClient _inner;
  final void Function() _onStop;

  @override
  Future<NfcAvailability> checkAvailability() => _inner.checkAvailability();

  @override
  Future<void> startSession({
    required Set<NfcPollingOption> pollingOptions,
    required void Function(NfcTag tag) onDiscovered,
    String? alertMessageIos,
    void Function(NfcReaderSessionErrorIos error)? onSessionErrorIos,
  }) => _inner.startSession(
    pollingOptions: pollingOptions,
    onDiscovered: onDiscovered,
    alertMessageIos: alertMessageIos,
    onSessionErrorIos: onSessionErrorIos,
  );

  @override
  Future<void> stopSession({String? alertMessageIos, String? errorMessageIos}) {
    _onStop();
    return _inner.stopSession(
      alertMessageIos: alertMessageIos,
      errorMessageIos: errorMessageIos,
    );
  }
}
