import 'package:flutter/material.dart';

import '../services/sesion.dart';
import '../theme/app_theme.dart';
import '../widgets/comunes.dart';
import '../widgets/login_form.dart';
import '../widgets/logo_farmiq.dart';
import 'login_personal_screen.dart';
import 'recuperar_screen.dart';
import 'registro_screen.dart';

/// Pantalla de inicio: login de clientes como acceso principal.
/// El acceso del personal de botica está al final, en letra discreta pero visible.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final bool _sesionVencio = Sesion.instancia.consumirAvisoExpiracion();

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: LogoFarmiq(alto: 44)),
                  const SizedBox(height: 28),
                  Text(
                    'Bienvenido',
                    style: textos.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Inicia sesión para reservar tus medicamentos y guardar tus favoritos.',
                    style: textos.bodyMedium?.copyWith(color: AppColors.textoSuave),
                  ),
                  if (_sesionVencio) ...[
                    const SizedBox(height: 14),
                    const Aviso(
                      'Tu sesión venció. Vuelve a iniciar sesión.',
                      color: AppColors.azul,
                      icono: Icons.info_outline,
                    ),
                  ],
                  const SizedBox(height: 22),
                  const LoginForm(personal: false),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => const RecuperarScreen()),
                      ),
                      child: const Text('¿Olvidaste tu contraseña?'),
                    ),
                  ),
                  const SizedBox(height: 4),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(64, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const RegistroScreen()),
                    ),
                    child: const Text('Crear una cuenta'),
                  ),
                  TextButton(
                    onPressed: Sesion.instancia.entrarComoInvitado,
                    child: const Text('Continuar como invitado'),
                  ),
                  const SizedBox(height: 28),
                  // Acceso discreto para el personal de las boticas
                  Center(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => const LoginPersonalScreen()),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Text(
                          '¿Trabajas en una botica? Acceso para personal',
                          style: textos.bodySmall?.copyWith(
                            color: AppColors.textoSuave.withValues(alpha: 0.75),
                            fontSize: 12,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
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
