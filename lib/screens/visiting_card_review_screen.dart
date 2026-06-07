import 'package:flutter/material.dart';

import 'package:card_box/models/visiting_card_extraction.dart';
import 'package:card_box/screens/card_image_viewer_screen.dart';
import 'package:card_box/theme.dart';
import 'package:card_box/widgets/stored_card_image.dart';

class VisitingCardReviewResult {
  const VisitingCardReviewResult({
    required this.name,
    required this.company,
    required this.title,
    required this.phones,
    required this.emails,
    required this.websites,
    required this.address,
    required this.rawOcrText,
  });

  final String name;
  final String company;
  final String title;
  final List<String> phones;
  final List<String> emails;
  final List<String> websites;
  final String address;
  final String rawOcrText;
}

class VisitingCardReviewScreen extends StatefulWidget {
  const VisitingCardReviewScreen({
    super.key,
    required this.extraction,
    required this.frontImagePath,
    this.backImagePath = '',
    this.currentName = '',
    this.currentCompany = '',
    this.currentTitle = '',
    this.currentPhones = const <String>[],
    this.currentEmails = const <String>[],
    this.currentWebsites = const <String>[],
    this.currentAddress = '',
  });

  final VisitingCardExtraction extraction;
  final String frontImagePath;
  final String backImagePath;
  final String currentName;
  final String currentCompany;
  final String currentTitle;
  final List<String> currentPhones;
  final List<String> currentEmails;
  final List<String> currentWebsites;
  final String currentAddress;

  @override
  State<VisitingCardReviewScreen> createState() =>
      _VisitingCardReviewScreenState();
}

class _VisitingCardReviewScreenState extends State<VisitingCardReviewScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _companyController;
  late final TextEditingController _titleController;
  late final TextEditingController _phonesController;
  late final TextEditingController _emailsController;
  late final TextEditingController _websitesController;
  late final TextEditingController _addressController;
  late final TextEditingController _rawOcrController;
  late bool _useName;
  late bool _useCompany;
  late bool _useTitle;
  late bool _usePhones;
  late bool _useEmails;
  late bool _useWebsites;
  late bool _useAddress;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.extraction.suggestedName.isNotEmpty
          ? widget.extraction.suggestedName
          : widget.currentName,
    );
    _companyController = TextEditingController(
      text: widget.extraction.suggestedCompany.isNotEmpty
          ? widget.extraction.suggestedCompany
          : widget.currentCompany,
    );
    _titleController = TextEditingController(
      text: widget.extraction.suggestedTitle.isNotEmpty
          ? widget.extraction.suggestedTitle
          : widget.currentTitle,
    );
    _phonesController = TextEditingController(
      text: _joinLines(
        widget.extraction.suggestedPhones.isNotEmpty
            ? widget.extraction.suggestedPhones
            : widget.currentPhones,
      ),
    );
    _emailsController = TextEditingController(
      text: _joinLines(
        widget.extraction.suggestedEmails.isNotEmpty
            ? widget.extraction.suggestedEmails
            : widget.currentEmails,
      ),
    );
    _websitesController = TextEditingController(
      text: _joinLines(
        widget.extraction.suggestedWebsites.isNotEmpty
            ? widget.extraction.suggestedWebsites
            : widget.currentWebsites,
      ),
    );
    _addressController = TextEditingController(
      text: widget.extraction.suggestedAddress.isNotEmpty
          ? widget.extraction.suggestedAddress
          : widget.currentAddress,
    );
    _rawOcrController = TextEditingController(
      text: widget.extraction.rawOcrText,
    );
    _useName = _nameController.text.trim().isNotEmpty;
    _useCompany = _companyController.text.trim().isNotEmpty;
    _useTitle = _titleController.text.trim().isNotEmpty;
    _usePhones = _phonesController.text.trim().isNotEmpty;
    _useEmails = _emailsController.text.trim().isNotEmpty;
    _useWebsites = _websitesController.text.trim().isNotEmpty;
    _useAddress = _addressController.text.trim().isNotEmpty;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _companyController.dispose();
    _titleController.dispose();
    _phonesController.dispose();
    _emailsController.dispose();
    _websitesController.dispose();
    _addressController.dispose();
    _rawOcrController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = CardBoxThemeTokens.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Review extracted details')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          tokens.spaceLarge,
          tokens.spaceSmall,
          tokens.spaceLarge,
          tokens.spaceXLarge + tokens.spaceMedium,
        ),
        children: [
          Card(
            child: Padding(
              padding: EdgeInsets.all(tokens.spaceLarge),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Check each suggestion before saving',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: tokens.spaceSmall),
                  const Text(
                    'Card Box pulled likely contact details from the card image. Keep the fields that look right and edit anything that needs correction.',
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: tokens.spaceMedium),
          _PhotoPreviewRow(
            frontImagePath: widget.frontImagePath,
            backImagePath: widget.backImagePath,
          ),
          SizedBox(height: tokens.spaceMedium),
          _SelectableField(
            label: 'Person name',
            value: _useName,
            controller: _nameController,
            onChanged: (value) => setState(() => _useName = value),
          ),
          SizedBox(height: tokens.spaceMedium - 2),
          _SelectableField(
            label: 'Company',
            value: _useCompany,
            controller: _companyController,
            onChanged: (value) => setState(() => _useCompany = value),
          ),
          SizedBox(height: tokens.spaceMedium - 2),
          _SelectableField(
            label: 'Title',
            value: _useTitle,
            controller: _titleController,
            onChanged: (value) => setState(() => _useTitle = value),
          ),
          SizedBox(height: tokens.spaceMedium - 2),
          _SelectableField(
            label: 'Phone numbers',
            value: _usePhones,
            controller: _phonesController,
            minLines: 2,
            maxLines: 4,
            helperText: 'One phone per line',
            onChanged: (value) => setState(() => _usePhones = value),
          ),
          SizedBox(height: tokens.spaceMedium - 2),
          _SelectableField(
            label: 'Emails',
            value: _useEmails,
            controller: _emailsController,
            minLines: 2,
            maxLines: 4,
            helperText: 'One email per line',
            onChanged: (value) => setState(() => _useEmails = value),
          ),
          SizedBox(height: tokens.spaceMedium - 2),
          _SelectableField(
            label: 'Websites',
            value: _useWebsites,
            controller: _websitesController,
            minLines: 2,
            maxLines: 4,
            helperText: 'One website per line',
            onChanged: (value) => setState(() => _useWebsites = value),
          ),
          SizedBox(height: tokens.spaceMedium - 2),
          _SelectableField(
            label: 'Address',
            value: _useAddress,
            controller: _addressController,
            minLines: 2,
            maxLines: 4,
            onChanged: (value) => setState(() => _useAddress = value),
          ),
          SizedBox(height: tokens.spaceMedium),
          TextFormField(
            controller: _rawOcrController,
            readOnly: true,
            minLines: 4,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: 'Raw OCR text',
              border: OutlineInputBorder(),
            ),
          ),
          SizedBox(height: tokens.spaceXLarge),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check),
            label: const Text('Use selected details'),
          ),
        ],
      ),
    );
  }

  void _save() {
    Navigator.of(context).pop(
      VisitingCardReviewResult(
        name: _useName ? _nameController.text.trim() : '',
        company: _useCompany ? _companyController.text.trim() : '',
        title: _useTitle ? _titleController.text.trim() : '',
        phones: _usePhones ? _parseLines(_phonesController.text) : const [],
        emails: _useEmails ? _parseLines(_emailsController.text) : const [],
        websites: _useWebsites
            ? _parseLines(_websitesController.text)
            : const [],
        address: _useAddress ? _addressController.text.trim() : '',
        rawOcrText: _rawOcrController.text.trim(),
      ),
    );
  }

  String _joinLines(List<String> values) => values.join('\n');

  List<String> _parseLines(String value) {
    return value
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }
}

class _SelectableField extends StatelessWidget {
  const _SelectableField({
    required this.label,
    required this.value,
    required this.controller,
    required this.onChanged,
    this.helperText,
    this.minLines = 1,
    this.maxLines = 1,
  });

  final String label;
  final bool value;
  final TextEditingController controller;
  final ValueChanged<bool> onChanged;
  final String? helperText;
  final int minLines;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final tokens = CardBoxThemeTokens.of(context);
    return Card(
      child: Padding(
        padding: EdgeInsets.all(tokens.spaceMedium),
        child: Column(
          children: [
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(label),
              subtitle: helperText == null ? null : Text(helperText!),
              value: value,
              onChanged: onChanged,
            ),
            TextFormField(
              controller: controller,
              enabled: value,
              minLines: minLines,
              maxLines: maxLines,
              decoration: InputDecoration(
                labelText: label,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoPreviewRow extends StatelessWidget {
  const _PhotoPreviewRow({
    required this.frontImagePath,
    required this.backImagePath,
  });

  final String frontImagePath;
  final String backImagePath;

  @override
  Widget build(BuildContext context) {
    final tokens = CardBoxThemeTokens.of(context);
    return Row(
      children: [
        Expanded(
          child: _TappablePreviewImage(
            imagePath: frontImagePath,
            emptyLabel: 'Front image missing',
            viewerTitle: 'Front image',
          ),
        ),
        SizedBox(width: tokens.spaceMedium - 2),
        Expanded(
          child: _TappablePreviewImage(
            imagePath: backImagePath,
            emptyLabel: 'Back image optional',
            viewerTitle: 'Back image',
          ),
        ),
      ],
    );
  }
}

class _TappablePreviewImage extends StatelessWidget {
  const _TappablePreviewImage({
    required this.imagePath,
    required this.emptyLabel,
    required this.viewerTitle,
  });

  final String imagePath;
  final String emptyLabel;
  final String viewerTitle;

  @override
  Widget build(BuildContext context) {
    final tokens = CardBoxThemeTokens.of(context);
    final canOpen = imagePath.trim().isNotEmpty;
    return InkWell(
      borderRadius: BorderRadius.circular(tokens.radiusSmall),
      onTap: canOpen
          ? () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => CardImageViewerScreen(
                  imagePath: imagePath,
                  title: viewerTitle,
                ),
              ),
            )
          : null,
      child: AspectRatio(
        aspectRatio: 1.6,
        child: Stack(
          children: [
            Positioned.fill(
              child: StoredCardImage(path: imagePath, emptyLabel: emptyLabel),
            ),
            if (canOpen)
              Positioned(
                right: 8,
                bottom: 8,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.62),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: tokens.spaceSmall,
                      vertical: tokens.spaceXSmall,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.open_in_full,
                          size: tokens.iconSmall - 4,
                          color: Colors.white,
                        ),
                        SizedBox(width: tokens.spaceXSmall),
                        Text(
                          'Open',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
