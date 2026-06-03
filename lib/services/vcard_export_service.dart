import 'package:card_box/models/wallet_card.dart';

class VCardExportService {
  const VCardExportService();

  String buildVCard(WalletCard card) {
    final lines = <String>[
      'BEGIN:VCARD',
      'VERSION:3.0',
      'FN:${_escape(card.name)}',
    ];

    final nameParts = _splitName(card.name);
    if (nameParts != null) {
      lines.add(
        'N:${_escape(nameParts.family)};${_escape(nameParts.given)};;;',
      );
    }
    if (card.issuer.trim().isNotEmpty) {
      lines.add('ORG:${_escape(card.issuer)}');
    }
    if (card.contactTitle.trim().isNotEmpty) {
      lines.add('TITLE:${_escape(card.contactTitle)}');
    }
    for (final phone in card.contactPhones) {
      if (phone.trim().isNotEmpty) {
        lines.add('TEL;TYPE=CELL:${_escape(phone)}');
      }
    }
    for (final email in card.contactEmails) {
      if (email.trim().isNotEmpty) {
        lines.add('EMAIL;TYPE=INTERNET:${_escape(email)}');
      }
    }
    for (final website in card.contactWebsites) {
      if (website.trim().isNotEmpty) {
        lines.add('URL:${_escape(website)}');
      }
    }
    if (card.contactAddress.trim().isNotEmpty) {
      lines.add('ADR;TYPE=WORK:;;${_escape(card.contactAddress)};;;;');
    }
    if (card.notes.trim().isNotEmpty) {
      lines.add('NOTE:${_escape(card.notes)}');
    }
    if (card.rawOcrText.trim().isNotEmpty) {
      lines.add('X-CARD-BOX-OCR:${_escape(card.rawOcrText)}');
    }
    lines.add('END:VCARD');
    return '${lines.join('\r\n')}\r\n';
  }

  String suggestedFileName(WalletCard card) {
    final base = card.name.trim().isEmpty ? 'contact' : card.name.trim();
    final normalized = base
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return normalized.isEmpty ? 'contact' : normalized;
  }

  String _escape(String value) {
    return value
        .replaceAll(r'\', r'\\')
        .replaceAll('\n', r'\n')
        .replaceAll(';', r'\;')
        .replaceAll(',', r'\,');
  }

  _NameParts? _splitName(String value) {
    final parts = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.length < 2) {
      return null;
    }
    final given = parts.sublist(0, parts.length - 1).join(' ');
    final family = parts.last;
    return _NameParts(given: given, family: family);
  }
}

class _NameParts {
  const _NameParts({required this.given, required this.family});

  final String given;
  final String family;
}
