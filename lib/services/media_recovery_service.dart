import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:card_box/models/add_card_preset.dart';
import 'package:card_box/models/recovered_media_draft.dart';
import 'package:card_box/services/card_media_store.dart' as media_store;

class MediaRecoveryService {
  MediaRecoveryService({required this._preferences, ImagePicker? imagePicker})
    : _imagePicker = imagePicker ?? ImagePicker();

  static const _pendingRequestKey = 'card_box.pending_media_request.v1';
  static const _pendingAttemptsKey =
      'card_box.pending_media_request.attempts.v1';
  static const _maxRecoveryAttempts = 3;

  final SharedPreferences _preferences;
  final ImagePicker _imagePicker;

  Future<void> markPendingPhotoRequest({
    required String draftCardId,
    required AddCardPreset preset,
    required String side,
    String? existingCardId,
  }) async {
    final payload = jsonEncode({
      'draftCardId': draftCardId,
      'preset': preset.name,
      'side': side,
      'existingCardId': existingCardId,
    });
    await _preferences.setString(_pendingRequestKey, payload);
    // Reset the attempt counter so a freshly marked request starts at 0.
    await _preferences.setInt(_pendingAttemptsKey, 0);
  }

  Future<void> clearPendingPhotoRequest() async {
    await _preferences.remove(_pendingRequestKey);
    await _preferences.remove(_pendingAttemptsKey);
  }

  Future<RecoveredMediaDraft?> recoverLostPhotoDraft() async {
    final pending = _readPendingRequest();
    final response = await _imagePicker.retrieveLostData();
    final files = response.files;
    if (files == null || files.isEmpty) {
      // If there was no recoverable pending request to begin with,
      // we are not in the "user keeps dismissing the picker" loop —
      // we just have nothing to recover. Do not start the attempts
      // counter, otherwise a corrupt (and already cleared) payload
      // would still leave a stale counter behind.
      if (pending == null) {
        return null;
      }
      // Preserve the pending request so a future launch can still
      // try — but cap the number of failed attempts to avoid a
      // permanent stuck state if the user keeps dismissing the picker.
      final attempts = _preferences.getInt(_pendingAttemptsKey) ?? 0;
      final nextAttempts = attempts + 1;
      if (nextAttempts >= _maxRecoveryAttempts) {
        debugPrint(
          'Media recovery: giving up after $nextAttempts empty attempts.',
        );
        await clearPendingPhotoRequest();
      } else {
        await _preferences.setInt(_pendingAttemptsKey, nextAttempts);
      }
      return null;
    }
    final request = pending ?? _PendingMediaRequest.fallback();
    final storedPath = await media_store.storePickedImage(
      files.first,
      cardId: request.draftCardId,
      side: request.side,
    );
    await clearPendingPhotoRequest();
    return RecoveredMediaDraft(
      draftCardId: request.draftCardId,
      preset: request.preset,
      existingCardId: request.existingCardId,
      frontImagePath: request.side == 'front' ? storedPath : '',
      backImagePath: request.side == 'back' ? storedPath : '',
    );
  }

  Future<void> discardRecoveredDraft(RecoveredMediaDraft draft) async {
    if (draft.frontImagePath.isNotEmpty) {
      await media_store.deleteStoredImage(draft.frontImagePath);
    }
    if (draft.backImagePath.isNotEmpty) {
      await media_store.deleteStoredImage(draft.backImagePath);
    }
  }

  _PendingMediaRequest? _readPendingRequest() {
    final raw = _preferences.getString(_pendingRequestKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        // The blob is non-empty JSON but not the shape we wrote —
        // most likely an old version of the app. Drop it so the
        // next launch starts clean and the user is not stuck
        // silently without a recovery banner.
        if (kDebugMode) {
          debugPrint(
            'MediaRecovery: pending payload is not a JSON map, dropping',
          );
        }
        unawaited(clearPendingPhotoRequest());
        return null;
      }
      return _PendingMediaRequest.fromJson(decoded);
    } catch (error) {
      if (kDebugMode) {
        debugPrint(
          'MediaRecovery: pending payload is corrupt, dropping: $error',
        );
      }
      unawaited(clearPendingPhotoRequest());
      return null;
    }
  }
}

class _PendingMediaRequest {
  const _PendingMediaRequest({
    required this.draftCardId,
    required this.preset,
    required this.side,
    required this.existingCardId,
  });

  factory _PendingMediaRequest.fromJson(Map<String, dynamic> json) {
    return _PendingMediaRequest(
      draftCardId:
          (json['draftCardId'] as String?) ??
          'recovered-${DateTime.now().microsecondsSinceEpoch}',
      preset: _presetFromName(json['preset'] as String?),
      side: (json['side'] as String?) == 'back' ? 'back' : 'front',
      existingCardId: json['existingCardId'] as String?,
    );
  }

  factory _PendingMediaRequest.fallback() {
    return _PendingMediaRequest(
      draftCardId: 'recovered-${DateTime.now().microsecondsSinceEpoch}',
      preset: AddCardPreset.general,
      side: 'front',
      existingCardId: null,
    );
  }

  final String draftCardId;
  final AddCardPreset preset;
  final String side;
  final String? existingCardId;

  static AddCardPreset _presetFromName(String? value) {
    for (final preset in AddCardPreset.values) {
      if (preset.name == value) {
        return preset;
      }
    }
    return AddCardPreset.general;
  }
}
