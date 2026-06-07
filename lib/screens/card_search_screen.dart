import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:card_box/models/wallet_card.dart';
import 'package:card_box/screens/barcode_present_screen.dart';
import 'package:card_box/screens/card_reference_present_screen.dart';
import 'package:card_box/services/card_repository.dart';
import 'package:card_box/theme.dart';
import 'package:card_box/widgets/card_tile.dart';

class CardSearchScreen extends StatefulWidget {
  const CardSearchScreen({
    super.key,
    required this.repository,
    required this.showContactsInitially,
  });

  final CardRepository repository;
  final bool showContactsInitially;

  @override
  State<CardSearchScreen> createState() => _CardSearchScreenState();
}

class _CardSearchScreenState extends State<CardSearchScreen> {
  static const _modePreferenceKey = 'card_box.search_mode.v1';

  final TextEditingController _queryController = TextEditingController();
  final FocusNode _queryFocusNode = FocusNode();
  late _SearchMode _mode;

  @override
  void initState() {
    super.initState();
    _mode = widget.showContactsInitially
        ? _SearchMode.contacts
        : _SearchMode.cards;
    _loadSavedMode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      FocusScope.of(context).requestFocus(_queryFocusNode);
    });
  }

  @override
  void dispose() {
    _queryController.dispose();
    _queryFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = CardBoxThemeTokens.of(context);
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: widget.repository,
      builder: (context, _) {
        final showingRecent = _queryController.text.trim().isEmpty;
        final results = _visibleCards(widget.repository.cards);
        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: TextField(
              controller: _queryController,
              focusNode: _queryFocusNode,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Search cards, contacts, codes, notes...',
                border: InputBorder.none,
              ),
              onChanged: (_) => setState(() {}),
              textInputAction: TextInputAction.search,
            ),
            actions: [
              if (_queryController.text.isNotEmpty)
                IconButton(
                  tooltip: 'Clear search',
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    _queryController.clear();
                    setState(() {});
                    FocusScope.of(context).requestFocus(_queryFocusNode);
                  },
                ),
            ],
          ),
          body: SafeArea(
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                tokens.spaceLarge,
                tokens.spaceSmall,
                tokens.spaceLarge,
                tokens.spaceXLarge + tokens.spaceXSmall,
              ),
              children: [
                SegmentedButton<_SearchMode>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: _SearchMode.cards,
                      icon: Icon(Icons.wallet_membership_outlined),
                      label: Text('Cards'),
                    ),
                    ButtonSegment(
                      value: _SearchMode.contacts,
                      icon: Icon(Icons.contact_page_outlined),
                      label: Text('Contacts'),
                    ),
                  ],
                  selected: {_mode},
                  onSelectionChanged: (selection) {
                    final nextMode = selection.first;
                    setState(() => _mode = nextMode);
                    _saveMode(nextMode);
                  },
                ),
                SizedBox(height: tokens.spaceMedium),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        results.isEmpty
                            ? (showingRecent ? 'No recent items' : 'No results')
                            : showingRecent
                            ? '${results.length} recent item${results.length == 1 ? '' : 's'}'
                            : '${results.length} result${results.length == 1 ? '' : 's'}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: tokens.spaceSmall),
                if (results.isEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: tokens.spaceSmall,
                      vertical: tokens.spaceXLarge + 12,
                    ),
                    child: Text(
                      showingRecent
                          ? 'Recent cards and contacts appear here when search is empty.'
                          : 'Try a different name, company, code, or note.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                  )
                else
                  for (var index = 0; index < results.length; index++) ...[
                    CardTile(
                      card: results[index],
                      onShowCode: results[index].hasBarcode
                          ? () => _showCardCode(results[index])
                          : null,
                      onShowImages: results[index].hasPhotos
                          ? () => _showCardImages(results[index])
                          : null,
                      onTap: () => Navigator.of(context).pop(results[index]),
                    ),
                    if (index != results.length - 1)
                      SizedBox(height: tokens.spaceMedium - 2),
                  ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _loadSavedMode() async {
    final preferences = await SharedPreferences.getInstance();
    final stored = preferences.getString(_modePreferenceKey);
    if (!mounted || stored == null) {
      return;
    }
    final match = _SearchMode.values.where((mode) => mode.name == stored);
    if (match.isEmpty) {
      return;
    }
    setState(() => _mode = match.first);
  }

  Future<void> _saveMode(_SearchMode mode) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_modePreferenceKey, mode.name);
  }

  List<WalletCard> _visibleCards(List<WalletCard> cards) {
    if (_queryController.text.trim().isEmpty) {
      return _recentCards(cards);
    }
    return _filteredCards(cards);
  }

  List<WalletCard> _recentCards(List<WalletCard> cards) {
    final filtered = cards.where((card) {
      return switch (_mode) {
        _SearchMode.cards => !card.isVisitingCard,
        _SearchMode.contacts => card.isVisitingCard,
      };
    }).toList();
    filtered.sort((a, b) {
      if (a.favorite != b.favorite) {
        return a.favorite ? -1 : 1;
      }
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return filtered.take(8).toList();
  }

  List<WalletCard> _filteredCards(List<WalletCard> cards) {
    final normalizedQuery = _queryController.text.trim().toLowerCase();
    final filtered = cards.where((card) {
      final browseMatches = switch (_mode) {
        _SearchMode.cards => !card.isVisitingCard,
        _SearchMode.contacts => card.isVisitingCard,
      };
      final queryMatches =
          normalizedQuery.isEmpty ||
          [
            card.name,
            card.issuer,
            card.categoryLabel,
            card.notes,
            card.barcodePayload,
            card.contactTitle,
            card.contactAddress,
            ...card.contactPhones,
            ...card.contactEmails,
            ...card.contactWebsites,
            card.rawOcrText,
          ].any((value) => value.toLowerCase().contains(normalizedQuery));
      return browseMatches && queryMatches;
    }).toList();
    filtered.sort((a, b) {
      if (a.favorite != b.favorite) {
        return a.favorite ? -1 : 1;
      }
      if (_mode == _SearchMode.cards && a.hasBarcode != b.hasBarcode) {
        return a.hasBarcode ? -1 : 1;
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return filtered;
  }

  Future<void> _showCardCode(WalletCard card) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => BarcodePresentScreen(card: card)));
  }

  Future<void> _showCardImages(WalletCard card) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CardReferencePresentScreen(card: card)),
    );
  }
}

enum _SearchMode { cards, contacts }
