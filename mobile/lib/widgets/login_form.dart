import 'dart:async';

import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../utils/formato.dart';
import 'comunes.dart';

/// Formulario de inicio de sesión. Lo usan el login de clientes y el de personal de botica.
/// Maneja el bloqueo temporal: tras 5 contraseñas incorrectas la API bloquea el correo y
/// aquí se muestra la cuenta regresiva.
class LoginForm extends StatefulWidget {
  const LoginForm({super.key, required this.personal, this.servicio});

  final bool personal;
  final AuthService? servicio;

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  late final AuthService _servicio = widget.servicio ?? AuthService();

  bool _verPassword = false;
  bool _cargando = false;
  String? _error;
  int _segundosBloqueo = 0;
  Timer? _reloj;

  bool get _bloqueado => _segundosBloqueo > 0;

  @override
  void dispose() {
    _reloj?.cancel();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _iniciarBloqueo(int segundos) {
    _reloj?.cancel();
    setState(() {
      _segundosBloqueo = segundos;
      _error = null;
    });
    _reloj = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _segundosBloqueo--);
      if (_segundosBloqueo <= 0) t.cancel();
    });
  }

  Future<void> _enviar() async {
    if (_bloqueado || _cargando) return;

    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Escribe tu correo y tu contraseña.');
      return;
    }

    final navegador = Navigator.of(context);
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      if (widget.personal) {
        await _servicio.loginPersonal(email, password);
      } else {
        await _servicio.login(email, password);
      }
      // Si el login se abrió encima de la pantalla raíz (acceso del personal), se cierra
      if (mounted) navegador.popUntil((ruta) => ruta.isFirst);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.bloqueado) {
        _iniciarBloqueo(entero(e.datos['segundos_restantes'], 60));
        setState(() => _cargando = false);
        return;
      }
      final restantes = e.datos['intentos_restantes'];
      setState(() {
        _cargando = false;
        _error = restantes is num && e.codigo == 401
            ? '${e.mensaje}. Te ${restantes == 1 ? 'queda 1 intento' : 'quedan $restantes intentos'} antes del bloqueo temporal.'
            : e.mensaje;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _email,
          enabled: !_cargando,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: 'Correo electrónico',
            prefixIcon: const Icon(Icons.mail_outline),
            filled: true,
            fillColor: Colors.white,
            border: bordeRedondeado(),
            enabledBorder: bordeRedondeado(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _password,
          enabled: !_cargando,
          obscureText: !_verPassword,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _enviar(),
          decoration: InputDecoration(
            labelText: 'Contraseña',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              tooltip: _verPassword ? 'Ocultar contraseña' : 'Mostrar contraseña',
              icon: Icon(_verPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
              onPressed: () => setState(() => _verPassword = !_verPassword),
            ),
            filled: true,
            fillColor: Colors.white,
            border: bordeRedondeado(),
            enabledBorder: bordeRedondeado(),
          ),
        ),
        if (_bloqueado) ...[
          const SizedBox(height: 14),
          Aviso(
            'Por seguridad bloqueamos el acceso temporalmente por varios intentos fallidos. '
            'Vuelve a intentarlo en ${mmss(_segundosBloqueo)}.',
            color: AppColors.alerta,
            icono: Icons.lock_clock,
          ),
        ] else if (_error != null) ...[
          const SizedBox(height: 14),
          Aviso(_error!),
        ],
        const SizedBox(height: 18),
        FilledButton(
          onPressed: (_cargando || _bloqueado) ? null : _enviar,
          child: _cargando
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                )
              : Text(_bloqueado ? 'Bloqueado ${mmss(_segundosBloqueo)}' : 'Iniciar sesión'),
        ),
      ],
    );
  }
}
