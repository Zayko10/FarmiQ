import 'package:flutter/material.dart';

import 'screens/raiz_screen.dart';
import 'services/sesion.dart';
import 'theme/app_theme.dart';

ThemeData? _temaCliente;
ThemeData? _temaPersonal;

class FarmiQApp extends StatelessWidget {
  /// [tema] solo se usa en las pruebas, para no descargar la tipografía.
  const FarmiQApp({super.key, this.tema});

  final ThemeData? tema;

  @override
  Widget build(BuildContext context) {
    // El tema cambia solo según quién inició sesión: el personal ve otra interfaz gráfica.
    return ListenableBuilder(
      listenable: Sesion.instancia,
      builder: (context, _) {
        final personal = Sesion.instancia.esPersonal;
        final ThemeData temaActual = tema ??
            (personal
                ? (_temaPersonal ??= construirTemaPersonal())
                : (_temaCliente ??= construirTema()));
        return MaterialApp(
          title: 'FarmiQ',
          debugShowCheckedModeBanner: false,
          theme: temaActual,
          home: const RaizScreen(),
        );
      },
    );
  }
}
