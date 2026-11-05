import 'package:flutter/material.dart';

import '../../models/inventario.dart';
import '../../services/api_client.dart';
import '../../services/panel_service.dart';
import '../../services/sesion.dart';
import '../../theme/app_theme.dart';
import '../../utils/formato.dart';
import '../../widgets/estado_vacio.dart';

const _ambar = Color(0xFFB7791F);

/// Tablero del personal: cuánto stock hay que atender y cómo van las reservas.
class PanelResumenScreen extends StatefulWidget {
  const PanelResumenScreen({super.key, required this.onIrInventario, required this.onIrReservas});

  final void Function(String filtro) onIrInventario;
  final void Function(String estado) onIrReservas;

  @override
  State<PanelResumenScreen> createState() => PanelResumenScreenState();
}

class PanelResumenScreenState extends State<PanelResumenScreen> {
  final _servicio = PanelService();
  ResumenPanel? _resumen;
  String? _error;

  @override
  void initState() {
    super.initState();
    cargar();
  }

  Future<void> cargar() async {
    try {
      final r = await _servicio.resumen();
      if (!mounted) return;
      setState(() {
        _resumen = r;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.mensaje);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _resumen;
    final esquema = Theme.of(context).colorScheme;
    final nombre = Sesion.instancia.usuario?.nombre ?? '';

    Widget cuerpo;
    if (_error != null && r == null) {
      cuerpo = EstadoVacio(
        icono: Icons.wifi_off_outlined,
        titulo: 'No pudimos cargar el resumen',
        mensaje: _error,
        accion: FilledButton(onPressed: cargar, child: const Text('Reintentar')),
      );
    } else if (r == null) {
      cuerpo = const Center(child: CircularProgressIndicator());
    } else {
      cuerpo = RefreshIndicator(
        onRefresh: cargar,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Text('Hola, $nombre', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            Text(r.boticaNombre, style: const TextStyle(color: AppColors.textoSuave)),
            const SizedBox(height: 16),
            _titulo('Reservas'),
            _grilla([
              _Dato('Por pagar', '${r.pendientesPago}', Icons.timer_outlined, _ambar,
                  () => widget.onIrReservas('pendiente_pago')),
              _Dato('Por entregar', '${r.porEntregar}', Icons.shopping_bag_outlined, esquema.primary,
                  () => widget.onIrReservas('pagada')),
              _Dato('Entregadas hoy', '${r.entregadasHoy}', Icons.verified_outlined, AppColors.verde,
                  () => widget.onIrReservas('entregada')),
              _Dato('Ventas de hoy', soles(r.ventasHoy), Icons.payments_outlined, AppColors.verde, null),
            ]),
            const SizedBox(height: 16),
            _titulo('Inventario'),
            _grilla([
              _Dato('Productos', '${r.productos}', Icons.inventory_2_outlined, esquema.primary,
                  () => widget.onIrInventario('todos')),
              _Dato('Sin stock', '${r.sinStock}', Icons.remove_shopping_cart_outlined, AppColors.alerta,
                  () => widget.onIrInventario('sin_stock')),
              _Dato('Stock bajo', '${r.stockBajo}', Icons.warning_amber_outlined, _ambar,
                  () => widget.onIrInventario('bajo')),
              _Dato('Sin actualizar +24 h', '${r.desactualizados}', Icons.update_disabled_outlined, _ambar,
                  () => widget.onIrInventario('desactualizados')),
            ]),
            const SizedBox(height: 12),
            Text(
              '${r.unidadesReservadas} unidades están separadas por clientes que aún no pagan o no recogen.',
              style: const TextStyle(color: AppColors.textoSuave, fontSize: 12),
            ),
            if (r.desactualizados > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _ambar.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _ambar.withValues(alpha: 0.35)),
                ),
                child: Text(
                  'Tienes ${r.desactualizados} producto${r.desactualizados == 1 ? '' : 's'} sin actualizar hace más de 24 horas. '
                  'Los clientes ven una advertencia en esos productos.',
                  style: const TextStyle(color: _ambar, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Panel de la botica')),
      body: cuerpo,
    );
  }

  Widget _titulo(String texto) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(texto, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
      );

  Widget _grilla(List<_Dato> datos) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.7,
      children: [for (final d in datos) _tarjeta(d)],
    );
  }

  Widget _tarjeta(_Dato d) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.borde),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: d.alTocar,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(d.icono, color: d.color),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    d.valor,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: d.color),
                  ),
                  Text(d.etiqueta, style: const TextStyle(fontSize: 12, color: AppColors.textoSuave)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Dato {
  const _Dato(this.etiqueta, this.valor, this.icono, this.color, this.alTocar);

  final String etiqueta;
  final String valor;
  final IconData icono;
  final Color color;
  final VoidCallback? alTocar;
}
