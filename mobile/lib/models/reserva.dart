import '../utils/formato.dart';

/// Reserva de un producto en una botica, con plazo para pagar (15 minutos).
class Reserva {
  Reserva({
    required this.id,
    required this.estado,
    required this.cantidad,
    required this.precioUnitario,
    required this.total,
    required this.segundosRestantes,
    required this.boticaId,
    required this.boticaNombre,
    required this.boticaDireccion,
    required this.medicamentoId,
    required this.medicamentoNombre,
    required this.requiereReceta,
    this.codigo,
    this.metodoPago,
    this.concentracion,
    this.presentacion,
  }) : venceLocal = DateTime.now().add(Duration(seconds: segundosRestantes));

  final String id;
  final String estado;
  final int cantidad;
  final double precioUnitario;
  final double total;
  final int segundosRestantes;
  final String boticaId;
  final String boticaNombre;
  final String boticaDireccion;
  final String medicamentoId;
  final String medicamentoNombre;
  final bool requiereReceta;
  final String? codigo;
  final String? metodoPago;
  final String? concentracion;
  final String? presentacion;

  /// Momento en que vence según el reloj del dispositivo (calculado con los segundos que dio la API,
  /// así no depende de que el reloj del teléfono esté bien).
  final DateTime venceLocal;

  bool get pendiente => estado == 'pendiente_pago';
  bool get pagada => estado == 'pagada';

  int get segundosAhora {
    if (!pendiente) return 0;
    final s = venceLocal.difference(DateTime.now()).inSeconds;
    return s < 0 ? 0 : s;
  }

  String get descripcionProducto => [concentracion, presentacion]
      .whereType<String>()
      .where((p) => p.isNotEmpty)
      .join(' · ');

  String get estadoTexto {
    switch (estado) {
      case 'pendiente_pago':
        return 'Pendiente de pago';
      case 'pagada':
        return 'Pagada · por recoger';
      case 'entregada':
        return 'Entregada';
      case 'expirada':
        return 'Vencida';
      case 'cancelada':
        return 'Cancelada';
      default:
        return estado;
    }
  }

  factory Reserva.fromJson(Map<String, dynamic> json) {
    return Reserva(
      id: json['id'].toString(),
      estado: json['estado'] as String,
      cantidad: entero(json['cantidad'], 1),
      precioUnitario: decimal(json['precio_unitario']) ?? 0,
      total: decimal(json['total']) ?? 0,
      segundosRestantes: entero(json['segundos_restantes']),
      boticaId: json['botica_id'].toString(),
      boticaNombre: json['botica_nombre'] as String? ?? '',
      boticaDireccion: json['botica_direccion'] as String? ?? '',
      medicamentoId: json['medicamento_id'].toString(),
      medicamentoNombre: json['medicamento_nombre'] as String? ?? '',
      requiereReceta: json['requiere_receta'] as bool? ?? false,
      codigo: json['codigo'] as String?,
      metodoPago: json['metodo_pago'] as String?,
      concentracion: json['concentracion'] as String?,
      presentacion: json['presentacion'] as String?,
    );
  }
}
