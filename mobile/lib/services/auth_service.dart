import 'api_client.dart';
import 'sesion.dart';

/// Registro, inicio de sesión, recuperación de contraseña y perfil.
class AuthService {
  AuthService({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;

  /// HU02: inicio de sesión del cliente.
  Future<Usuario> login(String email, String password) =>
      _iniciar('/api/v1/auth/login', email, password);

  /// Inicio de sesión del personal de botica (otra puerta de entrada).
  Future<Usuario> loginPersonal(String email, String password) =>
      _iniciar('/api/v1/auth/login-personal', email, password);

  Future<Usuario> _iniciar(String ruta, String email, String password) async {
    final datos = await _api.post(ruta, cuerpo: {'email': email.trim(), 'password': password});
    final usuario = Usuario.fromJson(datos['usuario'] as Map<String, dynamic>);
    await Sesion.instancia.iniciar(datos['token'] as String, usuario);
    return usuario;
  }

  /// HU01: registro de cliente.
  Future<void> registrar({
    required String nombre,
    required String email,
    required String password,
    String? telefono,
  }) async {
    await _api.post('/api/v1/auth/registro', cuerpo: {
      'nombre': nombre.trim(),
      'email': email.trim(),
      if (telefono != null && telefono.trim().isNotEmpty) 'telefono': telefono.trim(),
      'password': password,
      'acepta_terminos': true,
    });
  }

  /// HU13: pide el código de recuperación (en desarrollo se imprime en la consola de la API).
  Future<String> olvidePassword(String email) async {
    final datos = await _api.post('/api/v1/auth/olvide-password', cuerpo: {'email': email.trim()});
    return datos['mensaje'] as String? ?? 'Revisa tu correo.';
  }

  Future<String> restablecerPassword(String token, String password) async {
    final datos = await _api.post(
      '/api/v1/auth/restablecer-password',
      cuerpo: {'token': token.trim(), 'password': password},
    );
    return datos['mensaje'] as String? ?? 'Contraseña actualizada.';
  }

  /// HU14: edición de perfil.
  Future<Usuario> actualizarPerfil({String? nombre, String? telefono, String? direccion}) async {
    final datos = await _api.patch('/api/v1/perfil', cuerpo: {
      if (nombre != null) 'nombre': nombre.trim(),
      if (telefono != null) 'telefono': telefono.trim(),
      if (direccion != null) 'direccion': direccion.trim(),
    });
    final actual = Sesion.instancia.usuario;
    final nuevo = Usuario.fromJson({
      ...(datos['usuario'] as Map<String, dynamic>),
      'botica_nombre': actual?.boticaNombre,
    });
    await Sesion.instancia.actualizarUsuario(nuevo);
    return nuevo;
  }

  Future<Usuario> obtenerPerfil() async {
    final datos = await _api.get('/api/v1/perfil');
    return Usuario.fromJson(datos['usuario'] as Map<String, dynamic>);
  }
}
