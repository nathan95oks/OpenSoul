import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const Color brandPrimary = Color(0xFF1A1A2E);
  static const Color brandElectric = Color(0xFF16213E);
  static const Color brandLight = Color(0xFF0F3460);
  static const Color brandDeep = Color(0xFF000B29);

  static const Color darkBg = Color(0xFF0A0E1A);
  static const Color darkSurface = Color(0xFF121A2E);
  static const Color darkElevated = Color(0xFF1B2640);
  static const Color darkBorder = Color(0xFF2A3656);
  static const Color darkText = Color(0xFFF1F5F9);
  static const Color darkTextSub = Color(0xFF94A3B8);

  // ---- Fondos blancos de los módulos --------------------------------------
  // Misma identidad (blanco, azul, violeta y azul muy oscuro), mejor repartida:
  // el blanco es el fondo y el azul muy oscuro, la tinta y las superficies de
  // contraste (tarjetas, input, navegación, panel de botones).

  /// Fondo principal de Audio/Texto→LSB, Conversation y LSB→Texto/Audio.
  static const Color pageBg = Color(0xFFFFFFFF);

  /// Texto sobre blanco: el azul muy oscuro de las superficies (≈17:1).
  static const Color ink = darkSurface;

  /// Texto secundario sobre blanco: la misma tinta al 70 % (≈6,6:1).
  static const Color inkSub = Color(0xB3121A2E);

  /// Bordes y separadores sobre blanco.
  static const Color lineOnWhite = Color(0x1F121A2E);

  /// Superficie apenas teñida para que las tarjetas se separen del fondo.
  static const Color surfaceOnWhite = Color(0xFFF4F7FB);

  /// Lienzos suaves que enlazan las superficies claras con la paleta actual.
  static const Color audioPageBg = Color(0xFFEEF4FF);
  static const Color conversationPageBg = Color(0xFFF5F1FF);
  static const Color framedSurface = Color(0xFFFCFDFF);

  // ---- Inputs sobre superficies claras ------------------------------------
  // El tema global sigue siendo oscuro por el avatar. Los editores del flujo
  // LSB viven sobre hojas claras y, por tanto, no deben heredar texto blanco.
  static const Color lightInputBg = pageBg;
  static const Color lightInputText = ink;
  static const Color lightInputHint = Color(0xFF586174);
  static const Color lightInputBorder = Color(0xFF7E8AA3);
  static const Color lightInputCursor = lsbVioletDeep;
  static const Color audioActionBlue = Color(0xFF2563EB);

  // El módulo LSB→Texto/Audio ya consumía estos tokens de forma centralizada.
  // Se conservan sus nombres para no dispersar cambios por todos sus widgets.
  static const Color lightBg = pageBg;
  static const Color lightSurface = surfaceOnWhite;
  static const Color lightSubtle = Color(0xFFE9EEF6);
  static const Color lightBorder = lineOnWhite;
  static const Color lightText = ink;
  static const Color lightTextSub = inkSub;
  static const Color accentSoft = surfaceOnWhite;

  // ---- Violeta de LSB ---------------------------------------------------------
  // El de las glosas (tarjeta elegida, vista previa): marca lo que viene de LSB.
  static const Color lsbViolet = Color(0xFF7C3AED);
  static const Color lsbVioletDeep = Color(0xFF660066);
  static const Color lsbVioletLight = Color(0xFFC084FC);

  // Tarjeta de glosa sin elegir: la versión suave del violeta de LSB, para
  // que se distinga del fondo blanco sin competir con la elegida (violeta
  // lleno). Antes era #F4F7FB sin borde y casi no se veía.
  static const Color glossCardBg = Color(0xFFF3EEFF);
  static const Color glossCardBorder = Color(0x387C3AED); // lsbViolet al 22 %

  // ---- Seña a incorporar -------------------------------------------------------
  // Una palabra sin seña en el catálogo: el azul del audio, no el violeta de
  // LSB, porque todavía no es una seña. Claro sobre la burbuja violeta.
  static const Color pendingSign = audioActionBlue;
  static const Color pendingSignOnDark = Color(0xFFBFDBFE);

  /// La pantalla amarilla que tapa al avatar mientras se lee qué es una
  /// palabra sin seña: un color que se distingue de inmediato de la seña.
  static const Color describeCurtain = Color(0xFFFFD43B);

  static InputDecoration lightInputDecoration({
    String? hintText,
    String? labelText,
    String? counterText,
    String? suffixText,
    TextStyle? suffixStyle,
    Widget? suffixIcon,
    EdgeInsetsGeometry? contentPadding,
    double radius = 14,
    Color? enabledBorderColor,
    double enabledBorderWidth = 1.5,
    Color? focusedBorderColor,
    double focusedBorderWidth = 2,
  }) {
    final enabled = enabledBorderColor ?? lightInputBorder;
    final focused = focusedBorderColor ?? lsbViolet;
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: lightInputHint),
      labelText: labelText,
      labelStyle: const TextStyle(color: lightInputHint),
      floatingLabelStyle: const TextStyle(
        color: lsbVioletDeep,
        fontWeight: FontWeight.w700,
      ),
      counterText: counterText,
      counterStyle: const TextStyle(color: lightInputHint),
      suffixText: suffixText,
      suffixStyle: suffixStyle,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: lightInputBg,
      contentPadding: contentPadding,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: BorderSide(color: enabled, width: enabledBorderWidth),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: BorderSide(color: enabled, width: enabledBorderWidth),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: BorderSide(color: focused, width: focusedBorderWidth),
      ),
    );
  }

  static const Color successLight = Color(0xFF10B981);
  static const Color successDark = Color(0xFF34D399);
  static const Color warningLight = Color(0xFFF59E0B);
  static const Color warningDark = Color(0xFFFBBF24);
  static const Color errorLight = Color(0xFFEF4444);
  static const Color errorDark = Color(0xFFF87171);

  static const double radiusButton = 12;
  static const double radiusCard = 16;

  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: brandPrimary.withValues(alpha: 0.08),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  static const String _fontFamily = 'Roboto';

  static TextTheme _textTheme(Color primary, Color secondary) => TextTheme(
    displaySmall: TextStyle(
      fontSize: 32,
      fontWeight: FontWeight.w700,
      height: 1.2,
      color: primary,
    ),
    headlineMedium: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w700,
      height: 1.3,
      color: primary,
    ),
    titleLarge: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      height: 1.3,
      color: primary,
    ),
    bodyLarge: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w400,
      height: 1.5,
      color: primary,
    ),
    bodyMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      height: 1.5,
      color: primary,
    ),
    bodySmall: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      height: 1.4,
      color: secondary,
    ),
    labelLarge: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: primary,
    ),
  );

  static ThemeData get lightTheme => darkTheme;

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
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          color: darkText,
        ),
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusButton),
          ),
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
      // La barra inferior usaba azul sobre azul. El violeta claro identifica
      // la pestaña activa y el peso tipográfico mantiene el estado perceptible
      // incluso sin depender únicamente del color.
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: darkSurface,
        selectedItemColor: lsbVioletLight,
        unselectedItemColor: darkTextSub,
        selectedLabelStyle: TextStyle(fontWeight: FontWeight.w800),
        unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w500),
      ),
    );
  }

  static ElevatedButtonThemeData _elevatedButton() => ElevatedButtonThemeData(
    style:
        ElevatedButton.styleFrom(
          backgroundColor: brandPrimary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFF94A3B8),
          disabledForegroundColor: Colors.white70,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusButton),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ).copyWith(
          overlayColor: WidgetStateProperty.all(
            brandDeep.withValues(alpha: 0.2),
          ),
        ),
  );
}
