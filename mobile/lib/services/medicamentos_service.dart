import '../models/medicamento.dart';
import 'api_client.dart';

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
  }) async {
    final consulta = <String, String>{
      'q': q,
      'orden': orden,
      if (soloStock) 'solo_stock': 'true',
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
}
