import 'package:flutter/material.dart';

import 'package:card_box/models/recovered_media_draft.dart';
import 'package:card_box/screens/app_lock_screen.dart';
import 'package:card_box/screens/home_screen.dart';
import 'package:card_box/services/app_lock_service.dart';
import 'package:card_box/services/card_repository.dart';
import 'package:card_box/services/category_service.dart';
import 'package:card_box/services/media_recovery_service.dart';
import 'package:card_box/services/theme_service.dart';
import 'package:card_box/theme.dart';

class AppRoot extends StatefulWidget {
  const AppRoot({
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
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> with WidgetsBindingObserver {
  bool _obscureContent = false;
  RecoveredMediaDraft? _recoveredMediaDraft;

  @override
  void initState() {
    super.initState();
    _recoveredMediaDraft = widget.recoveredMediaDraft;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) {
      // Hot-restart or fast-back can deliver lifecycle events after
      // dispose. Bail out before any setState to avoid the
      // "setState called after dispose" assertion.
      return;
    }
    if (state == AppLifecycleState.detached) {
      // The OS is reclaiming the process — drop any in-flight
      // trusted-flow counter so the next launch does not inherit
      // a stale "lock is deferred" state.
      widget.appLockService.resetForDetached();
    }
    if (state == AppLifecycleState.resumed) {
      if (_obscureContent) {
        setState(() => _obscureContent = false);
      }
      return;
    }
    if (widget.appLockService.deferringBackgroundLock) {
      return;
    }
    if (state == AppLifecycleState.inactive) {
      if (!_obscureContent) {
        setState(() => _obscureContent = true);
      }
      widget.appLockService.lockForResume();
      return;
    }
    if (state == AppLifecycleState.paused) {
      widget.appLockService.lockForResume();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        widget.repository,
        widget.appLockService,
        widget.categoryService,
      ]),
      builder: (context, _) {
        final appLock = widget.appLockService;
        if (!appLock.ready) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final child = appLock.shouldShowLockScreen
            ? AppLockScreen(appLockService: appLock)
            : HomeScreen(
                repository: widget.repository,
                appLockService: widget.appLockService,
                categoryService: widget.categoryService,
                themeService: widget.themeService,
                mediaRecoveryService: widget.mediaRecoveryService,
                recoveredMediaDraft: _recoveredMediaDraft,
                onRecoveredMediaUsed: _clearRecoveredMedia,
                onRecoveredMediaDiscarded: _discardRecoveredMedia,
              );
        return Stack(
          fit: StackFit.expand,
          children: [
            child,
            if (_obscureContent)
              ColoredBox(color: CardBoxThemeTokens.of(context).appObscureScrim),
          ],
        );
      },
    );
  }

  void _clearRecoveredMedia() {
    if (_recoveredMediaDraft == null) {
      return;
    }
    setState(() => _recoveredMediaDraft = null);
  }

  Future<void> _discardRecoveredMedia() async {
    final draft = _recoveredMediaDraft;
    if (draft == null) {
      return;
    }
    await widget.mediaRecoveryService.discardRecoveredDraft(draft);
    if (!mounted) {
      return;
    }
    setState(() => _recoveredMediaDraft = null);
  }
}
