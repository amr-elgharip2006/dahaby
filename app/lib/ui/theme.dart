import 'package:flutter/material.dart';

/// Dahaby's colours. Screens read colours from the theme; these are for the
/// few places that are gold in both light and dark mode.
abstract final class Brand {
  static const gold = Color(0xFFB8860B);

  /// Dark brown used for text and marks that sit on gold.
  static const ink = Color(0xFF2B1F00);

  /// The gold of the logo and the headline cards. Text on it is [ink].
  static const goldGradient = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [Color(0xFFF6DC8C), Color(0xFFE9BE4C), Color(0xFFC99416)],
  );
}

/// Colours that are not part of Material's scheme.
class DahabyColors extends ThemeExtension<DahabyColors> {
  const DahabyColors({
    required this.gain,
    required this.loss,
    required this.silver,
  });

  final Color gain;
  final Color loss;
  final Color silver;

  static const light = DahabyColors(
    gain: Color(0xFF1B7F45),
    loss: Color(0xFFC0352B),
    silver: Color(0xFF7C8794),
  );
  static const dark = DahabyColors(
    gain: Color(0xFF55C98D),
    loss: Color(0xFFFF7B6E),
    silver: Color(0xFFAAB4C0),
  );

  static DahabyColors of(BuildContext context) =>
      Theme.of(context).extension<DahabyColors>() ?? light;

  @override
  DahabyColors copyWith({Color? gain, Color? loss, Color? silver}) =>
      DahabyColors(
        gain: gain ?? this.gain,
        loss: loss ?? this.loss,
        silver: silver ?? this.silver,
      );

  @override
  DahabyColors lerp(DahabyColors? other, double t) {
    if (other == null) return this;
    return DahabyColors(
      gain: Color.lerp(gain, other.gain, t)!,
      loss: Color.lerp(loss, other.loss, t)!,
      silver: Color.lerp(silver, other.silver, t)!,
    );
  }
}

/// The app theme for [brightness]: warm ivory in light mode, warm charcoal in
/// dark mode, gold accents in both.
ThemeData dahabyTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: Brand.gold,
        brightness: brightness,
      ).copyWith(
        surface: dark ? const Color(0xFF14110B) : const Color(0xFFFBF7EF),
        surfaceContainerLowest: dark ? const Color(0xFF1D1912) : Colors.white,
        surfaceContainerLow: dark ? const Color(0xFF1D1912) : Colors.white,
        surfaceContainer: dark ? const Color(0xFF1A160F) : Colors.white,
        surfaceContainerHigh: dark
            ? const Color(0xFF262117)
            : const Color(0xFFF4EDDD),
        surfaceContainerHighest: dark
            ? const Color(0xFF2C261B)
            : const Color(0xFFF1E9D6),
        onSurface: dark ? const Color(0xFFF3EBDA) : const Color(0xFF211B10),
        onSurfaceVariant: dark
            ? const Color(0xFFB5AA93)
            : const Color(0xFF6E6552),
        outlineVariant: dark
            ? const Color(0xFF312A1D)
            : const Color(0xFFEAE0CB),
      );

  final base = ThemeData(
    colorScheme: scheme,
    fontFamily: 'Cairo',
    scaffoldBackgroundColor: scheme.surface,
    extensions: [dark ? DahabyColors.dark : DahabyColors.light],
  );
  final text = base.textTheme;
  final border = BorderSide(color: scheme.outlineVariant);
  OutlineInputBorder input(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: color, width: width),
      );

  return base.copyWith(
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: text.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        color: scheme.onSurface,
      ),
    ),
    cardTheme: CardThemeData(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: scheme.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: border,
      ),
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
    navigationBarTheme: NavigationBarThemeData(
      height: 68,
      backgroundColor: scheme.surfaceContainer,
      surfaceTintColor: Colors.transparent,
      indicatorColor: scheme.primaryContainer,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => text.labelSmall?.copyWith(
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
          color: states.contains(WidgetState.selected)
              ? scheme.onSurface
              : scheme.onSurfaceVariant,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerLowest,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: input(scheme.outlineVariant),
      enabledBorder: input(scheme.outlineVariant),
      focusedBorder: input(scheme.primary, 1.6),
      errorBorder: input(scheme.error),
      focusedErrorBorder: input(scheme.error, 1.6),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: scheme.surfaceContainerLowest,
      selectedColor: scheme.primaryContainer,
      side: border,
      shape: const StadiumBorder(),
      labelStyle: text.labelLarge?.copyWith(color: scheme.onSurface),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        backgroundColor: scheme.surfaceContainerLowest,
        selectedBackgroundColor: scheme.primaryContainer,
        selectedForegroundColor: scheme.onPrimaryContainer,
        side: border,
        visualDensity: VisualDensity.compact,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}

/// The gold headline card used at the top of a screen. Text inside should use
/// [Brand.ink].
class GoldCard extends StatelessWidget {
  const GoldCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: Brand.goldGradient,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Brand.gold.withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(padding: const EdgeInsets.all(22), child: child),
    );
  }
}

/// Small round label in front of a price row, e.g. the karat.
class AssetBadge extends StatelessWidget {
  const AssetBadge(this.text, {super.key, this.silver = false});

  final String text;
  final bool silver;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = silver ? DahabyColors.of(context).silver : scheme.primary;
    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        shape: BoxShape.circle,
      ),
      child: Text(
        text,
        textDirection: TextDirection.ltr,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
    );
  }
}
