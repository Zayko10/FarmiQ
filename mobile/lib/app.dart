import 'package:flutter/material.dart';

import 'screens/shell_screen.dart';
import 'theme/app_theme.dart';

class FarmiQApp extends StatelessWidget {
  /// [tema] solo se usa en las pruebas, para no descargar la tipografía.
  const FarmiQApp({super.key, this.tema});

  final ThemeData? tema;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FarmiQ',
      debugShowCheckedModeBanner: false,
      theme: tema ?? construirTema(),
      home: const ShellScreen(),
    );
  }
}
