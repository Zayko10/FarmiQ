import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';
import 'sesion.dart';

/// Error con un mensaje listo para mostrar al usuario.
class ApiException implements Exception {
  ApiException(this.mensaje, {this.codigo, this.datos = const {}});

  final String mensaje;
  final int? codigo;

  /// Cuerpo completo de la respuesta de error (por ejemplo `segundos_restantes` en un bloqueo).
  final Map<String, dynamic> datos;

  bool get bloqueado => codigo == 429 && datos['bloqueado'] == true;

  @override
  String toString() => mensaje;
}

/// Hace las peticiones a la API de FarmiQ. Si hay sesión iniciada, envía el token solo.
class ApiClient {
  Future<Map<String, dynamic>> get(String ruta, {Map<String, String>? consulta}) =>
      _enviar('GET', ruta, consulta: consulta);

  Future<Map<String, dynamic>> post(String ruta, {Map<String, dynamic>? cuerpo}) =>
      _enviar('POST', ruta, cuerpo: cuerpo ?? const {});

  Future<Map<String, dynamic>> put(String ruta, {Map<String, dynamic>? cuerpo}) =>
      _enviar('PUT', ruta, cuerpo: cuerpo ?? const {});

  Future<Map<String, dynamic>> patch(String ruta, {Map<String, dynamic>? cuerpo}) =>
      _enviar('PATCH', ruta, cuerpo: cuerpo ?? const {});

  Future<Map<String, dynamic>> delete(String ruta) => _enviar('DELETE', ruta);

  Future<Map<String, dynamic>> _enviar(
    String metodo,
    String ruta, {
    Map<String, String>? consulta,
    Map<String, dynamic>? cuerpo,
  }) async {
    final uri = Uri.parse('$apiBaseUrl$ruta').replace(queryParameters: consulta);
    final token = Sesion.instancia.token;
    final cabeceras = <String, String>{
      if (token != null) 'Authorization': 'Bearer $token',
      if (cuerpo != null) 'Content-Type': 'application/json',
    };
    final texto = cuerpo == null ? null : jsonEncode(cuerpo);

    http.Response respuesta;
    try {
      switch (metodo) {
        case 'POST':
          respuesta = await http.post(uri, headers: cabeceras, body: texto);
        case 'PUT':
          respuesta = await http.put(uri, headers: cabeceras, body: texto);
        case 'PATCH':
          respuesta = await http.patch(uri, headers: cabeceras, body: texto);
        case 'DELETE':
          respuesta = await http.delete(uri, headers: cabeceras);
        default:
          respuesta = await http.get(uri, headers: cabeceras);
      }
    } catch (_) {
      throw ApiException('No pudimos conectar con FarmiQ. Revisa tu conexión e inténtalo de nuevo.');
    }

    Map<String, dynamic> datos;
    try {
      datos = jsonDecode(utf8.decode(respuesta.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException('Ocurrió un error. Inténtalo de nuevo.', codigo: respuesta.statusCode);
    }

    if (respuesta.statusCode >= 400) {
      // Token vencido o inválido en una petición con sesión: se cierra la sesión
      if (respuesta.statusCode == 401 && token != null) {
        Sesion.instancia.expirar();
      }
      throw ApiException(
        _mensajeDeError(datos),
        codigo: respuesta.statusCode,
        datos: datos,
      );
    }
    return datos;
  }

  /// Si la API devuelve una lista de campos inválidos, se muestran todos.
  String _mensajeDeError(Map<String, dynamic> datos) {
    final detalles = datos['detalles'];
    if (detalles is List && detalles.isNotEmpty) {
      final mensajes = detalles
          .map((d) => d is Map ? d['mensaje']?.toString() : null)
          .whereType<String>()
          .toSet()
          .toList();
      if (mensajes.isNotEmpty) return mensajes.join('\n');
    }
    return datos['error'] as String? ?? 'Ocurrió un error. Inténtalo de nuevo.';
  }
}
