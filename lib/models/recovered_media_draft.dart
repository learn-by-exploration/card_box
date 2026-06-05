import 'package:card_box/models/add_card_preset.dart';

class RecoveredMediaDraft {
  const RecoveredMediaDraft({
    required this.draftCardId,
    required this.preset,
    this.existingCardId,
    this.frontImagePath = '',
    this.backImagePath = '',
  });

  final String draftCardId;
  final AddCardPreset preset;
  final String? existingCardId;
  final String frontImagePath;
  final String backImagePath;

  bool get targetsExistingCard => existingCardId?.trim().isNotEmpty == true;

  bool get hasFrontImage => frontImagePath.trim().isNotEmpty;

  bool get hasBackImage => backImagePath.trim().isNotEmpty;

  String get recoveredSideLabel => hasFrontImage ? 'front' : 'back';
}
