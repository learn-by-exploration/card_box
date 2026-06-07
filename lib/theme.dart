import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import 'package:card_box/models/compatibility_status.dart';

enum CardBoxThemePalette { softTeal, forest, slate }

extension CardBoxThemePaletteX on CardBoxThemePalette {
  String get storageKey => switch (this) {
    CardBoxThemePalette.softTeal => 'soft_teal',
    CardBoxThemePalette.forest => 'forest',
    CardBoxThemePalette.slate => 'slate',
  };

  String get label => switch (this) {
    CardBoxThemePalette.softTeal => 'Soft teal',
    CardBoxThemePalette.forest => 'Forest',
    CardBoxThemePalette.slate => 'Slate',
  };

  String get description => switch (this) {
    CardBoxThemePalette.softTeal => 'Fresh, light, and quietly modern.',
    CardBoxThemePalette.forest => 'Calm, premium, and a little warmer.',
    CardBoxThemePalette.slate => 'Minimal, neutral, and very clean.',
  };
}

ThemeData get cardBoxLightTheme =>
    cardBoxLightThemeFor(CardBoxThemePalette.softTeal);

ThemeData get cardBoxDarkTheme =>
    cardBoxDarkThemeFor(CardBoxThemePalette.softTeal);

ThemeData cardBoxLightThemeFor(CardBoxThemePalette palette) {
  final spec = _paletteSpec(palette);
  final scheme = ColorScheme.fromSeed(
    brightness: Brightness.light,
    seedColor: spec.lightPrimary,
    primary: spec.lightPrimary,
    secondary: spec.lightSecondary,
    tertiary: spec.lightTertiary,
    surface: spec.lightOverlay,
  );
  return _buildTheme(
    scheme: scheme,
    scaffoldBackground: spec.lightScaffold,
    fieldFill: spec.lightFieldFill,
    borderColor: spec.lightBorder,
    cardBorder: spec.lightCardBorder,
    overlay: spec.lightOverlay,
    tokens: spec.lightTokens,
  );
}

ThemeData cardBoxDarkThemeFor(CardBoxThemePalette palette) {
  final spec = _paletteSpec(palette);
  final scheme = ColorScheme.fromSeed(
    brightness: Brightness.dark,
    seedColor: spec.darkPrimary,
    primary: spec.darkPrimary,
    secondary: spec.darkSecondary,
    tertiary: spec.darkTertiary,
    surface: spec.darkOverlay,
  );
  return _buildTheme(
    scheme: scheme,
    scaffoldBackground: spec.darkScaffold,
    fieldFill: spec.darkFieldFill,
    borderColor: spec.darkBorder,
    cardBorder: spec.darkCardBorder,
    overlay: spec.darkOverlay,
    tokens: spec.darkTokens,
  );
}

class _CardBoxPaletteSpec {
  const _CardBoxPaletteSpec({
    required this.lightPrimary,
    required this.lightSecondary,
    required this.lightTertiary,
    required this.lightScaffold,
    required this.lightFieldFill,
    required this.lightBorder,
    required this.lightCardBorder,
    required this.lightOverlay,
    required this.lightTokens,
    required this.darkPrimary,
    required this.darkSecondary,
    required this.darkTertiary,
    required this.darkScaffold,
    required this.darkFieldFill,
    required this.darkBorder,
    required this.darkCardBorder,
    required this.darkOverlay,
    required this.darkTokens,
  });

  final Color lightPrimary;
  final Color lightSecondary;
  final Color lightTertiary;
  final Color lightScaffold;
  final Color lightFieldFill;
  final Color lightBorder;
  final Color lightCardBorder;
  final Color lightOverlay;
  final CardBoxThemeTokens lightTokens;
  final Color darkPrimary;
  final Color darkSecondary;
  final Color darkTertiary;
  final Color darkScaffold;
  final Color darkFieldFill;
  final Color darkBorder;
  final Color darkCardBorder;
  final Color darkOverlay;
  final CardBoxThemeTokens darkTokens;
}

_CardBoxPaletteSpec _paletteSpec(CardBoxThemePalette palette) {
  return switch (palette) {
    CardBoxThemePalette.softTeal => const _CardBoxPaletteSpec(
      lightPrimary: Color(0xFF1B8A88),
      lightSecondary: Color(0xFFCA6F3C),
      lightTertiary: Color(0xFF5C6FB2),
      lightScaffold: Color(0xFFF6F8F8),
      lightFieldFill: Color(0xFFFFFFFF),
      lightBorder: Color(0xFFD8E0E0),
      lightCardBorder: Color(0xFFE2E8E8),
      lightOverlay: Color(0xFFFFFFFF),
      lightTokens: CardBoxThemeTokens(
        surfaceSubtle: Color(0xFFF0F5F5),
        surfaceRaised: Color(0xFFFFFFFF),
        surfaceInteractive: Color(0xFFE6F3F2),
        borderSoft: Color(0xFFD8E0E0),
        presentationSurface: Color(0xFFFFFFFF),
        presentationCanvas: Color(0xFFF7F9F9),
        statusContact: CardBoxStatusTone(
          background: Color(0xFFE8F6F4),
          foreground: Color(0xFF155D59),
        ),
        statusReady: CardBoxStatusTone(
          background: Color(0xFFEAF6EE),
          foreground: Color(0xFF255E3B),
        ),
        statusReadable: CardBoxStatusTone(
          background: Color(0xFFE9F2FC),
          foreground: Color(0xFF1D4E8F),
        ),
        statusReference: CardBoxStatusTone(
          background: Color(0xFFF2EEEA),
          foreground: Color(0xFF6D594A),
        ),
        statusWarning: CardBoxStatusTone(
          background: Color(0xFFFCF2E4),
          foreground: Color(0xFF8A591B),
        ),
        statusCandidate: CardBoxStatusTone(
          background: Color(0xFFEFEDF8),
          foreground: Color(0xFF4D4184),
        ),
        statusUnsupported: CardBoxStatusTone(
          background: Color(0xFFFCEBED),
          foreground: Color(0xFF8E2A2A),
        ),
        appObscureScrim: Color(0xFF0F1416),
        radiusSmall: 12,
        radiusMedium: 14,
        radiusLarge: 18,
        spaceXSmall: 4,
        spaceSmall: 8,
        spaceMedium: 12,
        spaceLarge: 16,
        spaceXLarge: 20,
        iconSmall: 18,
        iconMedium: 20,
        iconLarge: 24,
      ),
      darkPrimary: Color(0xFF7BD7D1),
      darkSecondary: Color(0xFFF0B07D),
      darkTertiary: Color(0xFFC2CBFF),
      darkScaffold: Color(0xFF101415),
      darkFieldFill: Color(0xFF171D1E),
      darkBorder: Color(0xFF293233),
      darkCardBorder: Color(0xFF232B2C),
      darkOverlay: Color(0xFF161C1D),
      darkTokens: CardBoxThemeTokens(
        surfaceSubtle: Color(0xFF1A2122),
        surfaceRaised: Color(0xFF161C1D),
        surfaceInteractive: Color(0xFF203334),
        borderSoft: Color(0xFF293233),
        presentationSurface: Color(0xFFF6F8F9),
        presentationCanvas: Color(0xFF111617),
        statusContact: CardBoxStatusTone(
          background: Color(0xFF173731),
          foreground: Color(0xFFA2E6D8),
        ),
        statusReady: CardBoxStatusTone(
          background: Color(0xFF21372A),
          foreground: Color(0xFFB0E6BC),
        ),
        statusReadable: CardBoxStatusTone(
          background: Color(0xFF1B324C),
          foreground: Color(0xFFAED2FF),
        ),
        statusReference: CardBoxStatusTone(
          background: Color(0xFF332D27),
          foreground: Color(0xFFE5CCB3),
        ),
        statusWarning: CardBoxStatusTone(
          background: Color(0xFF3C2E1E),
          foreground: Color(0xFFF2C792),
        ),
        statusCandidate: CardBoxStatusTone(
          background: Color(0xFF2E2845),
          foreground: Color(0xFFD6C5FF),
        ),
        statusUnsupported: CardBoxStatusTone(
          background: Color(0xFF3F2427),
          foreground: Color(0xFFFFBCBC),
        ),
        appObscureScrim: Color(0xFF0B0E10),
        radiusSmall: 12,
        radiusMedium: 14,
        radiusLarge: 18,
        spaceXSmall: 4,
        spaceSmall: 8,
        spaceMedium: 12,
        spaceLarge: 16,
        spaceXLarge: 20,
        iconSmall: 18,
        iconMedium: 20,
        iconLarge: 24,
      ),
    ),
    CardBoxThemePalette.forest => const _CardBoxPaletteSpec(
      lightPrimary: Color(0xFF2A6E55),
      lightSecondary: Color(0xFFB87443),
      lightTertiary: Color(0xFF536B4E),
      lightScaffold: Color(0xFFF7F8F5),
      lightFieldFill: Color(0xFFFFFFFF),
      lightBorder: Color(0xFFDCE2D8),
      lightCardBorder: Color(0xFFE5E9E1),
      lightOverlay: Color(0xFFFFFFFF),
      lightTokens: CardBoxThemeTokens(
        surfaceSubtle: Color(0xFFF2F5F0),
        surfaceRaised: Color(0xFFFFFFFF),
        surfaceInteractive: Color(0xFFE9F2EC),
        borderSoft: Color(0xFFDCE2D8),
        presentationSurface: Color(0xFFFFFFFF),
        presentationCanvas: Color(0xFFF7F8F5),
        statusContact: CardBoxStatusTone(
          background: Color(0xFFEAF6EF),
          foreground: Color(0xFF1D5B45),
        ),
        statusReady: CardBoxStatusTone(
          background: Color(0xFFEEF6EA),
          foreground: Color(0xFF365A2B),
        ),
        statusReadable: CardBoxStatusTone(
          background: Color(0xFFEAF1FB),
          foreground: Color(0xFF214D86),
        ),
        statusReference: CardBoxStatusTone(
          background: Color(0xFFF3EFE8),
          foreground: Color(0xFF6D5B48),
        ),
        statusWarning: CardBoxStatusTone(
          background: Color(0xFFFDF1E4),
          foreground: Color(0xFF8B591B),
        ),
        statusCandidate: CardBoxStatusTone(
          background: Color(0xFFEFEDF7),
          foreground: Color(0xFF4D4281),
        ),
        statusUnsupported: CardBoxStatusTone(
          background: Color(0xFFFCEBED),
          foreground: Color(0xFF8E2A2A),
        ),
        appObscureScrim: Color(0xFF101513),
        radiusSmall: 12,
        radiusMedium: 14,
        radiusLarge: 18,
        spaceXSmall: 4,
        spaceSmall: 8,
        spaceMedium: 12,
        spaceLarge: 16,
        spaceXLarge: 20,
        iconSmall: 18,
        iconMedium: 20,
        iconLarge: 24,
      ),
      darkPrimary: Color(0xFF85C9A7),
      darkSecondary: Color(0xFFF0B78B),
      darkTertiary: Color(0xFFC0D4B8),
      darkScaffold: Color(0xFF101513),
      darkFieldFill: Color(0xFF171D1A),
      darkBorder: Color(0xFF2A322D),
      darkCardBorder: Color(0xFF232B26),
      darkOverlay: Color(0xFF161C19),
      darkTokens: CardBoxThemeTokens(
        surfaceSubtle: Color(0xFF1B211E),
        surfaceRaised: Color(0xFF161C19),
        surfaceInteractive: Color(0xFF223129),
        borderSoft: Color(0xFF2A322D),
        presentationSurface: Color(0xFFF7F8F5),
        presentationCanvas: Color(0xFF111613),
        statusContact: CardBoxStatusTone(
          background: Color(0xFF1A372C),
          foreground: Color(0xFFA9E4C2),
        ),
        statusReady: CardBoxStatusTone(
          background: Color(0xFF263625),
          foreground: Color(0xFFB7E4AA),
        ),
        statusReadable: CardBoxStatusTone(
          background: Color(0xFF1A314B),
          foreground: Color(0xFFAFD2FF),
        ),
        statusReference: CardBoxStatusTone(
          background: Color(0xFF342D27),
          foreground: Color(0xFFE4CEB5),
        ),
        statusWarning: CardBoxStatusTone(
          background: Color(0xFF3C2F1F),
          foreground: Color(0xFFF2C895),
        ),
        statusCandidate: CardBoxStatusTone(
          background: Color(0xFF2E2843),
          foreground: Color(0xFFD5C6FF),
        ),
        statusUnsupported: CardBoxStatusTone(
          background: Color(0xFF3F2427),
          foreground: Color(0xFFFFBCBC),
        ),
        appObscureScrim: Color(0xFF0B100E),
        radiusSmall: 12,
        radiusMedium: 14,
        radiusLarge: 18,
        spaceXSmall: 4,
        spaceSmall: 8,
        spaceMedium: 12,
        spaceLarge: 16,
        spaceXLarge: 20,
        iconSmall: 18,
        iconMedium: 20,
        iconLarge: 24,
      ),
    ),
    CardBoxThemePalette.slate => const _CardBoxPaletteSpec(
      lightPrimary: Color(0xFF476B7A),
      lightSecondary: Color(0xFF9A6B47),
      lightTertiary: Color(0xFF5E6280),
      lightScaffold: Color(0xFFF7F8FA),
      lightFieldFill: Color(0xFFFFFFFF),
      lightBorder: Color(0xFFD8DEE5),
      lightCardBorder: Color(0xFFE2E7ED),
      lightOverlay: Color(0xFFFFFFFF),
      lightTokens: CardBoxThemeTokens(
        surfaceSubtle: Color(0xFFF1F4F7),
        surfaceRaised: Color(0xFFFFFFFF),
        surfaceInteractive: Color(0xFFEAF0F5),
        borderSoft: Color(0xFFD8DEE5),
        presentationSurface: Color(0xFFFFFFFF),
        presentationCanvas: Color(0xFFF8F9FB),
        statusContact: CardBoxStatusTone(
          background: Color(0xFFEAF3F6),
          foreground: Color(0xFF244F5E),
        ),
        statusReady: CardBoxStatusTone(
          background: Color(0xFFEEF5EE),
          foreground: Color(0xFF34583A),
        ),
        statusReadable: CardBoxStatusTone(
          background: Color(0xFFEAF1FB),
          foreground: Color(0xFF214D86),
        ),
        statusReference: CardBoxStatusTone(
          background: Color(0xFFF1EEEA),
          foreground: Color(0xFF675A4D),
        ),
        statusWarning: CardBoxStatusTone(
          background: Color(0xFFFDF1E4),
          foreground: Color(0xFF8A591B),
        ),
        statusCandidate: CardBoxStatusTone(
          background: Color(0xFFEFEDF7),
          foreground: Color(0xFF4D4281),
        ),
        statusUnsupported: CardBoxStatusTone(
          background: Color(0xFFFCEBED),
          foreground: Color(0xFF8E2A2A),
        ),
        appObscureScrim: Color(0xFF111417),
        radiusSmall: 12,
        radiusMedium: 14,
        radiusLarge: 18,
        spaceXSmall: 4,
        spaceSmall: 8,
        spaceMedium: 12,
        spaceLarge: 16,
        spaceXLarge: 20,
        iconSmall: 18,
        iconMedium: 20,
        iconLarge: 24,
      ),
      darkPrimary: Color(0xFFA8C7D3),
      darkSecondary: Color(0xFFDAB38F),
      darkTertiary: Color(0xFFD2D5F4),
      darkScaffold: Color(0xFF101417),
      darkFieldFill: Color(0xFF171C20),
      darkBorder: Color(0xFF2A3138),
      darkCardBorder: Color(0xFF232A30),
      darkOverlay: Color(0xFF161B1F),
      darkTokens: CardBoxThemeTokens(
        surfaceSubtle: Color(0xFF1B2025),
        surfaceRaised: Color(0xFF161B1F),
        surfaceInteractive: Color(0xFF21303A),
        borderSoft: Color(0xFF2A3138),
        presentationSurface: Color(0xFFF6F8F9),
        presentationCanvas: Color(0xFF111518),
        statusContact: CardBoxStatusTone(
          background: Color(0xFF1C333D),
          foreground: Color(0xFFB2DBEA),
        ),
        statusReady: CardBoxStatusTone(
          background: Color(0xFF243629),
          foreground: Color(0xFFB7E4B8),
        ),
        statusReadable: CardBoxStatusTone(
          background: Color(0xFF1A314B),
          foreground: Color(0xFFAFD2FF),
        ),
        statusReference: CardBoxStatusTone(
          background: Color(0xFF332D27),
          foreground: Color(0xFFE4CEB5),
        ),
        statusWarning: CardBoxStatusTone(
          background: Color(0xFF3B2E1F),
          foreground: Color(0xFFF1C894),
        ),
        statusCandidate: CardBoxStatusTone(
          background: Color(0xFF2E2843),
          foreground: Color(0xFFD5C6FF),
        ),
        statusUnsupported: CardBoxStatusTone(
          background: Color(0xFF3F2427),
          foreground: Color(0xFFFFBCBC),
        ),
        appObscureScrim: Color(0xFF0B0E10),
        radiusSmall: 12,
        radiusMedium: 14,
        radiusLarge: 18,
        spaceXSmall: 4,
        spaceSmall: 8,
        spaceMedium: 12,
        spaceLarge: 16,
        spaceXLarge: 20,
        iconSmall: 18,
        iconMedium: 20,
        iconLarge: 24,
      ),
    ),
  };
}

ThemeData _buildTheme({
  required ColorScheme scheme,
  required Color scaffoldBackground,
  required Color fieldFill,
  required Color borderColor,
  required Color cardBorder,
  required Color overlay,
  required CardBoxThemeTokens tokens,
}) {
  final base = ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: scaffoldBackground,
    useMaterial3: true,
    extensions: <ThemeExtension<dynamic>>[tokens],
  );
  return base.copyWith(
    appBarTheme: AppBarTheme(
      centerTitle: false,
      backgroundColor: scaffoldBackground,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: fieldFill,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(tokens.radiusMedium),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(tokens.radiusMedium),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(tokens.radiusMedium),
        borderSide: BorderSide(color: scheme.primary, width: 1.4),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radiusSmall),
      ),
      side: BorderSide(color: borderColor),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: overlay,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(tokens.radiusSmall)),
        side: BorderSide(color: cardBorder),
      ),
      margin: EdgeInsets.zero,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scaffoldBackground,
      modalBackgroundColor: scaffoldBackground,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: fieldFill,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radiusLarge),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radiusLarge),
      ),
    ),
    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radiusMedium),
      ),
      iconColor: scheme.onSurfaceVariant,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radiusSmall),
      ),
    ),
  );
}

class CardBoxStatusTone {
  const CardBoxStatusTone({required this.background, required this.foreground});

  final Color background;
  final Color foreground;
}

class CardBoxThemeTokens extends ThemeExtension<CardBoxThemeTokens> {
  const CardBoxThemeTokens({
    required this.surfaceSubtle,
    required this.surfaceRaised,
    required this.surfaceInteractive,
    required this.borderSoft,
    required this.presentationSurface,
    required this.presentationCanvas,
    required this.statusContact,
    required this.statusReady,
    required this.statusReadable,
    required this.statusReference,
    required this.statusWarning,
    required this.statusCandidate,
    required this.statusUnsupported,
    required this.appObscureScrim,
    required this.radiusSmall,
    required this.radiusMedium,
    required this.radiusLarge,
    required this.spaceXSmall,
    required this.spaceSmall,
    required this.spaceMedium,
    required this.spaceLarge,
    required this.spaceXLarge,
    required this.iconSmall,
    required this.iconMedium,
    required this.iconLarge,
  });

  final Color surfaceSubtle;
  final Color surfaceRaised;
  final Color surfaceInteractive;
  final Color borderSoft;
  final Color presentationSurface;
  final Color presentationCanvas;
  final CardBoxStatusTone statusContact;
  final CardBoxStatusTone statusReady;
  final CardBoxStatusTone statusReadable;
  final CardBoxStatusTone statusReference;
  final CardBoxStatusTone statusWarning;
  final CardBoxStatusTone statusCandidate;
  final CardBoxStatusTone statusUnsupported;
  final Color appObscureScrim;
  final double radiusSmall;
  final double radiusMedium;
  final double radiusLarge;
  final double spaceXSmall;
  final double spaceSmall;
  final double spaceMedium;
  final double spaceLarge;
  final double spaceXLarge;
  final double iconSmall;
  final double iconMedium;
  final double iconLarge;

  CardBoxStatusTone statusToneFor(
    CompatibilityStatus status, {
    required bool isVisitingCard,
  }) {
    if (isVisitingCard) {
      return statusContact;
    }
    return switch (status) {
      CompatibilityStatus.barcodeDisplayable => statusReady,
      CompatibilityStatus.nfcReadable => statusReadable,
      CompatibilityStatus.referenceOnly => statusReference,
      CompatibilityStatus.untested => statusWarning,
      CompatibilityStatus.nfcDetectedNotReadable => statusWarning,
      CompatibilityStatus.androidHceCandidate => statusCandidate,
      CompatibilityStatus.unsupported => statusUnsupported,
    };
  }

  static CardBoxThemeTokens of(BuildContext context) {
    final tokens = Theme.of(context).extension<CardBoxThemeTokens>();
    assert(tokens != null, 'CardBoxThemeTokens not found in ThemeData.');
    return tokens!;
  }

  @override
  ThemeExtension<CardBoxThemeTokens> copyWith({
    Color? surfaceSubtle,
    Color? surfaceRaised,
    Color? surfaceInteractive,
    Color? borderSoft,
    Color? presentationSurface,
    Color? presentationCanvas,
    CardBoxStatusTone? statusContact,
    CardBoxStatusTone? statusReady,
    CardBoxStatusTone? statusReadable,
    CardBoxStatusTone? statusReference,
    CardBoxStatusTone? statusWarning,
    CardBoxStatusTone? statusCandidate,
    CardBoxStatusTone? statusUnsupported,
    Color? appObscureScrim,
    double? radiusSmall,
    double? radiusMedium,
    double? radiusLarge,
    double? spaceXSmall,
    double? spaceSmall,
    double? spaceMedium,
    double? spaceLarge,
    double? spaceXLarge,
    double? iconSmall,
    double? iconMedium,
    double? iconLarge,
  }) {
    return CardBoxThemeTokens(
      surfaceSubtle: surfaceSubtle ?? this.surfaceSubtle,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      surfaceInteractive: surfaceInteractive ?? this.surfaceInteractive,
      borderSoft: borderSoft ?? this.borderSoft,
      presentationSurface: presentationSurface ?? this.presentationSurface,
      presentationCanvas: presentationCanvas ?? this.presentationCanvas,
      statusContact: statusContact ?? this.statusContact,
      statusReady: statusReady ?? this.statusReady,
      statusReadable: statusReadable ?? this.statusReadable,
      statusReference: statusReference ?? this.statusReference,
      statusWarning: statusWarning ?? this.statusWarning,
      statusCandidate: statusCandidate ?? this.statusCandidate,
      statusUnsupported: statusUnsupported ?? this.statusUnsupported,
      appObscureScrim: appObscureScrim ?? this.appObscureScrim,
      radiusSmall: radiusSmall ?? this.radiusSmall,
      radiusMedium: radiusMedium ?? this.radiusMedium,
      radiusLarge: radiusLarge ?? this.radiusLarge,
      spaceXSmall: spaceXSmall ?? this.spaceXSmall,
      spaceSmall: spaceSmall ?? this.spaceSmall,
      spaceMedium: spaceMedium ?? this.spaceMedium,
      spaceLarge: spaceLarge ?? this.spaceLarge,
      spaceXLarge: spaceXLarge ?? this.spaceXLarge,
      iconSmall: iconSmall ?? this.iconSmall,
      iconMedium: iconMedium ?? this.iconMedium,
      iconLarge: iconLarge ?? this.iconLarge,
    );
  }

  @override
  ThemeExtension<CardBoxThemeTokens> lerp(
    covariant ThemeExtension<CardBoxThemeTokens>? other,
    double t,
  ) {
    if (other is! CardBoxThemeTokens) {
      return this;
    }
    return CardBoxThemeTokens(
      surfaceSubtle: Color.lerp(surfaceSubtle, other.surfaceSubtle, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      surfaceInteractive: Color.lerp(
        surfaceInteractive,
        other.surfaceInteractive,
        t,
      )!,
      borderSoft: Color.lerp(borderSoft, other.borderSoft, t)!,
      presentationSurface: Color.lerp(
        presentationSurface,
        other.presentationSurface,
        t,
      )!,
      presentationCanvas: Color.lerp(
        presentationCanvas,
        other.presentationCanvas,
        t,
      )!,
      statusContact: _lerpTone(statusContact, other.statusContact, t),
      statusReady: _lerpTone(statusReady, other.statusReady, t),
      statusReadable: _lerpTone(statusReadable, other.statusReadable, t),
      statusReference: _lerpTone(statusReference, other.statusReference, t),
      statusWarning: _lerpTone(statusWarning, other.statusWarning, t),
      statusCandidate: _lerpTone(statusCandidate, other.statusCandidate, t),
      statusUnsupported: _lerpTone(
        statusUnsupported,
        other.statusUnsupported,
        t,
      ),
      appObscureScrim: Color.lerp(appObscureScrim, other.appObscureScrim, t)!,
      radiusSmall: lerpDouble(radiusSmall, other.radiusSmall, t)!,
      radiusMedium: lerpDouble(radiusMedium, other.radiusMedium, t)!,
      radiusLarge: lerpDouble(radiusLarge, other.radiusLarge, t)!,
      spaceXSmall: lerpDouble(spaceXSmall, other.spaceXSmall, t)!,
      spaceSmall: lerpDouble(spaceSmall, other.spaceSmall, t)!,
      spaceMedium: lerpDouble(spaceMedium, other.spaceMedium, t)!,
      spaceLarge: lerpDouble(spaceLarge, other.spaceLarge, t)!,
      spaceXLarge: lerpDouble(spaceXLarge, other.spaceXLarge, t)!,
      iconSmall: lerpDouble(iconSmall, other.iconSmall, t)!,
      iconMedium: lerpDouble(iconMedium, other.iconMedium, t)!,
      iconLarge: lerpDouble(iconLarge, other.iconLarge, t)!,
    );
  }

  static CardBoxStatusTone _lerpTone(
    CardBoxStatusTone a,
    CardBoxStatusTone b,
    double t,
  ) {
    return CardBoxStatusTone(
      background: Color.lerp(a.background, b.background, t)!,
      foreground: Color.lerp(a.foreground, b.foreground, t)!,
    );
  }
}
