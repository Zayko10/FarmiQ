import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/comunes.dart';

/// HU13: recuperar contraseña en dos pasos (pedir el código y escribir la contraseña nueva).
class RecuperarScreen extends StatefulWidget {
  const RecuperarScreen({super.key});

  @override
  State<RecuperarScreen> createState() => _RecuperarScreenState();
}

class _RecuperarScreenState extends State<RecuperarScreen> {
  final _email = TextEditingController();
  final _codigo = TextEditingController();
  final _password = TextEditingController();
  final _servicio = AuthService();

  bool _paso2 = false;
  bool _cargando = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _email.dispose();
    _codigo.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _pedirCodigo() async {
    if (!_email.text.contains('@')) {
      setState(() => _error = 'Escribe un correo válido.');
      return;
    }
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final mensaje = await _servicio.olvidePassword(_email.text);
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _paso2 = true;
        _info = mensaje;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = e.mensaje;
      });
    }
  }

  Future<void> _restablecer() async {
    if (_codigo.text.trim().isEmpty) {
      setState(() => _error = 'Pega el código que recibiste por correo.');
      return;
    }
    if (_password.text.length < 8) {
      setState(() => _error = 'La contraseña debe tener al menos 8 caracteres.');
      return;
    }
    final navegador = Navigator.of(context);
    final mensajero = ScaffoldMessenger.of(context);
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final mensaje = await _servicio.restablecerPassword(_codigo.text, _password.text);
      mensajero.showSnackBar(SnackBar(content: Text(mensaje)));
      if (mounted) navegador.pop();
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
      appBar: AppBar(title: const Text('Recuperar contraseña')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _paso2
                        ? 'Escribe el código que te enviamos y tu nueva contraseña.'
                        : 'Escribe tu correo y te enviaremos un código para crear una contraseña nueva.',
                    style: const TextStyle(color: AppColors.textoSuave),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _email,
                    enabled: !_paso2 && !_cargando,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    decoration: InputDecoration(
                      labelText: 'Correo electrónico',
                      prefixIcon: const Icon(Icons.mail_outline),
                      filled: true,
                      fillColor: Colors.white,
                      border: bordeRedondeado(),
                      enabledBorder: bordeRedondeado(),
                    ),
                  ),
                  if (_paso2) ...[
                    const SizedBox(height: 12),
                    if (_info != null) Aviso(_info!, color: AppColors.verde, icono: Icons.mark_email_read_outlined),
                    const SizedBox(height: 4),
                    const Text(
                      'En desarrollo el correo se imprime en la consola de la API: docker compose logs -f api',
                      style: TextStyle(fontSize: 12, color: AppColors.textoSuave),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _codigo,
                      autocorrect: false,
                      decoration: InputDecoration(
                        labelText: 'Código de recuperación',
                        prefixIcon: const Icon(Icons.key_outlined),
                        filled: true,
                        fillColor: Colors.white,
                        border: bordeRedondeado(),
                        enabledBorder: bordeRedondeado(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _password,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Nueva contraseña (mínimo 8 caracteres)',
                        prefixIcon: const Icon(Icons.lock_outline),
                        filled: true,
                        fillColor: Colors.white,
                        border: bordeRedondeado(),
                        enabledBorder: bordeRedondeado(),
                      ),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Aviso(_error!),
                  ],
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: _cargando ? null : (_paso2 ? _restablecer : _pedirCodigo),
                    child: _cargando
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                          )
                        : Text(_paso2 ? 'Cambiar contraseña' : 'Enviar código'),
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
