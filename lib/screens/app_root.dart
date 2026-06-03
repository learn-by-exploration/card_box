import 'package:flutter/material.dart';

import 'package:card_box/screens/app_lock_screen.dart';
import 'package:card_box/screens/home_screen.dart';
import 'package:card_box/services/app_lock_service.dart';
import 'package:card_box/services/card_repository.dart';

class AppRoot extends StatefulWidget {
  const AppRoot({
    super.key,
    required this.repository,
    required this.appLockService,
  });

  final CardRepository repository;
  final AppLockService appLockService;

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> with WidgetsBindingObserver {
  bool _obscureContent = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
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
      animation: Listenable.merge([widget.repository, widget.appLockService]),
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
              );
        return Stack(
          fit: StackFit.expand,
          children: [
            child,
            if (_obscureContent) const ColoredBox(color: Color(0xFF0F1713)),
          ],
        );
      },
    );
  }
}
