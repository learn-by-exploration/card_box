class VisitingCardExtraction {
  const VisitingCardExtraction({
    required this.suggestedName,
    required this.suggestedCompany,
    required this.suggestedTitle,
    required this.suggestedPhones,
    required this.suggestedEmails,
    required this.suggestedWebsites,
    required this.suggestedAddress,
    required this.rawOcrText,
    this.hadRecognizerFailure = false,
  });

  final String suggestedName;
  final String suggestedCompany;
  final String suggestedTitle;
  final List<String> suggestedPhones;
  final List<String> suggestedEmails;
  final List<String> suggestedWebsites;
  final String suggestedAddress;
  final String rawOcrText;

  /// True when at least one of the text recognizers threw during
  /// the OCR run. The caller can use this to surface a one-time
  /// "OCR didn't return anything" hint instead of leaving the
  /// user staring at an empty form.
  final bool hadRecognizerFailure;
}
