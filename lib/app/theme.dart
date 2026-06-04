import 'package:flutter/material.dart';

/// Tema visual de OpenSoul — paleta minimalista blanco / negro / naranja.
///
/// Tres colores únicos: #FFFFFF · #000000 · #FF6B00.
/// La jerarquía visual se construye mediante tamaño, peso tipográfico,
/// espaciado, sombras sutiles y posición — no mediante colores adicionales.
class AppTheme {
  // Paleta estricta de 3 colores
  static const Color background   = Color(0xFF000000); // negro puro
  static const Color surface      = Color(0xFF0A0A0A); // negro profundo
  static const Color surfaceLight = Color(0xFF141414); // gris carbón
  static const Color accent       = Color(0xFFFF6B00); // naranja #FF6B00
  static const Color accentSoft   = Color(0xFFFF6B00); // alias — mismo naranja
  static const Color textPrimary  = Color(0xFFFFFFFF); // blanco
  static const Color textSecondary= Color(0x99FFFFFF); // blanco 60 %
  static const Color border       = Color(0xFF1C1C1C); // borde sutil

  // Compatibilidad: alias que apuntan a la nueva paleta
  static const Color teal    = accent;
  static const Color success = accent;
  static const Color danger  = accent;
  static const Color orange  = accent;

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: accent,
      colorScheme: const ColorScheme.dark(
        primary: accent,
        secondary: accent,
        surface: surface,
        error: accent,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: 0.5,
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceLight,
        selectedColor: accent,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: const BorderSide(color: border),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.black,
          disabledBackgroundColor: surfaceLight,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.5),
        ),
      ),
      fontFamily: 'Roboto',
    );
  }
}
