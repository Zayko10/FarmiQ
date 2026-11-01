import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';

/// Error con un mensaje listo para mostrar al usuario.
class ApiException implements Exception {
  ApiException(this.mensaje, {this.codigo});

  final String mensaje;
  final int? codigo;

  @override
  String toString() => mensaje;
}

/// Hace las peticiones a la API de FarmiQ.
class ApiClient {
  Future<Map<String, dynamic>> get(
    String ruta, {
    Map<String, String>? consulta,
    String? token,
  }) async {
    final uri = Uri.parse('$apiBaseUrl$ruta').replace(queryParameters: consulta);

    try {
      final respuesta = await http
          .get(uri, headers: {if (token != null) 'Authorization': 'Bearer $token'})
          .timeout(const Duration(seconds: 10));

      final cuerpo = jsonDecode(utf8.decode(respuesta.bodyBytes)) as Map<String, dynamic>;

      if (respuesta.statusCode >= 400) {
        throw ApiException(
          cuerpo['error'] as String? ?? 'Ocurrió un error. Inténtalo de nuevo.',
          codigo: respuesta.statusCode,
        );
      }
      return cuerpo;
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException('No pudimos conectar con FarmiQ. Revisa tu conexión e inténtalo de nuevo.');
    }
  }
}
