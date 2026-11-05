import '../models/inventario.dart';
import 'api_client.dart';

class PanelService {
  PanelService({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;

  Future<ResumenPanel> resumen() async {
    final datos = await _api.get('/api/v1/panel/resumen');
    return ResumenPanel.fromJson(datos);
  }

  /// [filtro]: todos, sin_stock, bajo, desactualizados
  Future<List<ItemInventario>> inventario({String? q, String filtro = 'todos'}) async {
    final datos = await _api.get('/api/v1/panel/inventario', consulta: {
      if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
      'filtro': filtro,
    });
    return (datos['productos'] as List<dynamic>? ?? [])
        .map((e) => ItemInventario.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// HU27: actualiza stock y/o precio.
  Future<ItemInventario> actualizar(String medicamentoId, {int? stock, double? precio}) async {
    final datos = await _api.patch('/api/v1/panel/inventario/$medicamentoId', cuerpo: {
      if (stock != null) 'stock': stock,
      if (precio != null) 'precio': precio,
    });
    return ItemInventario.fromJson(datos['producto'] as Map<String, dynamic>);
  }

  Future<List<ProductoCatalogo>> buscarCatalogo(String q) async {
    final datos = await _api.get('/api/v1/panel/catalogo', consulta: {'q': q.trim()});
    return (datos['productos'] as List<dynamic>? ?? [])
        .map((e) => ProductoCatalogo.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ItemInventario> agregarAlInventario(String medicamentoId, {required int stock, required double precio}) async {
    final datos = await _api.post('/api/v1/panel/inventario', cuerpo: {
      'medicamento_id': medicamentoId,
      'stock': stock,
      'precio': precio,
    });
    return ItemInventario.fromJson(datos['producto'] as Map<String, dynamic>);
  }

  Future<ItemInventario> crearProducto(Map<String, dynamic> producto) async {
    final datos = await _api.post('/api/v1/panel/medicamentos', cuerpo: producto);
    return ItemInventario.fromJson(datos['producto'] as Map<String, dynamic>);
  }

  /// [estado]: activas, pendiente_pago, pagada, entregada, todas
  Future<List<ReservaPanel>> reservas({String estado = 'activas'}) async {
    final datos = await _api.get('/api/v1/panel/reservas', consulta: {'estado': estado});
    return (datos['reservas'] as List<dynamic>? ?? [])
        .map((e) => ReservaPanel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> entregar(String codigo) async {
    await _api.post('/api/v1/panel/reservas/entregar', cuerpo: {'codigo': codigo.trim()});
  }
}
