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
  });

  final String suggestedName;
  final String suggestedCompany;
  final String suggestedTitle;
  final List<String> suggestedPhones;
  final List<String> suggestedEmails;
  final List<String> suggestedWebsites;
  final String suggestedAddress;
  final String rawOcrText;
}
