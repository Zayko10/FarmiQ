import '../models/botica.dart';
import 'api_client.dart';
import 'ubicacion_service.dart';

class ResultadoSedes {
  const ResultadoSedes({
    required this.boticas,
    required this.ubicacionActiva,
    this.mensaje,
    this.sugerencia,
  });

  final List<Botica> boticas;
  final bool ubicacionActiva;
  final String? mensaje;
  final String? sugerencia;
}

class BoticasService {
  BoticasService({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;

  /// Boticas ordenadas por cercanía; con [radioKm] solo las que están dentro de ese radio.
  Future<ResultadoSedes> listar({PosicionCliente? posicion, double? radioKm}) async {
    final datos = await _api.get('/api/v1/boticas', consulta: {
      if (posicion != null) 'lat': posicion.lat.toString(),
      if (posicion != null) 'lng': posicion.lng.toString(),
      if (posicion != null && radioKm != null) 'radio_km': radioKm.toString(),
    });
    return ResultadoSedes(
      boticas: (datos['boticas'] as List<dynamic>? ?? [])
          .map((e) => Botica.fromJson(e as Map<String, dynamic>))
          .toList(),
      ubicacionActiva: datos['ubicacion_activa'] as bool? ?? false,
      mensaje: datos['mensaje'] as String?,
      sugerencia: datos['sugerencia'] as String?,
    );
  }

  /// Productos de una botica con stock y precio.
  Future<List<ProductoBotica>> productos(String boticaId, {String? q, bool soloStock = false}) async {
    final datos = await _api.get('/api/v1/boticas/$boticaId/productos', consulta: {
      if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
      if (soloStock) 'solo_stock': 'true',
    });
    return (datos['productos'] as List<dynamic>? ?? [])
        .map((e) => ProductoBotica.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
