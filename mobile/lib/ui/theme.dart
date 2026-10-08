import 'package:flutter/material.dart';

/// Colours from the web app's `themes.css`.
class AuxColors extends ThemeExtension<AuxColors> {
  const AuxColors({
    required this.background,
    required this.backgroundHighlight,
    required this.text,
    required this.primary,
    required this.decorative,
  });

  static const dark = AuxColors(
    background: Color(0xFF232323),
    backgroundHighlight: Color(0xFF2F2F2F),
    text: Color(0xFFE8E8E8),
    primary: Color(0xFFA3B5AE),
    decorative: Color(0xFF808080),
  );

  static const light = AuxColors(
    background: Color(0xFFD1D1D1),
    backgroundHighlight: Color(0xFFE8E8E8),
    text: Color(0xFF1A1A1A),
    primary: Color(0xFF2D4739),
    decorative: Color(0xFF505050),
  );

  final Color background;
  final Color backgroundHighlight;
  final Color text;
  final Color primary;
  final Color decorative;

  static AuxColors of(BuildContext context) =>
      Theme.of(context).extension<AuxColors>()!;

  @override
  AuxColors copyWith() => this;

  @override
  AuxColors lerp(AuxColors? other, double t) =>
      t < 0.5 ? this : (other ?? this);
}

ThemeData buildTheme(bool dark) {
  final c = dark ? AuxColors.dark : AuxColors.light;
  final base = dark ? ThemeData.dark() : ThemeData.light();
  return base.copyWith(
    scaffoldBackgroundColor: c.background,
    colorScheme: base.colorScheme.copyWith(
      surface: c.background,
      onSurface: c.text,
      primary: c.primary,
      onPrimary: c.background,
      outline: c.decorative,
    ),
    textTheme: base.textTheme.apply(
      fontFamily: 'IBMPlexMono',
      bodyColor: c.text,
      displayColor: c.text,
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: c.primary,
      inactiveTrackColor: c.decorative,
      thumbColor: c.primary,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.background,
      shape: const RoundedRectangleBorder(),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: c.backgroundHighlight,
      contentTextStyle: TextStyle(fontFamily: 'IBMPlexMono', color: c.text),
    ),
    dividerColor: c.decorative,
    extensions: [c],
  );
}
