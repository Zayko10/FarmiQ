import 'package:flutter/material.dart';

import '../widgets/estado_vacio.dart';

/// Pantalla provisional de las secciones que se construyen en los siguientes pasos.
class ProximamenteScreen extends StatelessWidget {
  const ProximamenteScreen({
    super.key,
    required this.titulo,
    required this.icono,
    required this.mensaje,
  });

  final String titulo;
  final IconData icono;
  final String mensaje;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(titulo)),
      body: EstadoVacio(icono: icono, titulo: 'Próximamente', mensaje: mensaje),
    );
  }
}
