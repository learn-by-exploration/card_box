/// TTS service interface.
///
/// The interface is pure Dart (no `package:flutter/*` imports) so
/// unit tests can construct a `FakeTtsService` without a platform
/// channel. The default production implementation lives in
/// `tts_service_io.dart` (Android: `flutter_tts`; iOS: same plugin)
/// and `tts_service_stub.dart` (no-op for `flutter test`).
///
/// Why an interface? The widget layer must be able to call
/// `tts.speak(...)` in unit tests; the `flutter_tts` plugin cannot
/// be constructed in a `flutter test` environment because it
/// registers platform channels at construction time. Dependency-
/// injecting the interface keeps the widget pure-Dart-testable and
/// matches the existing service pattern (`AppLockService`,
/// `DeviceAuthService`, `SecureStore`).
///
/// The interface is intentionally minimal: speak a string,
/// optionally interrupt the current utterance, optionally stop
/// the engine. A future "list available voices" or "set pitch /
/// rate" capability can be added when the user needs it; the
/// Settings screen will then expose a small voice-test affordance.
library;

abstract class TtsService {
  /// Speak [text] aloud. Implementations may interrupt the current
  /// utterance (so a rapid "Read aloud" tap replaces the previous
  /// speech instead of queuing behind it) or may queue. The default
  /// implementation interrupts.
  ///
  /// Returns a future that completes when the platform reports
  /// "utterance completed" (Android) or the equivalent on iOS.
  /// The future is allowed to complete with an error if TTS is
  /// unavailable; the widget layer should catch and surface a
  /// snackbar.
  Future<void> speak(String text);

  /// Stop the current utterance, if any. Idempotent. Used when
  /// the user navigates away from the present screen mid-speech.
  Future<void> stop();

  /// Whether the service is currently speaking. Used by the widget
  /// to swap the "Read aloud" icon for a "Stop" icon.
  bool get isSpeaking;
}

/// A no-op implementation used by `flutter test` and by platforms
/// where TTS is unavailable (web, desktop without an engine).
/// `speak` is a fire-and-forget no-op; `stop` and `isSpeaking` are
/// inert. Tests can subclass this to record calls.
class NoOpTtsService implements TtsService {
  /// Optional recorder used by tests.
  final List<String> spoken = <String>[];

  @override
  Future<void> speak(String text) async {
    spoken.add(text);
  }

  @override
  Future<void> stop() async {}

  @override
  bool get isSpeaking => false;
}
