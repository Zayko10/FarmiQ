import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/comunes.dart';

/// HU01: registro de cliente.
class RegistroScreen extends StatefulWidget {
  const RegistroScreen({super.key});

  @override
  State<RegistroScreen> createState() => _RegistroScreenState();
}

class _RegistroScreenState extends State<RegistroScreen> {
  final _nombre = TextEditingController();
  final _email = TextEditingController();
  final _telefono = TextEditingController();
  final _password = TextEditingController();
  final _servicio = AuthService();

  bool _acepta = false;
  bool _verPassword = false;
  bool _cargando = false;
  String? _error;

  @override
  void dispose() {
    _nombre.dispose();
    _email.dispose();
    _telefono.dispose();
    _password.dispose();
    super.dispose();
  }

  InputDecoration _campo(String etiqueta, IconData icono, {Widget? sufijo}) => InputDecoration(
        labelText: etiqueta,
        prefixIcon: Icon(icono),
        suffixIcon: sufijo,
        filled: true,
        fillColor: Colors.white,
        border: bordeRedondeado(),
        enabledBorder: bordeRedondeado(),
      );

  Future<void> _registrar() async {
    if (_nombre.text.trim().length < 2) {
      setState(() => _error = 'Escribe tu nombre.');
      return;
    }
    if (!_email.text.contains('@')) {
      setState(() => _error = 'Escribe un correo válido.');
      return;
    }
    if (_password.text.length < 8) {
      setState(() => _error = 'La contraseña debe tener al menos 8 caracteres.');
      return;
    }
    if (!_acepta) {
      setState(() => _error = 'Debes aceptar los términos y condiciones.');
      return;
    }

    final navegador = Navigator.of(context);
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      await _servicio.registrar(
        nombre: _nombre.text,
        email: _email.text,
        password: _password.text,
        telefono: _telefono.text,
      );
      // Se inicia sesión de inmediato con la cuenta recién creada
      await _servicio.login(_email.text, _password.text);
      if (mounted) navegador.popUntil((ruta) => ruta.isFirst);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = e.mensaje;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crear cuenta')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _nombre,
                    textCapitalization: TextCapitalization.words,
                    decoration: _campo('Nombre completo', Icons.person_outline),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    decoration: _campo('Correo electrónico', Icons.mail_outline),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _telefono,
                    keyboardType: TextInputType.phone,
                    maxLength: 9,
                    decoration: _campo('Celular (opcional)', Icons.phone_outlined).copyWith(counterText: ''),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _password,
                    obscureText: !_verPassword,
                    decoration: _campo(
                      'Contraseña (mínimo 8 caracteres)',
                      Icons.lock_outline,
                      sufijo: IconButton(
                        icon: Icon(_verPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                        onPressed: () => setState(() => _verPassword = !_verPassword),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _acepta,
                    onChanged: (v) => setState(() => _acepta = v ?? false),
                    title: const Text('Acepto los términos y condiciones'),
                  ),
                  if (_error != null) ...[
                    Aviso(_error!),
                    const SizedBox(height: 12),
                  ],
                  FilledButton(
                    onPressed: _cargando ? null : _registrar,
                    child: _cargando
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                          )
                        : const Text('Crear cuenta'),
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
