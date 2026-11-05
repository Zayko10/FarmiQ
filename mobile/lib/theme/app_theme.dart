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

/// Colores de la interfaz del personal de botica (distinta a la del cliente).
class ColoresPersonal {
  ColoresPersonal._();

  static const Color primario = Color(0xFF0E5E5A);
  static const Color acento = Color(0xFFE9A23B);
  static const Color fondo = Color(0xFFEEF3F2);
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
  return _armarTema(esquema, fondo: AppColors.fondo, appBarOscuro: false);
}

/// Tema de la interfaz del personal: verde petróleo con acento ámbar y barra superior oscura.
ThemeData construirTemaPersonal() {
  final esquema = ColorScheme.fromSeed(seedColor: ColoresPersonal.primario).copyWith(
    primary: ColoresPersonal.primario,
    onPrimary: Colors.white,
    secondary: ColoresPersonal.acento,
    onSecondary: Colors.black,
    surface: Colors.white,
    error: AppColors.alerta,
  );
  return _armarTema(esquema, fondo: ColoresPersonal.fondo, appBarOscuro: true);
}

ThemeData _armarTema(ColorScheme esquema, {required Color fondo, required bool appBarOscuro}) {
  final base = ThemeData(useMaterial3: true, colorScheme: esquema);
  final textos = _textTheme(base.textTheme).apply(
    bodyColor: AppColors.texto,
    displayColor: AppColors.texto,
  );
  final colorBarra = appBarOscuro ? esquema.primary : Colors.white;
  final colorTextoBarra = appBarOscuro ? Colors.white : esquema.primary;

  return base.copyWith(
    scaffoldBackgroundColor: fondo,
    textTheme: textos,
    appBarTheme: AppBarTheme(
      backgroundColor: colorBarra,
      foregroundColor: colorTextoBarra,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: textos.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
        color: colorTextoBarra,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      indicatorColor: esquema.primary.withValues(alpha: 0.12),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.white,
      selectedColor: esquema.primary.withValues(alpha: 0.12),
      checkmarkColor: esquema.primary,
      side: const BorderSide(color: AppColors.borde),
      shape: const StadiumBorder(),
      labelStyle: textos.labelLarge,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: esquema.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(64, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    ),
  );
}
