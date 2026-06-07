import 'package:flutter/material.dart';

import 'package:card_box/services/theme_service.dart';
import 'package:card_box/theme.dart';

class ThemeSettingsScreen extends StatelessWidget {
  const ThemeSettingsScreen({super.key, required this.themeService});

  final ThemeService themeService;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themeService,
      builder: (context, _) {
        final mode = themeService.themeMode;
        final palette = themeService.palette;
        final tokens = CardBoxThemeTokens.of(context);
        return Scaffold(
          appBar: AppBar(title: const Text('Theme')),
          body: ListView(
            padding: EdgeInsets.fromLTRB(
              tokens.spaceLarge,
              tokens.spaceMedium,
              tokens.spaceLarge,
              tokens.spaceXLarge + 4,
            ),
            children: [
              Text(
                'Choose how Card Box should look.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              SizedBox(height: tokens.spaceLarge),
              Text(
                'Color style',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              SizedBox(height: tokens.spaceSmall),
              for (final candidate in CardBoxThemePalette.values) ...[
                _ThemePaletteTile(
                  palette: candidate,
                  selected: palette == candidate,
                  onTap: () => themeService.updatePalette(candidate),
                ),
                SizedBox(height: tokens.spaceMedium - 2),
              ],
              SizedBox(height: tokens.spaceSmall),
              Text(
                'Appearance mode',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              SizedBox(height: tokens.spaceSmall),
              _ThemeModeTile(
                title: 'System',
                subtitle: 'Match your phone settings automatically.',
                icon: Icons.brightness_auto_outlined,
                selected: mode == ThemeMode.system,
                onTap: () => themeService.updateThemeMode(ThemeMode.system),
              ),
              SizedBox(height: tokens.spaceMedium - 2),
              _ThemeModeTile(
                title: 'Light',
                subtitle: 'Bright, calm, and easy to scan.',
                icon: Icons.light_mode_outlined,
                selected: mode == ThemeMode.light,
                onTap: () => themeService.updateThemeMode(ThemeMode.light),
              ),
              SizedBox(height: tokens.spaceMedium - 2),
              _ThemeModeTile(
                title: 'Dark',
                subtitle: 'Lower glare with a quieter nighttime look.',
                icon: Icons.dark_mode_outlined,
                selected: mode == ThemeMode.dark,
                onTap: () => themeService.updateThemeMode(ThemeMode.dark),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ThemePaletteTile extends StatelessWidget {
  const _ThemePaletteTile({
    required this.palette,
    required this.selected,
    required this.onTap,
  });

  final CardBoxThemePalette palette;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final tokens = CardBoxThemeTokens.of(context);
    final swatches = switch (palette) {
      CardBoxThemePalette.softTeal => const <Color>[
        Color(0xFF1B8A88),
        Color(0xFFCA6F3C),
        Color(0xFFF0F5F5),
      ],
      CardBoxThemePalette.forest => const <Color>[
        Color(0xFF2A6E55),
        Color(0xFFB87443),
        Color(0xFFF2F5F0),
      ],
      CardBoxThemePalette.slate => const <Color>[
        Color(0xFF476B7A),
        Color(0xFF9A6B47),
        Color(0xFFF1F4F7),
      ],
    };
    return Material(
      color: selected ? colors.secondaryContainer : colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(tokens.radiusMedium),
      child: InkWell(
        borderRadius: BorderRadius.circular(tokens.radiusMedium),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(tokens.spaceMedium),
          child: Row(
            children: [
              Row(
                children: [
                  for (final swatch in swatches)
                    Container(
                      width: 20,
                      height: 20,
                      margin: EdgeInsets.only(right: tokens.spaceXSmall),
                      decoration: BoxDecoration(
                        color: swatch,
                        borderRadius: BorderRadius.circular(tokens.radiusSmall),
                        border: Border.all(color: colors.outlineVariant),
                      ),
                    ),
                ],
              ),
              SizedBox(width: tokens.spaceMedium),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      palette.label,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: tokens.spaceXSmall / 2),
                    Text(
                      palette.description,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              SizedBox(width: tokens.spaceMedium),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected ? colors.primary : colors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeModeTile extends StatelessWidget {
  const _ThemeModeTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final tokens = CardBoxThemeTokens.of(context);
    return Material(
      color: selected ? colors.secondaryContainer : colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(tokens.radiusMedium),
      child: InkWell(
        borderRadius: BorderRadius.circular(tokens.radiusMedium),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(tokens.spaceMedium),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: selected
                      ? colors.primary.withValues(alpha: 0.14)
                      : colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(tokens.radiusSmall),
                ),
                child: Icon(
                  icon,
                  color: selected ? colors.primary : colors.onSurfaceVariant,
                ),
              ),
              SizedBox(width: tokens.spaceMedium),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: tokens.spaceXSmall / 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              SizedBox(width: tokens.spaceMedium),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected ? colors.primary : colors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
