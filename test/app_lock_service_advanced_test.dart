// Tests for `AppLockService`.
// The existing test suite covers the happy path: enable
// lock, unlock with PIN, disable. This file pins down
// the failure-path branches — wrong PIN, biometrics
// disabled at the device level, the trusted-flow
// counter contract, and the lock-for-resume decision
// tree.

import 'package:flutter_test/flutter_test.dart';

import 'test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppLockService.unlockWithPin', () {
    test('returns false for a wrong PIN and stays locked', () async {
      final service = await createReadyAppLockService(
        lockEnabled: true,
        pin: '123456',
      );
      // Lock first.
      service.lockForResume();
      expect(service.unlocked, isFalse);

      final ok = await service.unlockWithPin('000000');
      expect(ok, isFalse);
      // Still locked.
      expect(service.unlocked, isFalse);
    });

    test('returns false when the secure store has no PIN', () async {
      // The user disabled and re-enabled the lock in a
      // way that left the secure store empty. The unlock
      // path must NOT crash and must return false.
      final service = await createReadyAppLockService(
        lockEnabled: true,
        // No pin argument → the store stays empty.
      );

      final ok = await service.unlockWithPin('123456');
      expect(ok, isFalse);
    });
  });

  group('AppLockService.unlockWithBiometrics', () {
    test('returns false when biometric is not enabled in settings', () async {
      // Even if the device supports biometrics, the user
      // did not opt in — the service must not invoke the
      // device prompt.
      final service = await createReadyAppLockService(
        lockEnabled: true,
        biometricsEnabled: false,
        biometricsEnrolled: true,
        pin: '123456',
      );

      final ok = await service.unlockWithBiometrics();
      expect(ok, isFalse);
    });

    test(
      'returns false when no biometrics are enrolled on the device',
      () async {
        final service = await createReadyAppLockService(
          lockEnabled: true,
          biometricsEnabled: true,
          biometricsEnrolled: false,
          pin: '123456',
        );

        final ok = await service.unlockWithBiometrics();
        expect(ok, isFalse);
      },
    );

    test('unlocks when biometrics succeed', () async {
      final auth = FakeDeviceAuthService(
        biometricsEnrolled: true,
        authenticateResult: true,
      );
      final service = await createReadyAppLockService(
        lockEnabled: true,
        biometricsEnabled: true,
        biometricsEnrolled: true,
        pin: '123456',
        deviceAuthService: auth,
      );
      service.lockForResume();
      expect(service.unlocked, isFalse);

      final ok = await service.unlockWithBiometrics();
      expect(ok, isTrue);
      expect(service.unlocked, isTrue);
      expect(auth.authenticateCalls, 1);
    });

    test('stays locked when biometrics are rejected', () async {
      final auth = FakeDeviceAuthService(
        biometricsEnrolled: true,
        authenticateResult: false,
      );
      final service = await createReadyAppLockService(
        lockEnabled: true,
        biometricsEnabled: true,
        biometricsEnrolled: true,
        pin: '123456',
        deviceAuthService: auth,
      );
      service.lockForResume();

      final ok = await service.unlockWithBiometrics();
      expect(ok, isFalse);
      expect(service.unlocked, isFalse);
    });
  });

  group('AppLockService.trusted flow', () {
    test('deferringBackgroundLock reflects the trusted flow counter', () async {
      final service = await createReadyAppLockService();
      expect(service.deferringBackgroundLock, isFalse);

      service.beginTrustedExternalFlow();
      expect(service.deferringBackgroundLock, isTrue);

      service.endTrustedExternalFlow();
      expect(service.deferringBackgroundLock, isFalse);
    });

    test('deferringBackgroundLock is true for nested flows', () async {
      // The counter is the number of active flows, not a
      // boolean. Two concurrent flows must each increment
      // and each decrement, so a single endTrustedExternal
      // call keeps the defer alive when the other is still
      // open.
      final service = await createReadyAppLockService();
      service.beginTrustedExternalFlow();
      service.beginTrustedExternalFlow();
      expect(service.deferringBackgroundLock, isTrue);

      service.endTrustedExternalFlow();
      // One flow still open.
      expect(service.deferringBackgroundLock, isTrue);

      service.endTrustedExternalFlow();
      expect(service.deferringBackgroundLock, isFalse);
    });

    test('endTrustedExternalFlow on an empty counter is a no-op', () async {
      final service = await createReadyAppLockService();
      // Should not throw, should not change state.
      service.endTrustedExternalFlow();
      expect(service.deferringBackgroundLock, isFalse);
    });

    test('lockForResume is skipped when a trusted flow is active', () async {
      // A trusted external flow (e.g. the camera scanner)
      // asks the service to skip the background-lock
      // re-prompt. The service must honor this and not
      // re-lock the app.
      final service = await createReadyAppLockService(
        lockEnabled: true,
        lockOnResume: true,
        pin: '123456',
      );
      // Unlock first.
      expect(await service.unlockWithPin('123456'), isTrue);
      // Begin the trusted flow (e.g. open the scanner).
      service.beginTrustedExternalFlow();
      // The app goes to the background. On resume, the
      // service would normally re-lock — but the trusted
      // flow defers the re-prompt.
      service.lockForResume();
      expect(service.unlocked, isTrue);
      service.endTrustedExternalFlow();
    });

    test('reclaims a stale trusted flow counter after 60s', () async {
      // The 60s max-age guarantees the trust window is
      // reclaimed no matter what — a force-killed flow's
      // `finally` would never have run, so the counter
      // would be stuck. The clock injection lets the test
      // simulate the passage of time.
      var now = DateTime.utc(2024, 1, 1, 0, 0, 0);
      final service = await createReadyAppLockService(clock: () => now);
      service.beginTrustedExternalFlow();
      expect(service.deferringBackgroundLock, isTrue);

      // Jump 61s ahead.
      now = now.add(const Duration(seconds: 61));
      // The next read of deferringBackgroundLock must
      // reclaim the stale counter.
      expect(service.deferringBackgroundLock, isFalse);
    });

    test('resetForDetached clears the counter immediately', () async {
      // The OS can detach the activity (force-kill) at
      // any time. The service must clear the trust
      // counter so a re-launch starts clean.
      final service = await createReadyAppLockService();
      service.beginTrustedExternalFlow();
      service.resetForDetached();
      expect(service.deferringBackgroundLock, isFalse);
    });
  });

  group('AppLockService.lockForResume decision tree', () {
    test('does not lock when lock is not enabled', () async {
      final service = await createReadyAppLockService();
      // lockEnabled defaults to false.
      expect(service.shouldShowLockScreen, isFalse);
      service.lockForResume();
      expect(service.unlocked, isTrue);
    });

    test('does not lock when lockOnResume is false', () async {
      final service = await createReadyAppLockService(
        lockEnabled: true,
        lockOnResume: false,
        pin: '123456',
      );
      // Unlock the app first.
      expect(await service.unlockWithPin('123456'), isTrue);
      expect(service.unlocked, isTrue);
      // lockOnResume is false — the service should
      // never re-lock on resume.
      service.lockForResume();
      expect(service.unlocked, isTrue);
    });
  });
}
