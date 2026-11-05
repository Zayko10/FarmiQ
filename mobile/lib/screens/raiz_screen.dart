import 'package:flutter/material.dart';

import '../services/sesion.dart';
import '../widgets/logo_farmiq.dart';
import 'login_screen.dart';
import 'personal/personal_shell.dart';
import 'shell_screen.dart';

/// Decide qué ve la persona al abrir la app:
/// - sin sesión: el inicio de sesión de clientes (con acceso discreto para el personal),
/// - cliente o invitado: la app del cliente,
/// - personal de botica: su propio panel.
class RaizScreen extends StatefulWidget {
  const RaizScreen({super.key});

  @override
  State<RaizScreen> createState() => _RaizScreenState();
}

class _RaizScreenState extends State<RaizScreen> {
  @override
  void initState() {
    super.initState();
    if (!Sesion.instancia.cargada) {
      Sesion.instancia.cargar();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Sesion.instancia,
      builder: (context, _) {
        final sesion = Sesion.instancia;
        if (!sesion.cargada) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LogoFarmiq(alto: 40),
                  SizedBox(height: 24),
                  CircularProgressIndicator(),
                ],
              ),
            ),
          );
        }
        if (sesion.esPersonal) return const PersonalShell();
        if (sesion.autenticado || sesion.esInvitado) return const ShellScreen();
        return const LoginScreen();
      },
    );
  }
}
