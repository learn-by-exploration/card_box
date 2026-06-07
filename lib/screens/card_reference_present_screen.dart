import 'package:flutter/material.dart';

import 'package:card_box/models/wallet_card.dart';
import 'package:card_box/theme.dart';
import 'package:card_box/widgets/stored_card_image.dart';

class CardReferencePresentScreen extends StatefulWidget {
  const CardReferencePresentScreen({super.key, required this.card});

  final WalletCard card;

  @override
  State<CardReferencePresentScreen> createState() =>
      _CardReferencePresentScreenState();
}

class _CardReferencePresentScreenState
    extends State<CardReferencePresentScreen> {
  late final PageController _pageController;
  late final List<_ReferencePage> _pages;
  int _currentPage = 0;

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
  }

  @override
  void dispose() {
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
