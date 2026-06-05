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
  static final _contactFieldPrefixes = <String>[
    'tel',
    'phone',
    'mobile',
    'fax',
    'email',
    'e-mail',
    'mail',
    'web',
    'website',
    'url',
    'address',
    'add',
    '電話',
    '携帯',
    'メール',
    'mail',
    '住所',
    'fax',
  ];
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
    '代表取締役',
    '取締役',
    '社長',
    '部長',
    '課長',
    '主任',
    '係長',
    'マネージャー',
    'ディレクター',
    'コーチ',
    '先生',
    '教授',
    '監督',
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
    '丁目',
    '番地',
    '号',
    '都',
    '道',
    '府',
    '県',
    '市',
    '区',
    '町',
    '村',
    'ビル',
  ];

  Future<VisitingCardExtraction> extractFromImages({
    required String frontImagePath,
    String? backImagePath,
  }) async {
    final recognizers = <TextRecognizer>[
      TextRecognizer(script: TextRecognitionScript.latin),
      TextRecognizer(script: TextRecognitionScript.japanese),
    ];
    try {
      final allLines = <String>[];
      for (final recognizer in recognizers) {
        allLines.addAll(
          await _recognizeLinesSafely(recognizer, frontImagePath),
        );
      }
      if (backImagePath != null && backImagePath.trim().isNotEmpty) {
        for (final recognizer in recognizers) {
          allLines.addAll(
            await _recognizeLinesSafely(recognizer, backImagePath),
          );
        }
      }
      return parseRecognizedLines(allLines);
    } finally {
      for (final recognizer in recognizers) {
        await recognizer.close();
      }
    }
  }

  VisitingCardExtraction parseRecognizedLines(List<String> rawLines) {
    final normalizedLines = _dedupeLines(rawLines);
    final rawOcrText = normalizedLines.join('\n');
    final emails = _dedupeMatches(_emailPattern, rawOcrText);
    final websites = _dedupeMatches(
      _websitePattern,
      rawOcrText,
    ).where((website) => !_looksLikeEmail(website)).toList();
    final phones = _extractPhones(normalizedLines);

    final remainingLines = normalizedLines
        .where((line) {
          final lower = line.toLowerCase();
          if (_emailPattern.hasMatch(line) || _websitePattern.hasMatch(line)) {
            return false;
          }
          if (_phonePattern.hasMatch(line) && !_looksLikeLikelyAddress(line)) {
            return false;
          }
          if (_hasFieldPrefix(lower)) {
            return false;
          }
          return true;
        })
        .map(_stripFieldLabel)
        .where((line) => line.isNotEmpty)
        .toList();

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
  }

  Future<List<String>> _recognizeLinesSafely(
    TextRecognizer recognizer,
    String imagePath,
  ) async {
    try {
      return await _recognizeLines(recognizer, imagePath);
    } catch (_) {
      return const <String>[];
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
    return digitsOnly.length >= 9;
  }

  List<String> _extractPhones(List<String> lines) {
    final seen = <String>{};
    for (final line in lines) {
      if (line.toLowerCase().contains('fax')) {
        continue;
      }
      for (final match in _phonePattern.allMatches(line)) {
        final value = match.group(0)?.trim();
        if (value == null ||
            value.isEmpty ||
            !_looksLikePhone(value) ||
            _looksLikeLikelyAddress(line)) {
          continue;
        }
        seen.add(value);
      }
    }
    return seen.toList();
  }

  String _inferName(List<String> lines) {
    return _bestScoredLine(
      lines: lines.take(6).toList(),
      scorer: (line, index) {
        final lower = line.toLowerCase();
        final words = line.split(RegExp(r'\s+'));
        var score = 0;
        if (index == 0) {
          score += 4;
        }
        if (!RegExp(r'\d').hasMatch(line)) {
          score += 3;
        }
        if (words.length >= 2 && words.length <= 4) {
          score += 4;
        }
        if (_looksLikePersonName(line)) {
          score += 4;
        }
        if (_jobTitleKeywords.any(lower.contains)) {
          score -= 6;
        }
        if (_companyKeywords.any(lower.contains)) {
          score -= 6;
        }
        if (_looksLikeLikelyAddress(line)) {
          score -= 8;
        }
        if (_hasFieldPrefix(lower)) {
          score -= 8;
        }
        return score;
      },
      minimumScore: 5,
    );
  }

  String _inferCompany(List<String> lines, String suggestedName) {
    return _bestScoredLine(
      lines: lines.take(8).where((line) => line != suggestedName).toList(),
      scorer: (line, index) {
        final lower = line.toLowerCase();
        var score = 0;
        if (index <= 2) {
          score += 2;
        }
        if (_companyKeywords.any(lower.contains)) {
          score += 8;
        }
        if (!_jobTitleKeywords.any(lower.contains) &&
            !_looksLikeLikelyAddress(line) &&
            !RegExp(r'\d').hasMatch(line)) {
          score += 3;
        }
        if (line.length >= 5) {
          score += 1;
        }
        if (_looksLikePersonName(line)) {
          score -= 7;
        }
        if (_jobTitleKeywords.any(lower.contains)) {
          score -= 5;
        }
        if (_hasFieldPrefix(lower) || _looksLikeLikelyAddress(line)) {
          score -= 7;
        }
        return score;
      },
      minimumScore: 3,
    );
  }

  String _inferTitle(
    List<String> lines,
    String suggestedName,
    String suggestedCompany,
  ) {
    final title = _bestScoredLine(
      lines: lines
          .take(8)
          .where((line) => line != suggestedName && line != suggestedCompany)
          .toList(),
      scorer: (line, index) {
        final lower = line.toLowerCase();
        var score = 0;
        if (_jobTitleKeywords.any(lower.contains)) {
          score += 8;
        }
        if (!RegExp(r'\d').hasMatch(line) && line.length <= 32) {
          score += 2;
        }
        if (index <= 2) {
          score += 1;
        }
        if (_companyKeywords.any(lower.contains)) {
          score -= 3;
        }
        if (_looksLikeLikelyAddress(line) || _hasFieldPrefix(lower)) {
          score -= 6;
        }
        return score;
      },
      minimumScore: 4,
    );
    if (title.isNotEmpty) {
      return title;
    }
    if (suggestedName.isNotEmpty && suggestedCompany.isNotEmpty) {
      final start = lines.indexOf(suggestedName);
      final end = lines.indexOf(suggestedCompany);
      if (start != -1 && end != -1 && end > start + 1) {
        final between = _stripFieldLabel(lines[start + 1]);
        if (between.isNotEmpty && !_looksLikeLikelyAddress(between)) {
          return between;
        }
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
          _looksLikeLikelyAddress(line) ||
          (RegExp(r'\d').hasMatch(line) &&
              !lower.contains('fax') &&
              !lower.contains('tel') &&
              !lower.contains('phone'))) {
        addressLines.add(line);
      }
    }
    return addressLines.join('\n').trim();
  }

  bool _looksLikeLikelyAddress(String line) {
    final lower = line.toLowerCase();
    if (_addressKeywords.any(lower.contains)) {
      return true;
    }
    return line.contains('〒') ||
        line.contains('東京都') ||
        line.contains('大阪府') ||
        line.contains('京都府') ||
        line.contains('北海道') ||
        RegExp(r'^(?:〒\s*)?\d{3}-\d{4}(?!-\d)').hasMatch(line);
  }

  bool _hasFieldPrefix(String lower) {
    return _contactFieldPrefixes.any(
      (prefix) =>
          lower.startsWith('$prefix:') ||
          lower.startsWith('$prefix ') ||
          lower.startsWith('$prefix.'),
    );
  }

  String _stripFieldLabel(String line) {
    var value = line.trim();
    for (final prefix in _contactFieldPrefixes) {
      final pattern = RegExp(
        '^${RegExp.escape(prefix)}\\s*[:：.-]?\\s*',
        caseSensitive: false,
      );
      value = value.replaceFirst(pattern, '');
    }
    return value.trim();
  }

  bool _looksLikePersonName(String line) {
    final compact = line.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.isEmpty || compact.length > 40) {
      return false;
    }
    if (RegExp(r'\d').hasMatch(compact)) {
      return false;
    }
    if (compact.contains('@') || compact.contains('http')) {
      return false;
    }
    final words = compact.split(' ');
    if (words.length >= 2 && words.length <= 4) {
      return true;
    }
    return RegExp(r'^[A-Za-z\u3040-\u30ff\u3400-\u9fff・ ]+$').hasMatch(compact);
  }

  String _bestScoredLine({
    required List<String> lines,
    required int Function(String line, int index) scorer,
    required int minimumScore,
  }) {
    var bestScore = minimumScore - 1;
    var bestLine = '';
    for (var index = 0; index < lines.length; index += 1) {
      final candidate = _stripFieldLabel(lines[index]);
      if (candidate.isEmpty) {
        continue;
      }
      final score = scorer(candidate, index);
      if (score > bestScore) {
        bestScore = score;
        bestLine = candidate;
      }
    }
    return bestLine;
  }
}
