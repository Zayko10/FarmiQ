import '../utils/formato.dart';

/// Línea de inventario de la botica (panel del personal).
class ItemInventario {
  const ItemInventario({
    required this.medicamentoId,
    required this.nombre,
    required this.principioActivo,
    required this.concentracion,
    required this.presentacion,
    required this.categoria,
    required this.esGenerico,
    required this.requiereReceta,
    required this.stock,
    required this.stockReservado,
    required this.disponible,
    required this.precio,
    required this.desactualizado,
    this.minutosDesdeActualizacion,
  });

  final String medicamentoId;
  final String nombre;
  final String principioActivo;
  final String concentracion;
  final String presentacion;
  final String categoria;
  final bool esGenerico;
  final bool requiereReceta;
  final int stock;
  final int stockReservado;
  final int disponible;
  final double precio;
  final bool desactualizado;
  final int? minutosDesdeActualizacion;

  String get descripcion => [principioActivo, concentracion, presentacion]
      .where((p) => p.isNotEmpty)
      .join(' · ');

  factory ItemInventario.fromJson(Map<String, dynamic> json) {
    return ItemInventario(
      medicamentoId: json['medicamento_id'].toString(),
      nombre: json['nombre'] as String,
      principioActivo: json['principio_activo'] as String? ?? '',
      concentracion: json['concentracion'] as String? ?? '',
      presentacion: json['presentacion'] as String? ?? '',
      categoria: json['categoria'] as String? ?? '',
      esGenerico: json['es_generico'] as bool? ?? false,
      requiereReceta: json['requiere_receta'] as bool? ?? false,
      stock: entero(json['stock']),
      stockReservado: entero(json['stock_reservado']),
      disponible: entero(json['disponible']),
      precio: decimal(json['precio']) ?? 0,
      desactualizado: json['desactualizado'] as bool? ?? false,
      minutosDesdeActualizacion: (json['minutos_desde_actualizacion'] as num?)?.toInt(),
    );
  }
}

/// Producto del catálogo que la botica todavía no tiene en su inventario.
class ProductoCatalogo {
  const ProductoCatalogo({
    required this.medicamentoId,
    required this.nombre,
    required this.descripcion,
  });

  final String medicamentoId;
  final String nombre;
  final String descripcion;

  factory ProductoCatalogo.fromJson(Map<String, dynamic> json) {
    final partes = [
      json['principio_activo'] as String? ?? '',
      json['concentracion'] as String? ?? '',
      json['presentacion'] as String? ?? '',
    ].where((p) => p.isNotEmpty).join(' · ');
    return ProductoCatalogo(
      medicamentoId: json['medicamento_id'].toString(),
      nombre: json['nombre'] as String,
      descripcion: partes,
    );
  }
}

/// Reserva vista por el personal de la botica.
class ReservaPanel {
  ReservaPanel({
    required this.id,
    required this.estado,
    required this.cantidad,
    required this.total,
    required this.codigo,
    required this.clienteNombre,
    required this.medicamentoNombre,
    required this.segundosRestantes,
    this.clienteTelefono,
    this.metodoPago,
    this.descripcionProducto,
  }) : venceLocal = DateTime.now().add(Duration(seconds: segundosRestantes));

  final String id;
  final String estado;
  final int cantidad;
  final double total;
  final String codigo;
  final String clienteNombre;
  final String? clienteTelefono;
  final String medicamentoNombre;
  final String? descripcionProducto;
  final String? metodoPago;
  final int segundosRestantes;
  final DateTime venceLocal;

  int get segundosAhora {
    if (estado != 'pendiente_pago') return 0;
    final s = venceLocal.difference(DateTime.now()).inSeconds;
    return s < 0 ? 0 : s;
  }

  factory ReservaPanel.fromJson(Map<String, dynamic> json) {
    final desc = [json['concentracion'] as String?, json['presentacion'] as String?]
        .whereType<String>()
        .where((p) => p.isNotEmpty)
        .join(' · ');
    return ReservaPanel(
      id: json['id'].toString(),
      estado: json['estado'] as String,
      cantidad: entero(json['cantidad'], 1),
      total: decimal(json['total']) ?? 0,
      codigo: json['codigo'] as String? ?? '',
      clienteNombre: json['cliente_nombre'] as String? ?? '',
      clienteTelefono: json['cliente_telefono'] as String?,
      medicamentoNombre: json['medicamento_nombre'] as String? ?? '',
      descripcionProducto: desc.isEmpty ? null : desc,
      metodoPago: json['metodo_pago'] as String?,
      segundosRestantes: entero(json['segundos_restantes']),
    );
  }
}

/// Números del tablero de resumen del personal.
class ResumenPanel {
  const ResumenPanel({
    required this.boticaNombre,
    required this.productos,
    required this.sinStock,
    required this.stockBajo,
    required this.desactualizados,
    required this.unidadesReservadas,
    required this.pendientesPago,
    required this.porEntregar,
    required this.entregadasHoy,
    required this.ventasHoy,
  });

  final String boticaNombre;
  final int productos;
  final int sinStock;
  final int stockBajo;
  final int desactualizados;
  final int unidadesReservadas;
  final int pendientesPago;
  final int porEntregar;
  final int entregadasHoy;
  final double ventasHoy;

  factory ResumenPanel.fromJson(Map<String, dynamic> json) {
    final inv = json['inventario'] as Map<String, dynamic>;
    final res = json['reservas'] as Map<String, dynamic>;
    final botica = json['botica'] as Map<String, dynamic>;
    return ResumenPanel(
      boticaNombre: botica['nombre'] as String? ?? '',
      productos: entero(inv['productos']),
      sinStock: entero(inv['sin_stock']),
      stockBajo: entero(inv['stock_bajo']),
      desactualizados: entero(inv['desactualizados']),
      unidadesReservadas: entero(inv['unidades_reservadas']),
      pendientesPago: entero(res['pendientes_pago']),
      porEntregar: entero(res['por_entregar']),
      entregadasHoy: entero(res['entregadas_hoy']),
      ventasHoy: decimal(res['ventas_hoy']) ?? 0,
    );
  }
}
