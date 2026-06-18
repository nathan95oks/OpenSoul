import 'package:flutter/material.dart';

/// OpenSoul LSB Design System.
///
/// Sistema de diseño unificado para los dos módulos de la app:
///   • Módulo AUDIO/TEXTO → LSB  -> [AppTheme.darkTheme]  (visualización del avatar 3D)
///   • Módulo LSB → TEXTO/AUDIO  -> [AppTheme.lightTheme] (interacción con tarjetas)
///
/// El "ADN" compartido (azul de marca, tipografía, radios y espaciado) es
/// idéntico en ambos temas. Solo cambian las superficies (fondos) y la forma
/// de expresar elevación (sombras suaves en light vs. glow/elevación por color
/// en dark). Esto garantiza coherencia y evita el desbalance de colores.
class AppTheme {
  AppTheme._();

  // ===========================================================================
  // 1. COLORES DE MARCA (compartidos — el puente entre ambos módulos)
  // ===========================================================================
  static const Color brandPrimary  = Color(0xFF2563EB); // azul primario
  static const Color brandElectric = Color(0xFF3B82F6); // azul eléctrico / acento
  static const Color brandLight    = Color(0xFF60A5FA); // acento sobre dark / glow
  static const Color brandDeep     = Color(0xFF1D4ED8); // hover / pressed

  // ===========================================================================
  // 2. SUPERFICIES POR TEMA
  // ===========================================================================
  // --- Dark (Módulo Audio/Texto → LSB) ---
  static const Color darkBg        = Color(0xFF0A0E1A); // azul casi negro
  static const Color darkSurface   = Color(0xFF121A2E); // panel / contenedor avatar
  static const Color darkElevated  = Color(0xFF1B2640); // tarjetas / controles
  static const Color darkBorder    = Color(0xFF2A3656);
  static const Color darkText      = Color(0xFFF1F5F9);
  static const Color darkTextSub   = Color(0xFF94A3B8);

  // --- Light (Módulo LSB → Texto/Audio) ---
  static const Color lightBg       = Color(0xFFF5F8FF); // blanco con tinte azul
  static const Color lightSurface  = Color(0xFFFFFFFF); // tarjetas de glosas
  static const Color lightSubtle   = Color(0xFFEAF1FF); // chips / hover de cards
  static const Color lightBorder   = Color(0xFFD6E2F5);
  static const Color lightText     = Color(0xFF0F172A);
  static const Color lightTextSub  = Color(0xFF475569);
  static const Color accentSoft    = Color(0xFFDBEAFE); // fondo de glosa seleccionada

  // ===========================================================================
  // 3. COLORES SEMÁNTICOS (ajustados por tema)
  // ===========================================================================
  static const Color successLight = Color(0xFF10B981);
  static const Color successDark  = Color(0xFF34D399);
  static const Color warningLight = Color(0xFFF59E0B);
  static const Color warningDark  = Color(0xFFFBBF24);
  static const Color errorLight   = Color(0xFFEF4444);
  static const Color errorDark    = Color(0xFFF87171);

  // ===========================================================================
  // 4. TOKENS COMPARTIDOS (radios, sombra de marca)
  // ===========================================================================
  static const double radiusButton = 12;
  static const double radiusCard   = 16;

  /// Sombra suave teñida de azul para las tarjetas del módulo light.
  /// Integra la card con la marca en lugar de usar un gris neutro.
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: brandPrimary.withValues(alpha: 0.08),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];

  // ===========================================================================
  // 5. TIPOGRAFÍA (escala idéntica en ambos temas)
  // ===========================================================================
  // 'Inter' es la familia recomendada; si no está empaquetada se usa el
  // fallback nativo (Roboto en Android / SF Pro en iOS).
  static const String _fontFamily = 'Roboto';

  static TextTheme _textTheme(Color primary, Color secondary) => TextTheme(
        displaySmall: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, height: 1.2, color: primary),
        headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, height: 1.3, color: primary),
        titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, height: 1.3, color: primary),
        bodyLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w400, height: 1.5, color: primary),
        bodyMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, height: 1.5, color: primary),
        bodySmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, height: 1.4, color: secondary),
        labelLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: primary),
      );

  // ===========================================================================
  // 6. TEMA LIGHT — Módulo LSB → Texto/Audio
  // ===========================================================================
  static ThemeData get lightTheme {
    final textTheme = _textTheme(lightText, lightTextSub);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBg,
      primaryColor: brandPrimary,
      fontFamily: _fontFamily,
      textTheme: textTheme,
      colorScheme: const ColorScheme.light(
        primary: brandPrimary,
        onPrimary: Colors.white,
        secondary: brandElectric,
        onSecondary: Colors.white,
        surface: lightSurface,
        onSurface: lightText,
        surfaceContainerHighest: lightSubtle,
        outline: lightBorder,
        error: errorLight,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: lightBg,
        elevation: 0,
        centerTitle: false,
        foregroundColor: lightText,
        titleTextStyle: textTheme.titleLarge,
        shape: const Border(bottom: BorderSide(color: lightBorder, width: 1)),
      ),
      cardTheme: CardThemeData(
        color: lightSurface,
        elevation: 0,
        shadowColor: brandPrimary.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
          side: const BorderSide(color: lightBorder),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: lightSurface,
        selectedColor: accentSoft,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, color: lightText),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusButton),
          side: const BorderSide(color: lightBorder),
        ),
        side: const BorderSide(color: lightBorder),
      ),
      elevatedButtonTheme: _elevatedButton(),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: brandPrimary,
          minimumSize: const Size(0, 48),
          side: const BorderSide(color: brandPrimary, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusButton)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: lightTextSub),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: brandPrimary,
        foregroundColor: Colors.white,
      ),
    );
  }

  // ===========================================================================
  // 7. TEMA DARK — Módulo Audio/Texto → LSB
  // ===========================================================================
  static ThemeData get darkTheme {
    final textTheme = _textTheme(darkText, darkTextSub);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBg,
      primaryColor: brandElectric,
      fontFamily: _fontFamily,
      textTheme: textTheme,
      colorScheme: const ColorScheme.dark(
        primary: brandElectric,
        onPrimary: Colors.white,
        secondary: brandLight,
        onSecondary: Color(0xFF0A0E1A),
        surface: darkSurface,
        onSurface: darkText,
        surfaceContainerHighest: darkElevated,
        outline: darkBorder,
        error: errorDark,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        foregroundColor: darkText,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: darkElevated,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
          side: const BorderSide(color: darkBorder),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: darkElevated,
        selectedColor: brandElectric,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, color: darkText),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusButton),
          side: const BorderSide(color: darkBorder),
        ),
        side: const BorderSide(color: darkBorder),
      ),
      elevatedButtonTheme: _elevatedButton(),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: brandLight,
          minimumSize: const Size(0, 48),
          side: const BorderSide(color: brandElectric, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusButton)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: darkTextSub),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: brandElectric,
        foregroundColor: Colors.white,
      ),
    );
  }

  /// Botón primario compartido — mismo color e geometría en ambos temas.
  static ElevatedButtonThemeData _elevatedButton() => ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: brandPrimary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFF94A3B8),
          disabledForegroundColor: Colors.white70,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusButton)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.5),
        ).copyWith(
          overlayColor: WidgetStateProperty.all(brandDeep.withValues(alpha: 0.2)),
        ),
      );
}
