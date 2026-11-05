import 'package:flutter/material.dart';

import '../services/sesion.dart';

/// Lleva al invitado a la pantalla de inicio de sesión (la raíz de la app).
void irAIniciarSesion(BuildContext context) {
  Navigator.of(context).popUntil((ruta) => ruta.isFirst);
  Sesion.instancia.salirDeInvitado();
}
