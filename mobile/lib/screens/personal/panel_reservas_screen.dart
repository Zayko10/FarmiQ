import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/inventario.dart';
import '../../services/api_client.dart';
import '../../services/panel_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/formato.dart';
import '../../widgets/comunes.dart';
import '../../widgets/estado_vacio.dart';

const _ambar = Color(0xFFB7791F);

/// Reservas de los clientes de la botica: por pagar (con su cuenta regresiva), por entregar y entregadas.
class PanelReservasScreen extends StatefulWidget {
  const PanelReservasScreen({super.key});

  @override
  State<PanelReservasScreen> createState() => PanelReservasScreenState();
}

class PanelReservasScreenState extends State<PanelReservasScreen> {
  static const _estados = {
    'pagada': 'Por entregar',
    'pendiente_pago': 'Por pagar',
    'entregada': 'Entregadas',
  };

  final _servicio = PanelService();
  final _codigo = TextEditingController();

  List<ReservaPanel>? _lista;
  String _estado = 'pagada';
  String? _error;
  bool _entregando = false;
  Timer? _reloj;
  int _segundos = 0;

  @override
  void initState() {
    super.initState();
    cargar();
    _reloj = Timer.periodic(const Duration(seconds: 1), (_) => _tic());
  }

  @override
  void dispose() {
    _reloj?.cancel();
    _codigo.dispose();
    super.dispose();
  }

  void _tic() {
    if (!mounted) return;
    _segundos++;
    final lista = _lista;
    final hayPendientes = lista != null && lista.any((r) => r.estado == 'pendiente_pago');
    // Se vuelve a consultar cada 20 s para ver reservas nuevas y pagos recién hechos
    if (_segundos % 20 == 0) {
      cargar();
    } else if (hayPendientes) {
      setState(() {});
    }
  }

  void aplicarEstado(String estado) {
    setState(() {
      _estado = estado;
      _lista = null;
    });
    cargar();
  }

  Future<void> cargar() async {
    try {
      final lista = await _servicio.reservas(estado: _estado);
      if (!mounted) return;
      setState(() {
        _lista = lista;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.mensaje);
    }
  }

  Future<void> _entregar(String codigo) async {
    if (_entregando) return;
    setState(() => _entregando = true);
    try {
      await _servicio.entregar(codigo);
      if (!mounted) return;
      _codigo.clear();
      mostrarMensaje(context, 'Entrega registrada');
      await cargar();
    } on ApiException catch (e) {
      if (!mounted) return;
      mostrarMensaje(context, e.mensaje);
    } finally {
      if (mounted) setState(() => _entregando = false);
    }
  }

  Future<void> _confirmarEntrega(ReservaPanel r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Registrar la entrega?'),
        content: Text('${r.cantidad} × ${r.medicamentoNombre} para ${r.clienteNombre}.\nCódigo ${r.codigo}.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sí, entregar')),
        ],
      ),
    );
    if (ok == true) await _entregar(r.codigo);
  }

  @override
  Widget build(BuildContext context) {
    final lista = _lista;

    Widget cuerpo;
    if (_error != null && lista == null) {
      cuerpo = EstadoVacio(
        icono: Icons.wifi_off_outlined,
        titulo: 'No pudimos cargar las reservas',
        mensaje: _error,
        accion: FilledButton(onPressed: cargar, child: const Text('Reintentar')),
      );
    } else if (lista == null) {
      cuerpo = const Center(child: CircularProgressIndicator());
    } else if (lista.isEmpty) {
      cuerpo = EstadoVacio(
        icono: Icons.receipt_long_outlined,
        titulo: 'No hay reservas ${_estados[_estado]!.toLowerCase()}',
      );
    } else {
      cuerpo = RefreshIndicator(
        onRefresh: cargar,
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          itemCount: lista.length,
          separatorBuilder: (context, i) => const SizedBox(height: 8),
          itemBuilder: (context, i) => _tarjeta(lista[i]),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Reservas')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _codigo,
                    textCapitalization: TextCapitalization.characters,
                    maxLength: 6,
                    decoration: InputDecoration(
                      hintText: 'Código de retiro del cliente',
                      counterText: '',
                      prefixIcon: const Icon(Icons.qr_code_2),
                      filled: true,
                      fillColor: Colors.white,
                      border: bordeRedondeado(),
                      enabledBorder: bordeRedondeado(),
                    ),
                    onSubmitted: (v) => v.trim().length == 6 ? _entregar(v) : null,
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _entregando
                      ? null
                      : () {
                          final c = _codigo.text.trim();
                          if (c.length != 6) {
                            mostrarMensaje(context, 'El código tiene 6 caracteres.');
                            return;
                          }
                          _entregar(c);
                        },
                  child: const Text('Entregar'),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              children: [
                for (final e in _estados.entries) ...[
                  ChoiceChip(
                    label: Text(e.value),
                    selected: _estado == e.key,
                    onSelected: (_) => aplicarEstado(e.key),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          Expanded(child: cuerpo),
        ],
      ),
    );
  }

  Widget _tarjeta(ReservaPanel r) {
    final pendiente = r.estado == 'pendiente_pago';
    final pagada = r.estado == 'pagada';

    return TarjetaBase(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${r.cantidad} × ${r.medicamentoNombre}',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
              Text(soles(r.total), style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
          if (r.descripcionProducto != null)
            Text(r.descripcionProducto!, style: const TextStyle(color: AppColors.textoSuave, fontSize: 12)),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.person_outline, size: 16, color: AppColors.textoSuave),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  r.clienteTelefono == null || r.clienteTelefono!.isEmpty
                      ? r.clienteNombre
                      : '${r.clienteNombre} · ${r.clienteTelefono}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (pendiente)
            Row(
              children: [
                const Icon(Icons.timer_outlined, size: 18, color: _ambar),
                const SizedBox(width: 4),
                Text(
                  'Vence en ${mmss(r.segundosAhora)} si no paga',
                  style: const TextStyle(color: _ambar, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          if (pagada)
            Row(
              children: [
                const EtiquetaChip('Pagada', color: AppColors.verde),
                const SizedBox(width: 8),
                Text(
                  r.codigo,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20, letterSpacing: 3),
                ),
                const Spacer(),
                FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 38)),
                  onPressed: _entregando ? null : () => _confirmarEntrega(r),
                  child: const Text('Entregar'),
                ),
              ],
            ),
          if (r.estado == 'entregada') const EtiquetaChip('Entregada', color: AppColors.verde),
        ],
      ),
    );
  }
}
