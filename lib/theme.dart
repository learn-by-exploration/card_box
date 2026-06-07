import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import 'package:card_box/models/compatibility_status.dart';

ThemeData get cardBoxLightTheme {
  const seed = Color(0xFF196C6B);
  final scheme = ColorScheme.fromSeed(
    brightness: Brightness.light,
    seedColor: seed,
    primary: const Color(0xFF196C6B),
    secondary: const Color(0xFFB65F2A),
    tertiary: const Color(0xFF415F91),
    surface: const Color(0xFFFDFDFD),
  );
  return _buildTheme(
    scheme: scheme,
    scaffoldBackground: const Color(0xFFF6F7F8),
    fieldFill: const Color(0xFFFFFFFF),
    borderColor: const Color(0xFFD9DEE3),
    cardBorder: const Color(0xFFE3E7EB),
    overlay: const Color(0xFFFFFFFF),
    tokens: const CardBoxThemeTokens(
      surfaceSubtle: Color(0xFFF1F4F6),
      surfaceRaised: Color(0xFFFFFFFF),
      surfaceInteractive: Color(0xFFE9F2F2),
      borderSoft: Color(0xFFD9DEE3),
      presentationSurface: Color(0xFFFFFFFF),
      presentationCanvas: Color(0xFFF7F9FA),
      statusContact: CardBoxStatusTone(
        background: Color(0xFFE8F5F2),
        foreground: Color(0xFF115847),
      ),
      statusReady: CardBoxStatusTone(
        background: Color(0xFFEAF5EE),
        foreground: Color(0xFF245E37),
      ),
      statusReadable: CardBoxStatusTone(
        background: Color(0xFFE8F1FB),
        foreground: Color(0xFF184A8B),
      ),
      statusReference: CardBoxStatusTone(
        background: Color(0xFFF1EDE7),
        foreground: Color(0xFF6A5648),
      ),
      statusWarning: CardBoxStatusTone(
        background: Color(0xFFFCF1E3),
        foreground: Color(0xFF8B5718),
      ),
      statusCandidate: CardBoxStatusTone(
        background: Color(0xFFEFECF8),
        foreground: Color(0xFF4B3E85),
      ),
      statusUnsupported: CardBoxStatusTone(
        background: Color(0xFFFCEBEC),
        foreground: Color(0xFF8D2727),
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
  );
}

ThemeData get cardBoxDarkTheme {
  const seed = Color(0xFF58B2AC);
  final scheme = ColorScheme.fromSeed(
    brightness: Brightness.dark,
    seedColor: seed,
    primary: const Color(0xFF7AD1CB),
    secondary: const Color(0xFFF3B37C),
    tertiary: const Color(0xFFB7C8FF),
    surface: const Color(0xFF15191B),
  );
  return _buildTheme(
    scheme: scheme,
    scaffoldBackground: const Color(0xFF101315),
    fieldFill: const Color(0xFF171C1F),
    borderColor: const Color(0xFF2A3135),
    cardBorder: const Color(0xFF232A2E),
    overlay: const Color(0xFF161B1D),
    tokens: const CardBoxThemeTokens(
      surfaceSubtle: Color(0xFF1B2023),
      surfaceRaised: Color(0xFF161B1D),
      surfaceInteractive: Color(0xFF203032),
      borderSoft: Color(0xFF2A3135),
      presentationSurface: Color(0xFFF6F8F9),
      presentationCanvas: Color(0xFF111518),
      statusContact: CardBoxStatusTone(
        background: Color(0xFF17352D),
        foreground: Color(0xFF9FE3CF),
      ),
      statusReady: CardBoxStatusTone(
        background: Color(0xFF203629),
        foreground: Color(0xFFAAE1B6),
      ),
      statusReadable: CardBoxStatusTone(
        background: Color(0xFF1A314B),
        foreground: Color(0xFFA9CFFF),
      ),
      statusReference: CardBoxStatusTone(
        background: Color(0xFF322B25),
        foreground: Color(0xFFE3C8AF),
      ),
      statusWarning: CardBoxStatusTone(
        background: Color(0xFF3A2D1E),
        foreground: Color(0xFFF0C28D),
      ),
      statusCandidate: CardBoxStatusTone(
        background: Color(0xFF2D2743),
        foreground: Color(0xFFD2C1FF),
      ),
      statusUnsupported: CardBoxStatusTone(
        background: Color(0xFF3D2426),
        foreground: Color(0xFFFFBAB9),
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
  );
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
