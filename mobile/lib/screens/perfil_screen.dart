import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/sesion.dart';
import '../theme/app_theme.dart';
import '../widgets/comunes.dart';

/// HU14: edición de perfil.
class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  late final TextEditingController _nombre;
  late final TextEditingController _telefono;
  late final TextEditingController _direccion;
  final _servicio = AuthService();

  bool _cargando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final u = Sesion.instancia.usuario;
    _nombre = TextEditingController(text: u?.nombre ?? '');
    _telefono = TextEditingController(text: u?.telefono ?? '');
    _direccion = TextEditingController(text: u?.direccion ?? '');
    _refrescar();
  }

  // Trae los datos más recientes (la dirección no viaja en el inicio de sesión)
  Future<void> _refrescar() async {
    try {
      final u = await _servicio.obtenerPerfil();
      if (!mounted) return;
      _nombre.text = u.nombre;
      _telefono.text = u.telefono ?? '';
      _direccion.text = u.direccion ?? '';
    } on ApiException {
      // Se muestran los datos guardados en el dispositivo
    }
  }

  @override
  void dispose() {
    _nombre.dispose();
    _telefono.dispose();
    _direccion.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final navegador = Navigator.of(context);
    final mensajero = ScaffoldMessenger.of(context);
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      await _servicio.actualizarPerfil(
        nombre: _nombre.text,
        telefono: _telefono.text,
        direccion: _direccion.text,
      );
      mensajero.showSnackBar(const SnackBar(content: Text('Perfil actualizado')));
      if (mounted) navegador.pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = e.mensaje;
      });
    }
  }

  InputDecoration _campo(String etiqueta, IconData icono) => InputDecoration(
        labelText: etiqueta,
        prefixIcon: Icon(icono),
        filled: true,
        fillColor: Colors.white,
        border: bordeRedondeado(),
        enabledBorder: bordeRedondeado(),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Editar perfil')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(controller: _nombre, decoration: _campo('Nombre completo', Icons.person_outline)),
          const SizedBox(height: 12),
          TextField(
            controller: _telefono,
            keyboardType: TextInputType.phone,
            maxLength: 9,
            decoration: _campo('Celular (9 dígitos)', Icons.phone_outlined).copyWith(counterText: ''),
          ),
          const SizedBox(height: 12),
          TextField(controller: _direccion, decoration: _campo('Dirección', Icons.home_outlined)),
          const SizedBox(height: 8),
          Text(
            'Tu correo (${Sesion.instancia.usuario?.email ?? ''}) no se puede cambiar.',
            style: const TextStyle(color: AppColors.textoSuave, fontSize: 12),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Aviso(_error!),
          ],
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _cargando ? null : _guardar,
            child: _cargando
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                  )
                : const Text('Guardar cambios'),
          ),
        ],
      ),
    );
  }
}
