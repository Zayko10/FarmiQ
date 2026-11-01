import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Colores tomados del logotipo de FarmiQ.
class AppColors {
  AppColors._();

  static const Color azul = Color(0xFF045289);
  static const Color verde = Color(0xFF159B69);
  static const Color fondo = Color(0xFFF6F8FA);
  static const Color texto = Color(0xFF1F2933);
  static const Color textoSuave = Color(0xFF5F6B7A);
  static const Color borde = Color(0xFFE1E6EB);
  static const Color alerta = Color(0xFFC0392B);
}

/// Borde redondeado de los campos de texto.
OutlineInputBorder bordeRedondeado({Color color = AppColors.borde, double ancho = 1}) {
  return OutlineInputBorder(
    borderRadius: BorderRadius.circular(28),
    borderSide: BorderSide(color: color, width: ancho),
  );
}

// Google Sans Flex es la tipografía que usa Google en sus productos.
// Si el paquete no la incluye, se usa Outfit, que es muy parecida.
const String _fuentePrincipal = 'Google Sans Flex';
const String _fuenteRespaldo = 'Outfit';

String _elegirFuente() {
  try {
    GoogleFonts.getFont(_fuentePrincipal);
    return _fuentePrincipal;
  } catch (_) {
    return _fuenteRespaldo;
  }
}

// Se aplica la fuente estilo por estilo (en lugar de GoogleFonts.getTextTheme)
// para no mezclar el TextTheme de Flutter con el del paquete material_ui.
TextTheme _textTheme(TextTheme base) {
  final familia = _elegirFuente();

  TextStyle? aplicar(TextStyle? estilo) {
    if (estilo == null) return null;
    return GoogleFonts.getFont(familia, textStyle: estilo);
  }

  return base.copyWith(
    displayLarge: aplicar(base.displayLarge),
    displayMedium: aplicar(base.displayMedium),
    displaySmall: aplicar(base.displaySmall),
    headlineLarge: aplicar(base.headlineLarge),
    headlineMedium: aplicar(base.headlineMedium),
    headlineSmall: aplicar(base.headlineSmall),
    titleLarge: aplicar(base.titleLarge),
    titleMedium: aplicar(base.titleMedium),
    titleSmall: aplicar(base.titleSmall),
    bodyLarge: aplicar(base.bodyLarge),
    bodyMedium: aplicar(base.bodyMedium),
    bodySmall: aplicar(base.bodySmall),
    labelLarge: aplicar(base.labelLarge),
    labelMedium: aplicar(base.labelMedium),
    labelSmall: aplicar(base.labelSmall),
  );
}

ThemeData construirTema() {
  final esquema = ColorScheme.fromSeed(seedColor: AppColors.azul).copyWith(
    primary: AppColors.azul,
    onPrimary: Colors.white,
    secondary: AppColors.verde,
    onSecondary: Colors.white,
    surface: Colors.white,
    error: AppColors.alerta,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: esquema);
  final textos = _textTheme(base.textTheme).apply(
    bodyColor: AppColors.texto,
    displayColor: AppColors.texto,
  );

  return base.copyWith(
    scaffoldBackgroundColor: AppColors.fondo,
    textTheme: textos,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: AppColors.azul,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: textos.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
        color: AppColors.azul,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppColors.azul.withValues(alpha: 0.12),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.white,
      selectedColor: AppColors.azul.withValues(alpha: 0.12),
      checkmarkColor: AppColors.azul,
      side: const BorderSide(color: AppColors.borde),
      shape: const StadiumBorder(),
      labelStyle: textos.labelLarge,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.azul,
        foregroundColor: Colors.white,
        minimumSize: const Size(64, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    ),
  );
}
