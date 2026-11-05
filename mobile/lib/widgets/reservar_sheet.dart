import 'package:flutter/material.dart';

import '../screens/reserva_detalle_screen.dart';
import '../services/api_client.dart';
import '../services/reservas_service.dart';
import '../services/sesion.dart';
import '../theme/app_theme.dart';
import '../utils/formato.dart';
import '../utils/navegacion.dart';
import 'comunes.dart';

const int _maxPorPedido = 5;

/// Pide iniciar sesión al invitado; si hay sesión abre la hoja para reservar.
/// Al confirmar, el stock queda separado 15 minutos y se abre la pantalla de pago.
Future<void> mostrarReserva(
  BuildContext context, {
  required String boticaId,
  required String boticaNombre,
  required String medicamentoId,
  required String medicamentoNombre,
  required double precio,
  required int stock,
  bool requiereReceta = false,
}) async {
  if (!Sesion.instancia.autenticado) {
    mostrarMensaje(
      context,
      'Inicia sesión o crea una cuenta para reservar.',
      accion: SnackBarAction(label: 'Iniciar sesión', onPressed: () => irAIniciarSesion(context)),
    );
    return;
  }

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: _ReservarSheet(
        boticaId: boticaId,
        boticaNombre: boticaNombre,
        medicamentoId: medicamentoId,
        medicamentoNombre: medicamentoNombre,
        precio: precio,
        stock: stock,
        requiereReceta: requiereReceta,
        contextoPadre: context,
      ),
    ),
  );
}

class _ReservarSheet extends StatefulWidget {
  const _ReservarSheet({
    required this.boticaId,
    required this.boticaNombre,
    required this.medicamentoId,
    required this.medicamentoNombre,
    required this.precio,
    required this.stock,
    required this.requiereReceta,
    required this.contextoPadre,
  });

  final String boticaId;
  final String boticaNombre;
  final String medicamentoId;
  final String medicamentoNombre;
  final double precio;
  final int stock;
  final bool requiereReceta;
  final BuildContext contextoPadre;

  @override
  State<_ReservarSheet> createState() => _ReservarSheetState();
}

class _ReservarSheetState extends State<_ReservarSheet> {
  final _servicio = ReservasService();
  int _cantidad = 1;
  bool _cargando = false;
  String? _error;

  int get _maximo => widget.stock < _maxPorPedido ? widget.stock : _maxPorPedido;

  Future<void> _confirmar() async {
    final navegador = Navigator.of(context);
    final padre = widget.contextoPadre;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final resultado = await _servicio.crear(
        boticaId: widget.boticaId,
        medicamentoId: widget.medicamentoId,
        cantidad: _cantidad,
      );
      navegador.pop();
      if (padre.mounted) {
        await Navigator.of(padre).push(
          MaterialPageRoute<void>(builder: (_) => ReservaDetalleScreen(reserva: resultado.reserva)),
        );
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = e.mensaje;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final total = widget.precio * _cantidad;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Reservar', style: textos.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(widget.medicamentoNombre, style: textos.titleMedium),
            Text(
              '${widget.boticaNombre} · ${soles(widget.precio)} c/u · ${widget.stock} disponibles',
              style: textos.bodySmall?.copyWith(color: AppColors.textoSuave),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Cantidad'),
                Row(
                  children: [
                    IconButton.outlined(
                      onPressed: _cargando || _cantidad <= 1 ? null : () => setState(() => _cantidad--),
                      icon: const Icon(Icons.remove),
                    ),
                    SizedBox(
                      width: 48,
                      child: Text(
                        '$_cantidad',
                        textAlign: TextAlign.center,
                        style: textos.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton.outlined(
                      onPressed: _cargando || _cantidad >= _maximo ? null : () => setState(() => _cantidad++),
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
              ],
            ),
            if (widget.stock > _maxPorPedido)
              Text(
                'Máximo $_maxPorPedido unidades por reserva.',
                style: textos.bodySmall?.copyWith(color: AppColors.textoSuave),
              ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total a pagar', style: textos.titleMedium),
                Text(
                  soles(total),
                  style: textos.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: AppColors.azul),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Aviso(
              'Separamos tu producto por 15 minutos. Debes pagar dentro de ese tiempo; '
              'si no, se libera automáticamente para otros clientes.',
              color: AppColors.azul,
              icono: Icons.timer_outlined,
            ),
            if (widget.requiereReceta) ...[
              const SizedBox(height: 8),
              const Aviso(
                'Este medicamento requiere receta médica. Llévala al recogerlo.',
                color: Color(0xFFB7791F),
                icono: Icons.medical_information_outlined,
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Aviso(_error!),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _cargando ? null : _confirmar,
              child: _cargando
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                    )
                  : const Text('Separar y continuar al pago'),
            ),
          ],
        ),
      ),
    );
  }
}
