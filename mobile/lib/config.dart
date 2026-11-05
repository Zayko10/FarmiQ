import 'package:flutter/foundation.dart';

// Se puede forzar con: flutter run --dart-define=API_URL=http://192.168.1.50:3000
const String _apiUrlDefinida = String.fromEnvironment('API_URL');

/// Dirección de la API según dónde corre la app.
String get apiBaseUrl {
  if (_apiUrlDefinida.isNotEmpty) return _apiUrlDefinida;
  if (kIsWeb) return 'http://localhost:3000';
  // El emulador de Android ve la PC en 10.0.2.2
  if (defaultTargetPlatform == TargetPlatform.android) return 'http://10.0.2.2:3000';
  return 'http://localhost:3000';
}
