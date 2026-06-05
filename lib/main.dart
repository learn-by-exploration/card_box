import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:card_box/models/recovered_media_draft.dart';
import 'package:card_box/screens/app_root.dart';
import 'package:card_box/services/app_lock_service.dart';
import 'package:card_box/services/card_repository.dart';
import 'package:card_box/services/media_recovery_service.dart';
import 'package:card_box/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = await SharedPreferences.getInstance();
  final mediaRecoveryService = MediaRecoveryService(preferences: preferences);
  final repository = CardRepository(
    seedDemoCards: const bool.fromEnvironment('CARD_BOX_SEED_DEMOS'),
    legacyPreferences: preferences,
  );
  await repository.init();
  final recoveredMediaDraft = await mediaRecoveryService
      .recoverLostPhotoDraft();
  final appLockService = AppLockService(preferences: preferences);
  await appLockService.init();
  runApp(
    CardBoxApp(
      repository: repository,
      appLockService: appLockService,
      mediaRecoveryService: mediaRecoveryService,
      recoveredMediaDraft: recoveredMediaDraft,
    ),
  );
}

class CardBoxApp extends StatelessWidget {
  const CardBoxApp({
    super.key,
    required this.repository,
    required this.appLockService,
    required this.mediaRecoveryService,
    this.recoveredMediaDraft,
  });

  final CardRepository repository;
  final AppLockService appLockService;
  final MediaRecoveryService mediaRecoveryService;
  final RecoveredMediaDraft? recoveredMediaDraft;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Card Box',
      theme: cardBoxTheme,
      debugShowCheckedModeBanner: false,
      home: AppRoot(
        repository: repository,
        appLockService: appLockService,
        mediaRecoveryService: mediaRecoveryService,
        recoveredMediaDraft: recoveredMediaDraft,
      ),
    );
  }
}
