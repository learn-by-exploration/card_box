// Tests for `MediaRecoveryService`.
// The service handles the "I picked an image, the system
// killed my app, I want it back on next launch" flow. The
// existing tests cover the happy-path round trip. This
// file pins down the failure-path branches — corrupt
// pending payloads, the empty-recovery attempt cap, and
// the front/back side routing.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:card_box/models/add_card_preset.dart';
import 'package:card_box/services/media_recovery_service.dart';

import 'test_support.dart';

class _FakeImagePickerPlatform extends ImagePickerPlatform {
  LostDataResponse response = LostDataResponse.empty();

  @override
  Future<LostDataResponse> getLostData() async => response;

  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async {
    throw UnimplementedError();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ImagePickerPlatform.instance = _FakeImagePickerPlatform();
    // path_provider is consumed by the IO storePickedImage
    // implementation. Provide a real temp directory so the
    // bytes actually land on disk during the round trip.
    final tmp = await Directory.systemTemp.createTemp('recovery_init');
    PathProviderPlatform.instance = FakePathProviderPlatform(
      applicationDocumentsPath: tmp.path,
    );
  });

  group('MediaRecoveryService.recoverLostPhotoDraft', () {
    test(
      'returns null when there is no pending request and no lost data',
      () async {
        // Cold start: no pending payload, no lost data — there
        // is nothing to recover.
        final service = MediaRecoveryService(
          preferences: await SharedPreferences.getInstance(),
        );
        final result = await service.recoverLostPhotoDraft();
        expect(result, isNull);
      },
    );

    test('drops a corrupt pending payload and returns null', () async {
      // A pending payload that is not a JSON object is most
      // likely a legacy version of the app. The service
      // drops it on read so the next launch starts clean.
      SharedPreferences.setMockInitialValues({
        'card_box.pending_media_request.v1': 'not a map',
      });
      final prefs = await SharedPreferences.getInstance();
      final service = MediaRecoveryService(preferences: prefs);
      final result = await service.recoverLostPhotoDraft();
      expect(result, isNull);
      // The corrupt payload is removed.
      expect(prefs.getString('card_box.pending_media_request.v1'), isNull);
    });

    test('drops a malformed-JSON pending payload and returns null', () async {
      SharedPreferences.setMockInitialValues({
        'card_box.pending_media_request.v1': '{not-valid-json',
      });
      final prefs = await SharedPreferences.getInstance();
      final service = MediaRecoveryService(preferences: prefs);
      final result = await service.recoverLostPhotoDraft();
      expect(result, isNull);
      expect(prefs.getString('card_box.pending_media_request.v1'), isNull);
    });

    test('bumps the empty-attempts counter and clears after the cap', () async {
      // The user keeps dismissing the picker. After 3 empty
      // recovery attempts the pending payload is dropped
      // so the user is not stuck in a loop.
      SharedPreferences.setMockInitialValues({
        'card_box.pending_media_request.v1':
            '{"draftCardId":"d1","preset":"general","side":"front"}',
        'card_box.pending_media_request.attempts.v1': 0,
      });
      final prefs = await SharedPreferences.getInstance();
      final service = MediaRecoveryService(preferences: prefs);
      final picker = ImagePickerPlatform.instance as _FakeImagePickerPlatform;
      picker.response = LostDataResponse.empty();

      // First call: attempts becomes 1.
      await service.recoverLostPhotoDraft();
      expect(prefs.getInt('card_box.pending_media_request.attempts.v1'), 1);
      // Second call: attempts becomes 2.
      await service.recoverLostPhotoDraft();
      expect(prefs.getInt('card_box.pending_media_request.attempts.v1'), 2);
      // Third call: the cap (3) is hit, the payload is
      // dropped.
      await service.recoverLostPhotoDraft();
      expect(prefs.getString('card_box.pending_media_request.v1'), isNull);
    });

    test(
      'does NOT bump the counter on a cold start (no pending request)',
      () async {
        // The "no pending + no lost data" branch must NOT
        // start the attempts counter — otherwise a stale
        // counter could outlive a real clear.
        final prefs = await SharedPreferences.getInstance();
        final service = MediaRecoveryService(preferences: prefs);
        await service.recoverLostPhotoDraft();
        expect(
          prefs.getInt('card_box.pending_media_request.attempts.v1'),
          isNull,
        );
      },
    );

    test('routes a front-side recovery to frontImagePath', () async {
      SharedPreferences.setMockInitialValues({
        'card_box.pending_media_request.v1':
            '{"draftCardId":"d1","preset":"general","side":"front"}',
      });
      final prefs = await SharedPreferences.getInstance();
      final service = MediaRecoveryService(preferences: prefs);
      final picker = ImagePickerPlatform.instance as _FakeImagePickerPlatform;
      // The storePickedImage IO implementation reads the
      // XFile bytes from disk, so we create a real file
      // (the test runtime picks the IO variant of the
      // card_media_store top-level functions).
      final tmp = await Directory.systemTemp.createTemp('recovery_front');
      final source = File('${tmp.path}/front.jpg')
        ..writeAsBytesSync(<int>[0, 1, 2]);
      picker.response = LostDataResponse(
        type: RetrieveType.image,
        files: <XFile>[XFile(source.path)],
      );

      final result = await service.recoverLostPhotoDraft();
      expect(result, isNotNull);
      expect(result!.frontImagePath, isNotEmpty);
      expect(result.backImagePath, isEmpty);
    });

    test('routes a back-side recovery to backImagePath', () async {
      SharedPreferences.setMockInitialValues({
        'card_box.pending_media_request.v1':
            '{"draftCardId":"d1","preset":"general","side":"back"}',
      });
      final prefs = await SharedPreferences.getInstance();
      final service = MediaRecoveryService(preferences: prefs);
      final picker = ImagePickerPlatform.instance as _FakeImagePickerPlatform;
      final tmp = await Directory.systemTemp.createTemp('recovery_back');
      final source = File('${tmp.path}/back.jpg')
        ..writeAsBytesSync(<int>[0, 1, 2]);
      picker.response = LostDataResponse(
        type: RetrieveType.image,
        files: <XFile>[XFile(source.path)],
      );

      final result = await service.recoverLostPhotoDraft();
      expect(result, isNotNull);
      expect(result!.backImagePath, isNotEmpty);
      expect(result.frontImagePath, isEmpty);
    });

    test(
      'uses a fallback draft card id when the pending request is missing',
      () async {
        // Lost data is present but the pending payload is
        // gone (e.g. user cleared storage between launches).
        // The service must still recover, attributing the
        // image to a fallback draft id with the default
        // preset and side.
        final prefs = await SharedPreferences.getInstance();
        final service = MediaRecoveryService(preferences: prefs);
        final picker = ImagePickerPlatform.instance as _FakeImagePickerPlatform;
        final tmp = await Directory.systemTemp.createTemp('recovery_fb');
        final source = File('${tmp.path}/fb.jpg')
          ..writeAsBytesSync(<int>[0, 1, 2]);
        picker.response = LostDataResponse(
          type: RetrieveType.image,
          files: <XFile>[XFile(source.path)],
        );

        final result = await service.recoverLostPhotoDraft();
        expect(result, isNotNull);
        expect(result!.draftCardId, startsWith('recovered-'));
        expect(result.preset, AddCardPreset.general);
      },
    );
  });

  group('MediaRecoveryService.markPendingPhotoRequest', () {
    test('resets the attempts counter to 0', () async {
      // A stale counter from a previous request must NOT
      // carry over — the new request starts at 0.
      SharedPreferences.setMockInitialValues({
        'card_box.pending_media_request.v1': '{"stale":true}',
        'card_box.pending_media_request.attempts.v1': 2,
      });
      final prefs = await SharedPreferences.getInstance();
      final service = MediaRecoveryService(preferences: prefs);

      await service.markPendingPhotoRequest(
        draftCardId: 'd-new',
        preset: AddCardPreset.general,
        side: 'front',
      );

      expect(prefs.getInt('card_box.pending_media_request.attempts.v1'), 0);
      final stored = prefs.getString('card_box.pending_media_request.v1');
      expect(stored, isNotNull);
      expect(stored, contains('d-new'));
    });
  });
}
