import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:card_box/models/add_card_preset.dart';
import 'package:card_box/models/card_category.dart';
import 'package:card_box/models/compatibility_status.dart';
import 'package:card_box/models/recovered_media_draft.dart';
import 'package:card_box/models/wallet_card.dart';
import 'package:card_box/screens/archived_cards_screen.dart';
import 'package:card_box/screens/app_lock_settings_screen.dart';
import 'package:card_box/screens/barcode_present_screen.dart';
import 'package:card_box/screens/card_detail_screen.dart';
import 'package:card_box/screens/card_search_screen.dart';
import 'package:card_box/screens/card_reference_present_screen.dart';
import 'package:card_box/screens/category_settings_screen.dart';
import 'package:card_box/screens/compatibility_test_screen.dart';
import 'package:card_box/screens/contact_qr_screen.dart';
import 'package:card_box/screens/edit_card_screen.dart';
import 'package:card_box/screens/export_import_screen.dart';
import 'package:card_box/screens/theme_settings_screen.dart';
import 'package:card_box/services/app_lock_service.dart';
import 'package:card_box/services/card_share_service.dart';
import 'package:card_box/services/card_repository.dart';
import 'package:card_box/services/category_service.dart';
import 'package:card_box/services/media_recovery_service.dart';
import 'package:card_box/services/theme_service.dart';
import 'package:card_box/theme.dart';
import 'package:card_box/widgets/card_tile.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.repository,
    required this.appLockService,
    required this.categoryService,
    required this.themeService,
    required this.mediaRecoveryService,
    required this.onRecoveredMediaDiscarded,
    required this.onRecoveredMediaUsed,
    this.recoveredMediaDraft,
  });

  final CardRepository repository;
  final AppLockService appLockService;
  final CategoryService categoryService;
  final ThemeService themeService;
  final MediaRecoveryService mediaRecoveryService;
  final RecoveredMediaDraft? recoveredMediaDraft;
  final Future<void> Function() onRecoveredMediaDiscarded;
  final VoidCallback onRecoveredMediaUsed;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _layoutPreferenceKey = 'card_box.home_layout.v1';
  static const _allCategoriesFilterKey = '__all__';

  String? _categoryKey;
  _BrowseMode _browseMode = _BrowseMode.cards;
  _CardLayoutMode _layoutMode = _CardLayoutMode.list;

  @override
  void initState() {
    super.initState();
    _loadLayoutPreference();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([widget.repository, widget.categoryService]),
      builder: (context, _) {
        final allItems = widget.repository.cards;
        final archivedCount = widget.repository.archivedCards.length;
        final cards = _filteredCards(allItems);
        final browseLabel = _browseMode == _BrowseMode.cards
            ? 'Your cards'
            : 'Your contacts';
        return Scaffold(
          appBar: AppBar(
            title: const Text('Card Box'),
            actions: [
              IconButton(
                tooltip: _layoutMode == _CardLayoutMode.list
                    ? 'Use grid view'
                    : 'Use list view',
                icon: Icon(
                  _layoutMode == _CardLayoutMode.list
                      ? Icons.grid_view_outlined
                      : Icons.view_agenda_outlined,
                ),
                onPressed: _toggleLayoutMode,
              ),
              PopupMenuButton<_HomeMenuAction>(
                tooltip: 'More',
                onSelected: _handleMenuAction,
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: _HomeMenuAction.archived,
                    child: _PopupMenuItemRow(
                      icon: Icons.archive_outlined,
                      label: archivedCount == 0
                          ? 'Archived cards'
                          : 'Archived cards ($archivedCount)',
                    ),
                  ),
                  const PopupMenuItem(
                    value: _HomeMenuAction.summary,
                    child: _PopupMenuItemRow(
                      icon: Icons.space_dashboard_outlined,
                      label: 'Wallet summary',
                    ),
                  ),
                  const PopupMenuItem(
                    value: _HomeMenuAction.theme,
                    child: _PopupMenuItemRow(
                      icon: Icons.palette_outlined,
                      label: 'Theme',
                    ),
                  ),
                  const PopupMenuItem(
                    value: _HomeMenuAction.categories,
                    child: _PopupMenuItemRow(
                      icon: Icons.category_outlined,
                      label: 'Categories',
                    ),
                  ),
                  const PopupMenuItem(
                    value: _HomeMenuAction.backup,
                    child: _PopupMenuItemRow(
                      icon: Icons.ios_share,
                      label: 'Backup and import',
                    ),
                  ),
                  PopupMenuItem(
                    value: _HomeMenuAction.lock,
                    child: _PopupMenuItemRow(
                      icon: widget.appLockService.lockEnabled
                          ? Icons.lock_outline
                          : Icons.shield_outlined,
                      label: 'App lock',
                    ),
                  ),
                  const PopupMenuItem(
                    value: _HomeMenuAction.help,
                    child: _PopupMenuItemRow(
                      icon: Icons.help_outline_rounded,
                      label: 'How to add',
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                if (widget.recoveredMediaDraft != null) ...[
                  _RecoveredMediaCard(
                    draft: widget.recoveredMediaDraft!,
                    cardName: widget.recoveredMediaDraft!.targetsExistingCard
                        ? widget.repository
                              .findById(
                                widget.recoveredMediaDraft!.existingCardId!,
                              )
                              ?.name
                        : null,
                    onContinue: _continueRecoveredMediaFlow,
                    onDismiss: _dismissRecoveredMedia,
                  ),
                  const SizedBox(height: 12),
                ],
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<_BrowseMode>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: _BrowseMode.cards,
                        icon: Icon(Icons.wallet_membership_outlined),
                        label: Text('Cards'),
                      ),
                      ButtonSegment(
                        value: _BrowseMode.contacts,
                        icon: Icon(Icons.contact_page_outlined),
                        label: Text('Contacts'),
                      ),
                    ],
                    selected: {_browseMode},
                    onSelectionChanged: (selection) {
                      setState(() {
                        _browseMode = selection.first;
                        if (_browseMode == _BrowseMode.contacts) {
                          _categoryKey = null;
                        }
                      });
                    },
                  ),
                ),
                const SizedBox(height: 16),
                _SectionLabel(
                  title: browseLabel,
                  trailing: Text(
                    '${cards.length} shown',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                const SizedBox(height: 8),
                if (_browseMode == _BrowseMode.cards) ...[
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _openCategoryPicker(allItems),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                              horizontal: CardBoxThemeTokens.of(
                                context,
                              ).spaceMedium,
                              vertical: CardBoxThemeTokens.of(
                                context,
                              ).spaceMedium,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                CardBoxThemeTokens.of(context).radiusMedium,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.tune_rounded,
                                size: CardBoxThemeTokens.of(context).iconSmall,
                              ),
                              SizedBox(
                                width:
                                    CardBoxThemeTokens.of(context).spaceMedium -
                                    2,
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Category',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.labelSmall,
                                    ),
                                    SizedBox(
                                      height:
                                          CardBoxThemeTokens.of(
                                            context,
                                          ).spaceXSmall /
                                          2,
                                    ),
                                    Text(
                                      _selectedCategoryLabel(allItems),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(
                                width: CardBoxThemeTokens.of(
                                  context,
                                ).spaceSmall,
                              ),
                              const Icon(Icons.keyboard_arrow_down_rounded),
                            ],
                          ),
                        ),
                      ),
                      if (_categoryKey != null) ...[
                        const SizedBox(width: 10),
                        ActionChip(
                          avatar: const Icon(Icons.close, size: 16),
                          label: const Text('Clear'),
                          onPressed: () => setState(() => _categoryKey = null),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _categoryKey == null
                        ? 'Showing every category.'
                        : 'Showing only ${_selectedCategoryLabel(allItems)}.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                ] else ...[
                  Text(
                    'Keep visiting cards in their own space so your everyday wallet stays tidy.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                ],
                if (cards.isEmpty)
                  _EmptyState(
                    onAddCard: _browseMode == _BrowseMode.cards
                        ? _openAddCardPicker
                        : _openContactAddPicker,
                    title: _browseMode == _BrowseMode.cards
                        ? 'No cards found'
                        : 'No contacts found',
                    body: _browseMode == _BrowseMode.cards
                        ? 'Add a barcode card, NFC/RFID card, visiting card, or a simple reference card with photos and notes.'
                        : 'Scan a visiting card directly or add a contact card manually.',
                    buttonLabel: _browseMode == _BrowseMode.cards
                        ? 'Add your first card'
                        : 'Scan your first contact',
                  )
                else ...[
                  _CardCollection(
                    cards: cards,
                    layoutMode: _layoutMode,
                    onTapCard: _openCardActions,
                    onShowCode: _showCardCode,
                    onShowImages: _showCardImages,
                  ),
                ],
              ],
            ),
          ),
          floatingActionButton: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              FloatingActionButton.small(
                heroTag: 'search_fab',
                tooltip: 'Search',
                onPressed: _openSearch,
                child: const Icon(Icons.search),
              ),
              const SizedBox(height: 12),
              FloatingActionButton.extended(
                heroTag: 'add_fab',
                icon: Icon(
                  _browseMode == _BrowseMode.cards
                      ? Icons.add
                      : Icons.contact_page_outlined,
                ),
                label: Text(
                  _browseMode == _BrowseMode.cards ? 'Add card' : 'Add contact',
                ),
                onPressed: _browseMode == _BrowseMode.cards
                    ? _openAddCardPicker
                    : _openContactAddPicker,
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openAddHelp() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        final tokens = CardBoxThemeTokens.of(context);
        final isCards = _browseMode == _BrowseMode.cards;
        return SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              tokens.spaceLarge,
              0,
              tokens.spaceLarge,
              tokens.spaceXLarge,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCards ? 'How to add a card' : 'How to add a contact',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                SizedBox(height: tokens.spaceSmall),
                Text(
                  isCards
                      ? 'Pick the path that matches what you are holding. You can still edit everything afterward.'
                      : 'Choose the fastest way to get a visiting card or contact saved, then tidy the details afterward.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                SizedBox(height: tokens.spaceLarge),
                if (isCards) ...[
                  const _HelpOptionRow(
                    icon: Icons.qr_code_2,
                    title: 'Barcode card',
                    body:
                        'Best for loyalty, library, membership, and gift cards with visible barcodes or QR codes.',
                  ),
                  const SizedBox(height: 12),
                  const _HelpOptionRow(
                    icon: Icons.nfc,
                    title: 'NFC / RFID card',
                    body:
                        'Best for tap-style cards like access or transit. Save it first, then test what this phone can read.',
                  ),
                  const SizedBox(height: 12),
                  const _HelpOptionRow(
                    icon: Icons.contact_page_outlined,
                    title: 'Visiting card',
                    body:
                        'Best for business cards. Scan the card, extract details, and review what should become a saved contact.',
                  ),
                  const SizedBox(height: 12),
                  const _HelpOptionRow(
                    icon: Icons.badge_outlined,
                    title: 'Reference card',
                    body:
                        'Best when the phone cannot use the card directly and you mainly want front/back images plus notes.',
                  ),
                  const SizedBox(height: 12),
                  const _HelpOptionRow(
                    icon: Icons.add_card,
                    title: 'General card',
                    body:
                        'Best when you are not sure yet. Start blank and add only the parts this card really needs.',
                  ),
                ] else ...[
                  const _HelpOptionRow(
                    icon: Icons.document_scanner_outlined,
                    title: 'Scan visiting card',
                    body:
                        'Use this when the business card is in front of you and you want the fastest capture flow.',
                  ),
                  const SizedBox(height: 12),
                  const _HelpOptionRow(
                    icon: Icons.contact_page_outlined,
                    title: 'Add contact manually',
                    body:
                        'Use this when you already know the details or only need a simple contact record first.',
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openCategoryPicker(List<WalletCard> cards) async {
    final options = _categoryFilterOptions(cards);
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Filter by category',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'Choose the kind of card you want to browse right now.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      _CategoryOptionTile(
                        label: 'All categories',
                        count: cards
                            .where((card) => !card.isVisitingCard)
                            .length,
                        selected: _categoryKey == null,
                        onTap: () =>
                            Navigator.of(context).pop(_allCategoriesFilterKey),
                      ),
                      for (final option in options)
                        _CategoryOptionTile(
                          label: option.label,
                          count: option.count,
                          selected: _categoryKey == option.key,
                          onTap: () => Navigator.of(context).pop(option.key),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (!mounted || selected == null) {
      return;
    }
    setState(() {
      _categoryKey = selected == _allCategoriesFilterKey ? null : selected;
    });
  }

  Future<void> _loadLayoutPreference() async {
    final preferences = await SharedPreferences.getInstance();
    final stored = preferences.getString(_layoutPreferenceKey);
    if (!mounted || stored == null) {
      return;
    }
    final match = _CardLayoutMode.values.where((mode) => mode.name == stored);
    if (match.isEmpty) {
      return;
    }
    setState(() => _layoutMode = match.first);
  }

  Future<void> _toggleLayoutMode() async {
    final nextMode = _layoutMode == _CardLayoutMode.list
        ? _CardLayoutMode.grid
        : _CardLayoutMode.list;
    setState(() => _layoutMode = nextMode);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_layoutPreferenceKey, nextMode.name);
  }

  Future<void> _openSearch() async {
    final result = await Navigator.of(context).push<WalletCard>(
      MaterialPageRoute(
        builder: (_) => CardSearchScreen(
          repository: widget.repository,
          showContactsInitially: _browseMode == _BrowseMode.contacts,
        ),
      ),
    );
    if (result == null || !mounted) {
      return;
    }
    await _openCardActions(result);
  }

  void _openAddCard(AddCardPreset preset, {bool autoStartFrontScan = false}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EditCardScreen(
          repository: widget.repository,
          appLockService: widget.appLockService,
          categoryService: widget.categoryService,
          mediaRecoveryService: widget.mediaRecoveryService,
          preset: preset,
          autoStartFrontScan: autoStartFrontScan,
        ),
      ),
    );
  }

  Future<void> _openAddCardPicker() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _AddOptionsSheet(
        title: 'How do you want to add it?',
        subtitle:
            'Pick the path that matches what you are holding. You can still edit everything afterward.',
        options: [
          _AddOption(
            icon: Icons.qr_code_2,
            title: 'Barcode card',
            subtitle: 'Great for loyalty, library, and membership cards',
            onTap: () {
              Navigator.of(context).pop();
              _openAddCard(AddCardPreset.barcode);
            },
          ),
          _AddOption(
            icon: Icons.nfc,
            title: 'NFC / RFID card',
            subtitle: 'Save it first, then test what this phone can read',
            onTap: () {
              Navigator.of(context).pop();
              _openAddCard(AddCardPreset.nfc);
            },
          ),
          _AddOption(
            icon: Icons.contact_page_outlined,
            title: 'Visiting card',
            subtitle: 'Scan a business card or save it as a contact-style card',
            onTap: () {
              Navigator.of(context).pop();
              _openAddCard(AddCardPreset.visiting, autoStartFrontScan: true);
            },
          ),
          _AddOption(
            icon: Icons.badge_outlined,
            title: 'Reference card',
            subtitle: 'Photos and notes for cards that stay physical',
            onTap: () {
              Navigator.of(context).pop();
              _openAddCard(AddCardPreset.reference);
            },
          ),
          _AddOption(
            icon: Icons.add_card,
            title: 'General card',
            subtitle: 'Start blank and decide the details yourself',
            onTap: () {
              Navigator.of(context).pop();
              _openAddCard(AddCardPreset.general);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _openContactAddPicker() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _AddOptionsSheet(
        title: 'How do you want to add a contact?',
        subtitle:
            'You can scan a visiting card right away or add the details manually.',
        options: [
          _AddOption(
            icon: Icons.document_scanner_outlined,
            title: 'Scan visiting card',
            subtitle:
                'Open the scanner immediately, then review extracted details',
            onTap: () {
              Navigator.of(context).pop();
              _openAddCard(AddCardPreset.visiting, autoStartFrontScan: true);
            },
          ),
          _AddOption(
            icon: Icons.contact_page_outlined,
            title: 'Add contact manually',
            subtitle: 'Start with a blank contact card and add photos later',
            onTap: () {
              Navigator.of(context).pop();
              _openAddCard(AddCardPreset.visiting);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _openCardActions(WalletCard card) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        final maxHeight = MediaQuery.of(context).size.height * 0.82;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'More options',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    card.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    card.issuer.isEmpty ? card.categoryLabel : card.issuer,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  Flexible(
                    child: Scrollbar(
                      thumbVisibility: true,
                      child: ListView(
                        shrinkWrap: true,
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          if (card.hasBarcode)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.fullscreen),
                              title: const Text('Show code'),
                              subtitle: const Text(
                                'Open the full-screen barcode or QR view',
                              ),
                              onTap: () {
                                Navigator.of(context).pop();
                                Navigator.of(this.context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        BarcodePresentScreen(card: card),
                                  ),
                                );
                              },
                            ),
                          if (!card.hasBarcode && card.hasPhotos)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.credit_card),
                              title: const Text('Show card'),
                              subtitle: const Text(
                                'Open the saved front and back images full screen',
                              ),
                              onTap: () {
                                Navigator.of(context).pop();
                                Navigator.of(this.context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        CardReferencePresentScreen(card: card),
                                  ),
                                );
                              },
                            ),
                          if (card.isVisitingCard)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.qr_code_2_outlined),
                              title: const Text('Show contact QR'),
                              subtitle: const Text(
                                'Share this contact by letting someone scan a QR code',
                              ),
                              onTap: () {
                                Navigator.of(context).pop();
                                Navigator.of(this.context).push(
                                  MaterialPageRoute(
                                    builder: (_) => ContactQrScreen(card: card),
                                  ),
                                );
                              },
                            ),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.share_outlined),
                            title: Text(
                              card.isVisitingCard
                                  ? 'Share contact'
                                  : 'Share card',
                            ),
                            subtitle: Text(
                              card.isVisitingCard
                                  ? 'Share a contact file through any messenger'
                                  : 'Share a card image or summary through any messenger',
                            ),
                            onTap: () {
                              Navigator.of(context).pop();
                              _shareCard(card);
                            },
                          ),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.edit_outlined),
                            title: Text(
                              card.isVisitingCard
                                  ? 'Edit contact'
                                  : 'Edit card',
                            ),
                            subtitle: Text(
                              card.isVisitingCard
                                  ? 'Update photos, extracted fields, and notes'
                                  : 'Update details, photos, notes, or codes',
                            ),
                            onTap: () {
                              Navigator.of(context).pop();
                              Navigator.of(this.context).push(
                                MaterialPageRoute(
                                  builder: (_) => EditCardScreen(
                                    repository: widget.repository,
                                    appLockService: widget.appLockService,
                                    categoryService: widget.categoryService,
                                    mediaRecoveryService:
                                        widget.mediaRecoveryService,
                                    existingCard: card,
                                  ),
                                ),
                              );
                            },
                          ),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.visibility_outlined),
                            title: Text(
                              card.isVisitingCard
                                  ? 'View contact'
                                  : 'View details',
                            ),
                            subtitle: Text(
                              card.isVisitingCard
                                  ? 'Open the full contact detail screen'
                                  : 'Open the full card detail screen',
                            ),
                            onTap: () {
                              Navigator.of(context).pop();
                              Navigator.of(this.context).push(
                                MaterialPageRoute(
                                  builder: (_) => CardDetailScreen(
                                    repository: widget.repository,
                                    appLockService: widget.appLockService,
                                    categoryService: widget.categoryService,
                                    cardId: card.id,
                                  ),
                                ),
                              );
                            },
                          ),
                          if (!card.hasBarcode && !card.isVisitingCard)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.nfc),
                              title: const Text('Test NFC / RFID'),
                              subtitle: const Text(
                                'Check whether this phone can read the card',
                              ),
                              onTap: () {
                                Navigator.of(context).pop();
                                Navigator.of(this.context).push(
                                  MaterialPageRoute(
                                    builder: (_) => CompatibilityTestScreen(
                                      repository: widget.repository,
                                      appLockService: widget.appLockService,
                                      card: card,
                                    ),
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _handleMenuAction(_HomeMenuAction action) {
    switch (action) {
      case _HomeMenuAction.archived:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ArchivedCardsScreen(
              repository: widget.repository,
              appLockService: widget.appLockService,
              categoryService: widget.categoryService,
            ),
          ),
        );
      case _HomeMenuAction.summary:
        _showWalletSummary();
      case _HomeMenuAction.categories:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CategorySettingsScreen(
              categoryService: widget.categoryService,
              repository: widget.repository,
            ),
          ),
        );
      case _HomeMenuAction.theme:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                ThemeSettingsScreen(themeService: widget.themeService),
          ),
        );
      case _HomeMenuAction.backup:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ExportImportScreen(
              repository: widget.repository,
              appLockService: widget.appLockService,
            ),
          ),
        );
      case _HomeMenuAction.lock:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                AppLockSettingsScreen(appLockService: widget.appLockService),
          ),
        );
      case _HomeMenuAction.help:
        _openAddHelp();
    }
  }

  List<WalletCard> _filteredCards(List<WalletCard> cards) {
    final filtered = cards.where((card) {
      final browseMatches = switch (_browseMode) {
        _BrowseMode.cards => !card.isVisitingCard,
        _BrowseMode.contacts => card.isVisitingCard,
      };
      final categoryMatches = _browseMode == _BrowseMode.contacts
          ? true
          : _matchesSelectedCategory(card);
      return browseMatches && categoryMatches;
    }).toList();
    filtered.sort((a, b) {
      if (a.favorite != b.favorite) {
        return a.favorite ? -1 : 1;
      }
      if (_browseMode == _BrowseMode.cards && a.hasBarcode != b.hasBarcode) {
        return a.hasBarcode ? -1 : 1;
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return filtered;
  }

  bool _matchesSelectedCategory(WalletCard card) {
    if (_categoryKey == null) {
      return true;
    }
    if (_categoryKey!.startsWith('custom:')) {
      final customLabel = _categoryKey!.substring('custom:'.length);
      return card.category == CardCategory.other &&
          card.customCategory?.trim().toLowerCase() ==
              customLabel.toLowerCase();
    }
    return card.category.name == _categoryKey;
  }

  String _selectedCategoryLabel(List<WalletCard> cards) {
    if (_categoryKey == null) {
      return 'All categories';
    }
    for (final option in _categoryFilterOptions(cards)) {
      if (option.key == _categoryKey) {
        return option.label;
      }
    }
    return 'Selected category';
  }

  List<_CategoryFilterOption> _categoryFilterOptions(List<WalletCard> cards) {
    final cardItems = cards.where((card) => !card.isVisitingCard).toList();
    final customLabels = <String>{
      ...widget.categoryService.customCategories,
      ...cardItems
          .where((card) => card.category == CardCategory.other)
          .map((card) => card.customCategory?.trim() ?? '')
          .where((label) => label.isNotEmpty),
    }.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return [
      ...CardCategory.values
          .where((category) => category != CardCategory.contact)
          .map(
            (category) => _CategoryFilterOption(
              key: category.name,
              label: category.label,
              count: cardItems
                  .where((card) => card.category == category)
                  .length,
            ),
          ),
      ...customLabels.map(
        (label) => _CategoryFilterOption(
          key: 'custom:$label',
          label: label,
          count: cardItems.where((card) {
            return card.category == CardCategory.other &&
                card.customCategory?.trim().toLowerCase() ==
                    label.toLowerCase();
          }).length,
        ),
      ),
    ];
  }

  Future<void> _dismissRecoveredMedia() async {
    await widget.onRecoveredMediaDiscarded();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Recovered photo discarded.')));
  }

  Future<void> _continueRecoveredMediaFlow() async {
    final draft = widget.recoveredMediaDraft;
    if (draft == null) {
      return;
    }
    final existingCard = draft.targetsExistingCard
        ? widget.repository.findById(draft.existingCardId!)
        : null;
    widget.onRecoveredMediaUsed();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EditCardScreen(
          repository: widget.repository,
          appLockService: widget.appLockService,
          categoryService: widget.categoryService,
          mediaRecoveryService: widget.mediaRecoveryService,
          existingCard: existingCard,
          preset: draft.preset,
          recoveredMediaDraft: draft,
        ),
      ),
    );
  }

  Future<void> _showWalletSummary() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: _CompactOverviewPanel(cards: widget.repository.cards),
        ),
      ),
    );
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

  Future<void> _shareCard(WalletCard card) async {
    final result = await const CardShareService().shareCard(card);
    if (!mounted || result.message.isEmpty) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(result.message)));
  }
}

class _RecoveredMediaCard extends StatelessWidget {
  const _RecoveredMediaCard({
    required this.draft,
    required this.cardName,
    required this.onContinue,
    required this.onDismiss,
  });

  final RecoveredMediaDraft draft;
  final String? cardName;
  final VoidCallback onContinue;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final title = draft.targetsExistingCard
        ? 'Recovered ${draft.recoveredSideLabel} photo for ${cardName ?? 'your card'}'
        : 'Recovered ${draft.recoveredSideLabel} photo from the last session';
    final subtitle = draft.targetsExistingCard
        ? 'Open the editor to review and save the recovered image.'
        : 'Continue adding the card so the recovered image is not lost.';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(subtitle),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: onContinue,
                  icon: const Icon(Icons.restore),
                  label: const Text('Continue'),
                ),
                OutlinedButton.icon(
                  onPressed: onDismiss,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Discard'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

enum _BrowseMode { cards, contacts }

enum _CardLayoutMode { list, grid }

enum _HomeMenuAction {
  archived,
  summary,
  theme,
  categories,
  backup,
  lock,
  help,
}

class _CategoryFilterOption {
  const _CategoryFilterOption({
    required this.key,
    required this.label,
    required this.count,
  });

  final String key;
  final String label;
  final int count;
}

class _CategoryOptionTile extends StatelessWidget {
  const _CategoryOptionTile({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final tokens = CardBoxThemeTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? tokens.surfaceInteractive : tokens.surfaceSubtle,
        borderRadius: BorderRadius.circular(tokens.radiusMedium),
        child: InkWell(
          borderRadius: BorderRadius.circular(tokens.radiusMedium),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? colors.primary.withValues(alpha: 0.12)
                        : tokens.surfaceRaised,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$count',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.chevron_right_rounded,
                  color: selected ? colors.primary : colors.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CardCollection extends StatelessWidget {
  const _CardCollection({
    required this.cards,
    required this.layoutMode,
    required this.onTapCard,
    required this.onShowCode,
    required this.onShowImages,
  });

  final List<WalletCard> cards;
  final _CardLayoutMode layoutMode;
  final ValueChanged<WalletCard> onTapCard;
  final ValueChanged<WalletCard> onShowCode;
  final ValueChanged<WalletCard> onShowImages;

  @override
  Widget build(BuildContext context) {
    if (layoutMode == _CardLayoutMode.list) {
      return Column(
        children: [
          for (var index = 0; index < cards.length; index++) ...[
            CardTile(
              card: cards[index],
              onTap: () => onTapCard(cards[index]),
              onShowCode: cards[index].hasBarcode
                  ? () => onShowCode(cards[index])
                  : null,
              onShowImages: cards[index].hasPhotos
                  ? () => onShowImages(cards[index])
                  : null,
            ),
            if (index != cards.length - 1) const SizedBox(height: 10),
          ],
        ],
      );
    }

    final width = MediaQuery.sizeOf(context).width;
    final crossAxisCount = width >= 1100
        ? 4
        : width >= 820
        ? 3
        : 2;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cards.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.9,
      ),
      itemBuilder: (context, index) {
        final card = cards[index];
        return CardTile(
          card: card,
          layout: CardTileLayout.grid,
          onTap: () => onTapCard(card),
          onShowCode: card.hasBarcode ? () => onShowCode(card) : null,
          onShowImages: card.hasPhotos ? () => onShowImages(card) : null,
        );
      },
    );
  }
}

class _CompactOverviewPanel extends StatelessWidget {
  const _CompactOverviewPanel({required this.cards});

  final List<WalletCard> cards;

  @override
  Widget build(BuildContext context) {
    final readyToShow = cards.where((card) => card.hasBarcode).length;
    final nfcReadable = cards
        .where(
          (card) => card.compatibilityStatus == CompatibilityStatus.nfcReadable,
        )
        .length;
    final untested = cards
        .where(
          (card) => card.compatibilityStatus == CompatibilityStatus.untested,
        )
        .length;
    final contacts = cards.where((card) => card.isVisitingCard).length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your wallet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              cards.isEmpty
                  ? 'Start with the cards and contacts you actually use every week.'
                  : '$readyToShow ready to show, $nfcReadable NFC-readable, $contacts saved contacts, $untested still untested.',
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _MetricTile(
                    label: 'Cards',
                    value: '${cards.length}',
                    icon: Icons.wallet_outlined,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MetricTile(
                    label: 'Ready',
                    value: '$readyToShow',
                    icon: Icons.qr_code_2,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MetricTile(
                    label: 'Contacts',
                    value: '$contacts',
                    icon: Icons.contact_page_outlined,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
        trailing ?? const SizedBox.shrink(),
      ],
    );
  }
}

class _HelpOptionRow extends StatelessWidget {
  const _HelpOptionRow({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final tokens = CardBoxThemeTokens.of(context);
    final colors = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(tokens.radiusSmall),
          ),
          child: Icon(icon, color: colors.primary),
        ),
        SizedBox(width: tokens.spaceMedium),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              SizedBox(height: tokens.spaceXSmall / 2),
              Text(body, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final tokens = CardBoxThemeTokens.of(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spaceMedium,
        vertical: tokens.spaceSmall + 2,
      ),
      decoration: BoxDecoration(
        color: tokens.surfaceSubtle,
        borderRadius: BorderRadius.circular(tokens.radiusSmall),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: tokens.iconSmall,
            color: Theme.of(context).colorScheme.primary,
          ),
          SizedBox(height: tokens.spaceSmall),
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: tokens.spaceXSmall / 2),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.onAddCard,
    required this.title,
    required this.body,
    required this.buttonLabel,
  });

  final VoidCallback onAddCard;
  final String title;
  final String body;
  final String buttonLabel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(body, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onAddCard,
              icon: const Icon(Icons.add),
              label: Text(buttonLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddOptionsSheet extends StatelessWidget {
  const _AddOptionsSheet({
    required this.title,
    required this.subtitle,
    required this.options,
  });

  final String title;
  final String subtitle;
  final List<_AddOption> options;

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.82;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(subtitle),
              const SizedBox(height: 12),
              for (final option in options)
                _AddPathTile(
                  icon: option.icon,
                  title: option.title,
                  subtitle: option.subtitle,
                  onTap: option.onTap,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddOption {
  const _AddOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
}

class _AddPathTile extends StatelessWidget {
  const _AddPathTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(radius: 20, child: Icon(icon, size: 20)),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

/// Compact row used inside the three-dot overflow menu. The text is wrapped
/// in [Flexible] so a long label ellipsizes rather than overflowing the menu's
/// fixed-width row (a hard 256dp cap imposed by Flutter's popup layout).
class _PopupMenuItemRow extends StatelessWidget {
  const _PopupMenuItemRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 10),
        Flexible(
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}
