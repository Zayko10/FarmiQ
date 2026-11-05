import 'package:geolocator/geolocator.dart';

class PosicionCliente {
  const PosicionCliente(this.lat, this.lng);
  final double lat;
  final double lng;
}

class ResultadoUbicacion {
  const ResultadoUbicacion({this.posicion, this.error, this.abrirAjustes = false});

  final PosicionCliente? posicion;
  final String? error;

  /// Verdadero si el permiso fue negado para siempre y hay que activarlo desde Ajustes.
  final bool abrirAjustes;
}

/// Pide permiso y obtiene la ubicación del cliente para calcular qué boticas le quedan cerca.
class UbicacionService {
  /// Última posición conocida (se reutiliza entre pantallas).
  static PosicionCliente? ultima;

  static Future<ResultadoUbicacion> obtener() async {
    try {
      final gpsActivo = await Geolocator.isLocationServiceEnabled();
      if (!gpsActivo) {
        return const ResultadoUbicacion(
          error: 'Tu GPS está desactivado. Actívalo para ver las boticas cercanas.',
          abrirAjustes: true,
        );
      }

      var permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied) {
        permiso = await Geolocator.requestPermission();
      }
      if (permiso == LocationPermission.denied) {
        return const ResultadoUbicacion(
          error: 'Necesitamos tu permiso de ubicación para mostrarte las boticas más cercanas.',
        );
      }
      if (permiso == LocationPermission.deniedForever) {
        return const ResultadoUbicacion(
          error: 'El permiso de ubicación está bloqueado. Actívalo desde los ajustes del dispositivo.',
          abrirAjustes: true,
        );
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      ultima = PosicionCliente(pos.latitude, pos.longitude);
      return ResultadoUbicacion(posicion: ultima);
    } catch (_) {
      return const ResultadoUbicacion(
        error: 'No pudimos obtener tu ubicación. Inténtalo de nuevo.',
      );
    }
  }

  static Future<void> abrirAjustes() async {
    try {
      await Geolocator.openAppSettings();
    } catch (_) {}
  }
}
