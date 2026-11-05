import '../models/reserva.dart';
import 'api_client.dart';
import 'eventos.dart';

/// Datos de pago que escribe el cliente.
class DatosPago {
  const DatosPago.tarjeta({required String numero, required String vencimiento, required String cvv})
      : metodo = 'tarjeta',
        numeroTarjeta = numero,
        vencimientoTarjeta = vencimiento,
        cvvTarjeta = cvv,
        celular = null;

  const DatosPago.billetera({required this.metodo, required this.celular})
      : numeroTarjeta = null,
        vencimientoTarjeta = null,
        cvvTarjeta = null;

  final String metodo;
  final String? numeroTarjeta;
  final String? vencimientoTarjeta;
  final String? cvvTarjeta;
  final String? celular;

  Map<String, dynamic> toJson() => {
        'metodo': metodo,
        if (numeroTarjeta != null) 'numero_tarjeta': numeroTarjeta,
        if (vencimientoTarjeta != null) 'vencimiento': vencimientoTarjeta,
        if (cvvTarjeta != null) 'cvv': cvvTarjeta,
        if (celular != null) 'celular': celular,
      };
}

class ResultadoReserva {
  const ResultadoReserva(this.reserva, this.mensaje);
  final Reserva reserva;
  final String? mensaje;
}

class ReservasService {
  ReservasService({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;

  /// Separa el stock por 15 minutos.
  Future<ResultadoReserva> crear({
    required String boticaId,
    required String medicamentoId,
    required int cantidad,
  }) async {
    final datos = await _api.post('/api/v1/reservas', cuerpo: {
      'botica_id': boticaId,
      'medicamento_id': medicamentoId,
      'cantidad': cantidad,
    });
    Eventos.avisarReservas();
    return ResultadoReserva(
      Reserva.fromJson(datos['reserva'] as Map<String, dynamic>),
      datos['mensaje'] as String?,
    );
  }

  Future<List<Reserva>> listar() async {
    final datos = await _api.get('/api/v1/reservas');
    return (datos['reservas'] as List<dynamic>? ?? [])
        .map((e) => Reserva.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Reserva> obtener(String id) async {
    final datos = await _api.get('/api/v1/reservas/$id');
    return Reserva.fromJson(datos['reserva'] as Map<String, dynamic>);
  }

  Future<ResultadoReserva> pagar(String id, DatosPago pago) async {
    final datos = await _api.post('/api/v1/reservas/$id/pagar', cuerpo: pago.toJson());
    Eventos.avisarReservas();
    return ResultadoReserva(
      Reserva.fromJson(datos['reserva'] as Map<String, dynamic>),
      datos['mensaje'] as String?,
    );
  }

  Future<ResultadoReserva> cancelar(String id) async {
    final datos = await _api.post('/api/v1/reservas/$id/cancelar');
    Eventos.avisarReservas();
    return ResultadoReserva(
      Reserva.fromJson(datos['reserva'] as Map<String, dynamic>),
      datos['mensaje'] as String?,
    );
  }
}
