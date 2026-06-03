import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'package:card_box/models/visiting_card_extraction.dart';

class VisitingCardOcrService {
  static final _emailPattern = RegExp(
    r'[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}',
    caseSensitive: false,
  );
  static final _websitePattern = RegExp(
    r'(?:(?:https?:\/\/)?(?:www\.)?(?:[A-Z0-9-]+\.)+[A-Z]{2,}(?:\/\S*)?)',
    caseSensitive: false,
  );
  static final _phonePattern = RegExp(
    r'(?:(?:\+?\d)[\d\s().-]{6,}\d)',
    caseSensitive: false,
  );
  static final _jobTitleKeywords = <String>[
    'manager',
    'director',
    'engineer',
    'developer',
    'designer',
    'consultant',
    'analyst',
    'coordinator',
    'specialist',
    'president',
    'ceo',
    'cto',
    'cfo',
    'founder',
    'partner',
    'sales',
    'marketing',
    'coach',
    'teacher',
    'professor',
    'student',
    'producer',
    'architect',
    'lead',
    'owner',
    'representative',
    'supervisor',
  ];
  static final _companyKeywords = <String>[
    'inc',
    'ltd',
    'llc',
    'corp',
    'co.',
    'company',
    'group',
    'studio',
    'solutions',
    'systems',
    'technologies',
    'technology',
    'works',
    'agency',
    'associates',
    '株式会社',
    '有限会社',
  ];
  static final _addressKeywords = <String>[
    'street',
    'st.',
    'road',
    'rd.',
    'avenue',
    'ave',
    'building',
    'floor',
    'suite',
    'city',
    'state',
    'zip',
    'postal',
    'ku',
    'shi',
    'ward',
    'tokyo',
    'osaka',
    'japan',
  ];

  Future<VisitingCardExtraction> extractFromImages({
    required String frontImagePath,
    String? backImagePath,
  }) async {
    final textRecognizer = TextRecognizer();
    try {
      final allLines = <String>[
        ...await _recognizeLines(textRecognizer, frontImagePath),
      ];
      if (backImagePath != null && backImagePath.trim().isNotEmpty) {
        allLines.addAll(await _recognizeLines(textRecognizer, backImagePath));
      }

      final normalizedLines = _dedupeLines(allLines);
      final rawOcrText = normalizedLines.join('\n');
      final emails = _dedupeMatches(_emailPattern, rawOcrText);
      final websites = _dedupeMatches(
        _websitePattern,
        rawOcrText,
      ).where((website) => !_looksLikeEmail(website)).toList();
      final phones = _dedupeMatches(
        _phonePattern,
        rawOcrText,
      ).where(_looksLikePhone).toList();

      final remainingLines = normalizedLines.where((line) {
        final lower = line.toLowerCase();
        if (_emailPattern.hasMatch(line) ||
            _websitePattern.hasMatch(line) ||
            _phonePattern.hasMatch(line)) {
          return false;
        }
        if (lower.startsWith('tel') ||
            lower.startsWith('fax') ||
            lower.startsWith('mobile') ||
            lower.startsWith('email') ||
            lower.startsWith('web')) {
          return false;
        }
        return true;
      }).toList();

      final suggestedName = _inferName(remainingLines);
      final suggestedCompany = _inferCompany(remainingLines, suggestedName);
      final suggestedTitle = _inferTitle(
        remainingLines,
        suggestedName,
        suggestedCompany,
      );
      final suggestedAddress = _inferAddress(
        remainingLines,
        suggestedName,
        suggestedCompany,
        suggestedTitle,
      );

      return VisitingCardExtraction(
        suggestedName: suggestedName,
        suggestedCompany: suggestedCompany,
        suggestedTitle: suggestedTitle,
        suggestedPhones: phones,
        suggestedEmails: emails,
        suggestedWebsites: websites,
        suggestedAddress: suggestedAddress,
        rawOcrText: rawOcrText,
      );
    } finally {
      await textRecognizer.close();
    }
  }

  Future<List<String>> _recognizeLines(
    TextRecognizer recognizer,
    String imagePath,
  ) async {
    final image = InputImage.fromFilePath(imagePath);
    final result = await recognizer.processImage(image);
    return result.blocks
        .expand((block) => block.lines)
        .map((line) => line.text.trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }

  List<String> _dedupeLines(List<String> lines) {
    final seen = <String>{};
    for (final line in lines) {
      final normalized = line.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (normalized.isNotEmpty) {
        seen.add(normalized);
      }
    }
    return seen.toList();
  }

  List<String> _dedupeMatches(RegExp pattern, String text) {
    final seen = <String>{};
    for (final match in pattern.allMatches(text)) {
      final value = match.group(0)?.trim();
      if (value == null || value.isEmpty) {
        continue;
      }
      seen.add(value);
    }
    return seen.toList();
  }

  bool _looksLikeEmail(String value) => value.contains('@');

  bool _looksLikePhone(String value) {
    final digitsOnly = value.replaceAll(RegExp(r'\D'), '');
    return digitsOnly.length >= 7;
  }

  String _inferName(List<String> lines) {
    for (final line in lines.take(5)) {
      final words = line.split(RegExp(r'\s+'));
      if (words.length > 5) {
        continue;
      }
      if (RegExp(r'\d').hasMatch(line)) {
        continue;
      }
      final lower = line.toLowerCase();
      if (_jobTitleKeywords.any(lower.contains) ||
          _companyKeywords.any(lower.contains)) {
        continue;
      }
      return line;
    }
    return '';
  }

  String _inferCompany(List<String> lines, String suggestedName) {
    for (final line in lines.take(8)) {
      if (line == suggestedName) {
        continue;
      }
      final lower = line.toLowerCase();
      if (_companyKeywords.any(lower.contains)) {
        return line;
      }
    }
    for (final line in lines.take(8)) {
      if (line == suggestedName) {
        continue;
      }
      if (!RegExp(r'\d').hasMatch(line) && line.length > 4) {
        return line;
      }
    }
    return '';
  }

  String _inferTitle(
    List<String> lines,
    String suggestedName,
    String suggestedCompany,
  ) {
    for (final line in lines.take(8)) {
      if (line == suggestedName || line == suggestedCompany) {
        continue;
      }
      final lower = line.toLowerCase();
      if (_jobTitleKeywords.any(lower.contains)) {
        return line;
      }
    }
    if (suggestedName.isNotEmpty && suggestedCompany.isNotEmpty) {
      final start = lines.indexOf(suggestedName);
      final end = lines.indexOf(suggestedCompany);
      if (start != -1 && end != -1 && end > start + 1) {
        return lines[start + 1];
      }
    }
    return '';
  }

  String _inferAddress(
    List<String> lines,
    String suggestedName,
    String suggestedCompany,
    String suggestedTitle,
  ) {
    final addressLines = <String>[];
    for (final line in lines) {
      if (line == suggestedName ||
          line == suggestedCompany ||
          line == suggestedTitle) {
        continue;
      }
      final lower = line.toLowerCase();
      if (_addressKeywords.any(lower.contains) ||
          (RegExp(r'\d').hasMatch(line) &&
              !lower.contains('fax') &&
              !lower.contains('tel'))) {
        addressLines.add(line);
      }
    }
    return addressLines.join('\n').trim();
  }
}
