import 'dart:async';

import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:card_box/models/wallet_card.dart';
import 'package:card_box/theme.dart';
import 'package:card_box/widgets/stored_card_image.dart';

class CardReferencePresentScreen extends StatefulWidget {
  const CardReferencePresentScreen({
    super.key,
    required this.card,
    this.onShown,
  });

  final WalletCard card;
  /// Optional callback fired once when the screen first renders.
  /// Used to record that the card was used (marking lastUsedAt and
  /// useCount). The returned future is awaited inside the post-frame
  /// callback so a thrown error is observed by the caller, not
  /// silently swallowed. Callers without a repository can leave
  /// this null.
  final Future<void> Function()? onShown;

  @override
  State<CardReferencePresentScreen> createState() =>
      _CardReferencePresentScreenState();
}

class _CardReferencePresentScreenState
    extends State<CardReferencePresentScreen> {
  late final PageController _pageController;
  late final List<_ReferencePage> _pages;
  int _currentPage = 0;
  bool _wakelockAcquired = false;
  bool _onShownFired = false;

  @override
  void initState() {
    super.initState();
    _pages = [
      if (widget.card.frontImagePath.trim().isNotEmpty)
        _ReferencePage(label: 'Front', imagePath: widget.card.frontImagePath),
      if (widget.card.backImagePath.trim().isNotEmpty)
        _ReferencePage(label: 'Back', imagePath: widget.card.backImagePath),
    ];
    _pageController = PageController();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (!_wakelockAcquired) {
        // The plugin is idempotent, but we still gate the call so a
        // hot-reload re-entry into initState does not double-acquire.
        _wakelockAcquired = true;
        try {
          await WakelockPlus.enable();
        } catch (error) {
          debugPrint('CardReferencePresentScreen: WakelockPlus.enable failed: $error');
          _wakelockAcquired = false;
        }
      }
      if (!mounted) return;
      final callback = widget.onShown;
      if (callback != null && !_onShownFired) {
        _onShownFired = true;
        try {
          await callback();
        } catch (error) {
          debugPrint('CardReferencePresentScreen: onShown callback failed: $error');
        }
      }
    });
  }

  @override
  void dispose() {
    if (_wakelockAcquired) {
      _wakelockAcquired = false;
      // Best-effort: a stuck wakelock is auto-cleared on Android when
      // the Activity is destroyed, but on iOS the idleTimerDisabled
      // flag would otherwise outlive this screen.
      unawaited(WakelockPlus.disable().catchError((Object error) {
        debugPrint('CardReferencePresentScreen: WakelockPlus.disable failed: $error');
      }));
    }
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tokens = CardBoxThemeTokens.of(context);
    return Scaffold(
      backgroundColor: tokens.appObscureScrim,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: Text(widget.card.name),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            children: [
              if (_pages.length > 1)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    children: [
                      for (var index = 0; index < _pages.length; index++)
                        Expanded(
                          child: TextButton(
                            style: TextButton.styleFrom(
                              backgroundColor: _currentPage == index
                                  ? colorScheme.primary
                                  : Colors.transparent,
                              foregroundColor: _currentPage == index
                                  ? colorScheme.onPrimary
                                  : Colors.white,
                            ),
                            onPressed: () => _jumpToPage(index),
                            child: Text(_pages[index].label),
                          ),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _pages.length,
                  onPageChanged: (page) {
                    setState(() => _currentPage = page);
                  },
                  itemBuilder: (context, index) {
                    final page = _pages[index];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          page.label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: StoredCardImage(
                                path: page.imagePath,
                                emptyLabel: page.label,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _jumpToPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
    setState(() => _currentPage = page);
  }
}

class _ReferencePage {
  const _ReferencePage({required this.label, required this.imagePath});

  final String label;
  final String imagePath;
}
