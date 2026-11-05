import 'dart:async';

import 'package:flutter/material.dart';

import '../models/reserva.dart';
import '../services/api_client.dart';
import '../services/eventos.dart';
import '../services/reservas_service.dart';
import '../services/sesion.dart';
import '../theme/app_theme.dart';
import '../utils/formato.dart';
import '../utils/navegacion.dart';
import '../widgets/comunes.dart';
import '../widgets/estado_vacio.dart';
import 'reserva_detalle_screen.dart';

/// Lista de reservas del cliente. Las pendientes muestran cuánto falta para que se libere el stock.
class ReservasScreen extends StatefulWidget {
  const ReservasScreen({super.key});

  @override
  State<ReservasScreen> createState() => _ReservasScreenState();
}

class _ReservasScreenState extends State<ReservasScreen> {
  final _servicio = ReservasService();
  List<Reserva>? _lista;
  String? _error;
  Timer? _reloj;
  bool _cargando = false;

  @override
  void initState() {
    super.initState();
    Eventos.reservasCambiaron.addListener(_cargar);
    Sesion.instancia.addListener(_alCambiarSesion);
    _reloj = Timer.periodic(const Duration(seconds: 1), (_) => _tic());
    _cargar();
  }

  @override
  void dispose() {
    Eventos.reservasCambiaron.removeListener(_cargar);
    Sesion.instancia.removeListener(_alCambiarSesion);
    _reloj?.cancel();
    super.dispose();
  }

  void _alCambiarSesion() {
    if (!Sesion.instancia.autenticado) {
      if (mounted) setState(() => _lista = null);
    } else {
      _cargar();
    }
  }

  void _tic() {
    if (!mounted) return;
    final lista = _lista;
    if (lista == null || !lista.any((r) => r.pendiente)) return;
    // Si alguna llegó a cero, se vuelve a consultar para ver su estado real
    if (lista.any((r) => r.pendiente && r.segundosAhora <= 0)) {
      _cargar();
    }
    setState(() {});
  }

  Future<void> _cargar() async {
    if (!Sesion.instancia.autenticado || _cargando) return;
    _cargando = true;
    try {
      final lista = await _servicio.listar();
      if (!mounted) return;
      setState(() {
        _lista = lista;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.mensaje);
    } finally {
      _cargando = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!Sesion.instancia.autenticado) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mis reservas')),
        body: EstadoVacio(
          icono: Icons.receipt_long_outlined,
          titulo: 'Inicia sesión para ver tus reservas',
          mensaje: 'Reserva un medicamento y págalo en 15 minutos para asegurar tu stock.',
          accion: FilledButton(
            onPressed: () => irAIniciarSesion(context),
            child: const Text('Iniciar sesión'),
          ),
        ),
      );
    }

    Widget cuerpo;
    final lista = _lista;
    if (_error != null && lista == null) {
      cuerpo = EstadoVacio(
        icono: Icons.wifi_off_outlined,
        titulo: 'No pudimos cargar tus reservas',
        mensaje: _error,
        accion: FilledButton(onPressed: _cargar, child: const Text('Reintentar')),
      );
    } else if (lista == null) {
      cuerpo = const Center(child: CircularProgressIndicator());
    } else if (lista.isEmpty) {
      cuerpo = const EstadoVacio(
        icono: Icons.receipt_long_outlined,
        titulo: 'Aún no tienes reservas',
        mensaje: 'Busca un medicamento y toca "Reservar" en la botica que prefieras.',
      );
    } else {
      cuerpo = RefreshIndicator(
        onRefresh: _cargar,
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: lista.length,
          separatorBuilder: (context, i) => const SizedBox(height: 10),
          itemBuilder: (context, i) => _tarjeta(lista[i]),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Mis reservas')),
      body: cuerpo,
    );
  }

  Widget _tarjeta(Reserva r) {
    final color = r.pendiente
        ? const Color(0xFFB7791F)
        : (r.pagada || r.estado == 'entregada')
            ? AppColors.verde
            : r.estado == 'expirada'
                ? AppColors.alerta
                : AppColors.textoSuave;

    return TarjetaBase(
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => ReservaDetalleScreen(reserva: r)),
        );
        if (mounted) _cargar();
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  r.medicamentoNombre,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              EtiquetaChip(r.estadoTexto, color: color),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '${r.cantidad} × ${soles(r.precioUnitario)} · ${r.boticaNombre}',
            style: const TextStyle(color: AppColors.textoSuave, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (r.pendiente)
                Row(
                  children: [
                    Icon(Icons.timer_outlined, size: 18, color: r.segundosAhora <= 120 ? AppColors.alerta : color),
                    const SizedBox(width: 4),
                    Text(
                      'Paga en ${mmss(r.segundosAhora)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: r.segundosAhora <= 120 ? AppColors.alerta : color,
                      ),
                    ),
                  ],
                )
              else if (r.pagada && r.codigo != null)
                Text('Código: ${r.codigo}', style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 2))
              else
                const SizedBox.shrink(),
              Text(soles(r.total), style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.azul)),
            ],
          ),
        ],
      ),
    );
  }
}
