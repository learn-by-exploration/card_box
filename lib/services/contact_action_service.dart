import 'package:url_launcher/url_launcher.dart';

class ContactActionService {
  const ContactActionService();

  Uri? phoneUri(String phone) {
    final normalized = phone.trim();
    if (normalized.isEmpty) {
      return null;
    }
    return Uri(scheme: 'tel', path: normalized);
  }

  Uri? emailUri(String email) {
    final normalized = email.trim();
    if (normalized.isEmpty) {
      return null;
    }
    return Uri(scheme: 'mailto', path: normalized);
  }

  Uri? websiteUri(String website) {
    final normalized = website.trim();
    if (normalized.isEmpty) {
      return null;
    }
    if (normalized.contains('://')) {
      return Uri.tryParse(normalized);
    }
    return Uri.tryParse('https://$normalized');
  }

  Future<bool> open(Uri uri) {
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
