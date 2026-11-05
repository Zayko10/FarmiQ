import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/login_form.dart';

/// Acceso del personal de botica: otra apariencia (verde petróleo y ámbar) para distinguirlo del cliente.
class LoginPersonalScreen extends StatelessWidget {
  const LoginPersonalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    final temaFormulario = base.copyWith(
      colorScheme: base.colorScheme.copyWith(primary: ColoresPersonal.primario),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ColoresPersonal.primario,
          foregroundColor: Colors.white,
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
      ),
    );

    return Scaffold(
      backgroundColor: ColoresPersonal.primario,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Volver'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.storefront_outlined, color: ColoresPersonal.acento, size: 56),
                  const SizedBox(height: 14),
                  Text(
                    'Acceso para personal de botica',
                    textAlign: TextAlign.center,
                    style: base.textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Actualiza el stock y los precios de tu botica y entrega las reservas.',
                    textAlign: TextAlign.center,
                    style: base.textTheme.bodyMedium?.copyWith(color: Colors.white70),
                  ),
                  const SizedBox(height: 24),
                  Theme(
                    data: temaFormulario,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: ColoresPersonal.fondo,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const LoginForm(personal: true),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '¿Olvidaste tu contraseña? Pide a tu administrador que la restablezca.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
