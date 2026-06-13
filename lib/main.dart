import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:card_box/models/recovered_media_draft.dart';
import 'package:card_box/screens/app_root.dart';
import 'package:card_box/services/app_lock_service.dart';
import 'package:card_box/services/card_repository.dart';
import 'package:card_box/services/category_service.dart';
import 'package:card_box/services/media_recovery_service.dart';
import 'package:card_box/services/theme_service.dart';
import 'package:card_box/theme.dart';
import 'package:card_box/models/card_category.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = await SharedPreferences.getInstance();
  final mediaRecoveryService = MediaRecoveryService(preferences: preferences);
  final categoryService = CategoryService(preferences: preferences);
  await categoryService.init();
  final themeService = ThemeService(preferences: preferences);
  await themeService.init();
  final repository = CardRepository(
    seedDemoCards: const bool.fromEnvironment('CARD_BOX_SEED_DEMOS'),
    legacyPreferences: preferences,
  );
  await repository.init();
  // When a custom category is renamed, every card whose
  // `customCategory` matched the old label must be rewritten to the
  // new one — otherwise the rename orphans the cards. The service
  // only knows the labels; the repository owns the cards, so it
  // installs the hook here.
  await categoryService.setCategoryMigrationHook(
    (from, to) async {
      await repository.migrateCustomCategory(
        fromLabel: from,
        toCategory: CardCategory.other,
        toCustomCategory: to,
      );
    },
  );
  final recoveredMediaDraft = await mediaRecoveryService
      .recoverLostPhotoDraft();
  final appLockService = AppLockService(preferences: preferences);
  await appLockService.init();
  runApp(
    CardBoxApp(
      repository: repository,
      appLockService: appLockService,
      categoryService: categoryService,
      themeService: themeService,
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
    required this.categoryService,
    required this.themeService,
    required this.mediaRecoveryService,
    this.recoveredMediaDraft,
  });

  final CardRepository repository;
  final AppLockService appLockService;
  final CategoryService categoryService;
  final ThemeService themeService;
  final MediaRecoveryService mediaRecoveryService;
  final RecoveredMediaDraft? recoveredMediaDraft;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themeService,
      builder: (context, _) => MaterialApp(
        title: 'Card Box',
        theme: cardBoxLightThemeFor(themeService.palette),
        darkTheme: cardBoxDarkThemeFor(themeService.palette),
        themeMode: themeService.themeMode,
        debugShowCheckedModeBanner: false,
        home: AppRoot(
          repository: repository,
          appLockService: appLockService,
          categoryService: categoryService,
          themeService: themeService,
          mediaRecoveryService: mediaRecoveryService,
          recoveredMediaDraft: recoveredMediaDraft,
        ),
      ),
    );
  }
}
