import '../models/detalle.dart';
import '../models/medicamento.dart';
import 'api_client.dart';
import 'ubicacion_service.dart';

class ResultadoBusqueda {
  const ResultadoBusqueda({
    required this.medicamentos,
    required this.filtrosActivos,
    this.mensaje,
    this.sugerencia,
  });

  final List<Medicamento> medicamentos;
  final int filtrosActivos;
  final String? mensaje;
  final String? sugerencia;
}

class MedicamentosService {
  MedicamentosService({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;

  /// HU03 (búsqueda) y HU16 (orden y filtros).
  Future<ResultadoBusqueda> buscar({
    required String q,
    String orden = 'relevancia',
    bool soloStock = false,
    PosicionCliente? posicion,
  }) async {
    final consulta = <String, String>{
      'q': q,
      'orden': orden,
      if (soloStock) 'solo_stock': 'true',
      if (posicion != null) 'lat': posicion.lat.toString(),
      if (posicion != null) 'lng': posicion.lng.toString(),
    };

    final datos = await _api.get('/api/v1/medicamentos', consulta: consulta);
    final lista = (datos['resultados'] as List<dynamic>? ?? [])
        .map((e) => Medicamento.fromJson(e as Map<String, dynamic>))
        .toList();

    return ResultadoBusqueda(
      medicamentos: lista,
      filtrosActivos: (datos['filtros_activos'] as num?)?.toInt() ?? 0,
      mensaje: datos['mensaje'] as String?,
      sugerencia: datos['sugerencia'] as String?,
    );
  }

  /// HU15: detalle y ficha técnica (indica si es favorito cuando hay sesión).
  Future<DetalleMedicamento> detalle(String id) async {
    final datos = await _api.get('/api/v1/medicamentos/$id');
    return DetalleMedicamento.fromJson(datos);
  }

  /// HU04: boticas con stock de este medicamento (con distancia si se envía la ubicación).
  Future<List<DisponibilidadBotica>> disponibilidad(String id, {PosicionCliente? posicion}) async {
    final datos = await _api.get(
      '/api/v1/medicamentos/$id/disponibilidad',
      consulta: {
        if (posicion != null) 'lat': posicion.lat.toString(),
        if (posicion != null) 'lng': posicion.lng.toString(),
      },
    );
    return (datos['boticas'] as List<dynamic>? ?? [])
        .map((e) => DisponibilidadBotica.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// HU05: genéricos equivalentes y cuánto se ahorra.
  Future<List<Alternativa>> alternativas(String id) async {
    final datos = await _api.get('/api/v1/medicamentos/$id/alternativas');
    return (datos['alternativas'] as List<dynamic>? ?? [])
        .map((e) => Alternativa.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// HU17: favoritos.
  Future<List<Medicamento>> favoritos() async {
    final datos = await _api.get('/api/v1/favoritos');
    return (datos['favoritos'] as List<dynamic>? ?? [])
        .map((e) => Medicamento.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> agregarFavorito(String id) async {
    await _api.put('/api/v1/favoritos/$id');
  }

  Future<void> quitarFavorito(String id) async {
    await _api.delete('/api/v1/favoritos/$id');
  }
}
