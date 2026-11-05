import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Usuario autenticado (cliente o personal de botica).
class Usuario {
  const Usuario({
    required this.id,
    required this.nombre,
    required this.email,
    required this.rol,
    this.telefono,
    this.direccion,
    this.boticaId,
    this.boticaNombre,
  });

  final String id;
  final String nombre;
  final String email;
  final String rol;
  final String? telefono;
  final String? direccion;
  final String? boticaId;
  final String? boticaNombre;

  bool get esPersonal => rol == 'personal';

  factory Usuario.fromJson(Map<String, dynamic> json) {
    return Usuario(
      id: json['id'].toString(),
      nombre: json['nombre'] as String? ?? '',
      email: json['email'] as String? ?? '',
      rol: json['rol'] as String? ?? 'cliente',
      telefono: json['telefono'] as String?,
      direccion: json['direccion'] as String?,
      boticaId: json['botica_id']?.toString(),
      boticaNombre: json['botica_nombre'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'email': email,
        'rol': rol,
        'telefono': telefono,
        'direccion': direccion,
        'botica_id': boticaId,
        'botica_nombre': boticaNombre,
      };

  Usuario copiarCon({String? nombre, String? telefono, String? direccion}) {
    return Usuario(
      id: id,
      nombre: nombre ?? this.nombre,
      email: email,
      rol: rol,
      telefono: telefono ?? this.telefono,
      direccion: direccion ?? this.direccion,
      boticaId: boticaId,
      boticaNombre: boticaNombre,
    );
  }
}

/// Estado de la sesión de toda la app. Se guarda en el dispositivo.
class Sesion extends ChangeNotifier {
  Sesion._();

  static final Sesion instancia = Sesion._();

  static const _claveToken = 'farmiq_token';
  static const _claveUsuario = 'farmiq_usuario';

  String? _token;
  Usuario? _usuario;
  bool _invitado = false;
  bool _cargada = false;
  bool _expirada = false;

  String? get token => _token;
  Usuario? get usuario => _usuario;
  bool get autenticado => _token != null && _usuario != null;
  bool get esPersonal => autenticado && _usuario!.esPersonal;
  bool get esInvitado => _invitado && !autenticado;
  bool get cargada => _cargada;

  /// Verdadero una sola vez después de que la sesión venció (para avisarlo en el login).
  bool consumirAvisoExpiracion() {
    final valor = _expirada;
    _expirada = false;
    return valor;
  }

  Future<void> cargar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_claveToken);
      final usuario = prefs.getString(_claveUsuario);
      if (token != null && usuario != null) {
        _token = token;
        _usuario = Usuario.fromJson(jsonDecode(usuario) as Map<String, dynamic>);
      }
    } catch (_) {
      _token = null;
      _usuario = null;
    }
    _cargada = true;
    notifyListeners();
  }

  Future<void> iniciar(String token, Usuario usuario) async {
    _token = token;
    _usuario = usuario;
    _invitado = false;
    _expirada = false;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_claveToken, token);
      await prefs.setString(_claveUsuario, jsonEncode(usuario.toJson()));
    } catch (_) {
      // Si no se puede guardar, la sesión sigue activa mientras la app esté abierta
    }
  }

  Future<void> actualizarUsuario(Usuario usuario) async {
    _usuario = usuario;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_claveUsuario, jsonEncode(usuario.toJson()));
    } catch (_) {}
  }

  Future<void> cerrar() async {
    _token = null;
    _usuario = null;
    _invitado = false;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_claveToken);
      await prefs.remove(_claveUsuario);
    } catch (_) {}
  }

  /// La API respondió 401 con un token guardado: la sesión venció.
  void expirar() {
    if (_token == null) return;
    _expirada = true;
    cerrar();
  }

  void entrarComoInvitado() {
    _invitado = true;
    notifyListeners();
  }

  void salirDeInvitado() {
    _invitado = false;
    notifyListeners();
  }
}
