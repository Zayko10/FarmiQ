import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/reserva.dart';
import '../services/api_client.dart';
import '../services/reservas_service.dart';
import '../theme/app_theme.dart';
import '../utils/formato.dart';
import '../widgets/comunes.dart';

/// Reserva con cuenta regresiva de 15 minutos, pago y código de retiro.
class ReservaDetalleScreen extends StatefulWidget {
  const ReservaDetalleScreen({super.key, required this.reserva});

  final Reserva reserva;

  @override
  State<ReservaDetalleScreen> createState() => _ReservaDetalleScreenState();
}

class _ReservaDetalleScreenState extends State<ReservaDetalleScreen> {
  final _servicio = ReservasService();

  late Reserva _reserva = widget.reserva;
  Timer? _reloj;
  bool _consultando = false;
  bool _procesando = false;
  String? _error;
  String _metodo = 'tarjeta';

  final _numero = TextEditingController();
  final _vencimiento = TextEditingController();
  final _cvv = TextEditingController();
  final _celular = TextEditingController();

  @override
  void initState() {
    super.initState();
    _reloj = Timer.periodic(const Duration(seconds: 1), (_) => _tic());
    _refrescar();
  }

  @override
  void dispose() {
    _reloj?.cancel();
    _numero.dispose();
    _vencimiento.dispose();
    _cvv.dispose();
    _celular.dispose();
    super.dispose();
  }

  void _tic() {
    if (!mounted || !_reserva.pendiente) return;
    if (_reserva.segundosAhora <= 0) {
      // Se acabó el tiempo: la API ya liberó (o liberará en segundos) el stock
      _refrescar();
    }
    setState(() {});
  }

  Future<void> _refrescar() async {
    if (_consultando) return;
    _consultando = true;
    try {
      final r = await _servicio.obtener(_reserva.id);
      if (mounted) setState(() => _reserva = r);
    } on ApiException {
      // Se mantiene lo que ya se ve
    } finally {
      _consultando = false;
    }
  }

  DatosPago? _datosDePago() {
    if (_metodo == 'tarjeta') {
      final numero = _numero.text.replaceAll(' ', '');
      if (numero.length < 13) {
        setState(() => _error = 'Escribe el número completo de tu tarjeta.');
        return null;
      }
      if (!RegExp(r'^(0[1-9]|1[0-2])/\d{2}$').hasMatch(_vencimiento.text)) {
        setState(() => _error = 'El vencimiento debe tener el formato MM/AA.');
        return null;
      }
      if (_cvv.text.length < 3) {
        setState(() => _error = 'Escribe el código de seguridad (CVV).');
        return null;
      }
      return DatosPago.tarjeta(numero: numero, vencimiento: _vencimiento.text, cvv: _cvv.text);
    }
    if (!RegExp(r'^9\d{8}$').hasMatch(_celular.text)) {
      setState(() => _error = 'El celular debe tener 9 dígitos y empezar con 9.');
      return null;
    }
    return DatosPago.billetera(metodo: _metodo, celular: _celular.text);
  }

  Future<void> _pagar() async {
    setState(() => _error = null);
    final pago = _datosDePago();
    if (pago == null) return;

    setState(() => _procesando = true);
    try {
      final r = await _servicio.pagar(_reserva.id, pago);
      if (!mounted) return;
      setState(() {
        _reserva = r.reserva;
        _procesando = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _procesando = false;
        _error = e.mensaje;
      });
      if (e.codigo == 410 || e.codigo == 409) _refrescar();
    }
  }

  Future<void> _cancelar() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Cancelar la reserva?'),
        content: const Text('El producto se liberará de inmediato.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sí, cancelar')),
        ],
      ),
    );
    if (confirmar != true) return;

    setState(() => _procesando = true);
    try {
      final r = await _servicio.cancelar(_reserva.id);
      if (!mounted) return;
      setState(() {
        _reserva = r.reserva;
        _procesando = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _procesando = false;
        _error = e.mensaje;
      });
    }
  }

  InputDecoration _campo(String etiqueta, {String? ayuda}) => InputDecoration(
        labelText: etiqueta,
        helperText: ayuda,
        filled: true,
        fillColor: Colors.white,
        counterText: '',
        border: bordeRedondeado(),
        enabledBorder: bordeRedondeado(),
      );

  @override
  Widget build(BuildContext context) {
    final r = _reserva;
    final textos = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Mi reserva')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TarjetaBase(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(r.medicamentoNombre, style: textos.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    ),
                    EtiquetaChip(r.estadoTexto, color: _colorEstado(r.estado)),
                  ],
                ),
                if (r.descripcionProducto.isNotEmpty)
                  Text(r.descripcionProducto, style: textos.bodySmall?.copyWith(color: AppColors.textoSuave)),
                const Divider(height: 24),
                _fila('Botica', r.boticaNombre),
                _fila('Dirección', r.boticaDireccion),
                _fila('Cantidad', '${r.cantidad} × ${soles(r.precioUnitario)}'),
                _fila('Total', soles(r.total), fuerte: true),
                if (r.metodoPago != null) _fila('Pagado con', r.metodoPago!),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (r.pendiente) ..._pendiente(context),
          if (r.pagada || r.estado == 'entregada') _codigo(context),
          if (r.estado == 'expirada')
            const Aviso(
              'El tiempo para pagar terminó y el producto fue liberado. Puedes volver a reservarlo si aún hay stock.',
              color: AppColors.alerta,
              icono: Icons.timer_off_outlined,
            ),
          if (r.estado == 'cancelada')
            const Aviso('Reservaste y cancelaste este pedido. El producto fue liberado.',
                color: AppColors.textoSuave, icono: Icons.cancel_outlined),
        ],
      ),
    );
  }

  Color _colorEstado(String estado) {
    switch (estado) {
      case 'pendiente_pago':
        return const Color(0xFFB7791F);
      case 'pagada':
      case 'entregada':
        return AppColors.verde;
      case 'expirada':
        return AppColors.alerta;
      default:
        return AppColors.textoSuave;
    }
  }

  Widget _fila(String etiqueta, String valor, {bool fuerte = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 92, child: Text(etiqueta, style: const TextStyle(color: AppColors.textoSuave))),
          Expanded(
            child: Text(
              valor,
              style: TextStyle(fontWeight: fuerte ? FontWeight.w800 : FontWeight.w500, fontSize: fuerte ? 18 : 14),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _pendiente(BuildContext context) {
    final segundos = _reserva.segundosAhora;
    final urgente = segundos <= 120;
    final color = urgente ? AppColors.alerta : AppColors.azul;
    final progreso = (segundos / (15 * 60)).clamp(0.0, 1.0);

    return [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text('Tu producto está separado. Paga en', style: TextStyle(color: color)),
            const SizedBox(height: 4),
            Text(
              mmss(segundos),
              style: TextStyle(fontSize: 44, fontWeight: FontWeight.w800, color: color, letterSpacing: 2),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: progreso, color: color, backgroundColor: color.withValues(alpha: 0.15)),
            const SizedBox(height: 8),
            const Text(
              'Si no pagas antes de que termine, el producto se libera automáticamente.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textoSuave),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      Text('Método de pago', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        children: [
          for (final m in const {'tarjeta': 'Tarjeta', 'yape': 'Yape', 'plin': 'Plin'}.entries)
            ChoiceChip(
              label: Text(m.value),
              selected: _metodo == m.key,
              onSelected: _procesando ? null : (_) => setState(() => _metodo = m.key),
            ),
        ],
      ),
      const SizedBox(height: 12),
      if (_metodo == 'tarjeta') ...[
        TextField(
          controller: _numero,
          keyboardType: TextInputType.number,
          maxLength: 19,
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9 ]'))],
          decoration: _campo('Número de tarjeta'),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _vencimiento,
                keyboardType: TextInputType.number,
                maxLength: 5,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9/]'))],
                decoration: _campo('Vence (MM/AA)'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _cvv,
                keyboardType: TextInputType.number,
                maxLength: 4,
                obscureText: true,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: _campo('CVV'),
              ),
            ),
          ],
        ),
      ] else
        TextField(
          controller: _celular,
          keyboardType: TextInputType.phone,
          maxLength: 9,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: _campo('Celular de tu cuenta ${_metodo == 'yape' ? 'Yape' : 'Plin'}'),
        ),
      const SizedBox(height: 4),
      const Text(
        'Pago simulado para pruebas: una tarjeta que termina en 0000 o un celular que termina en 000 será rechazado.',
        style: TextStyle(fontSize: 12, color: AppColors.textoSuave),
      ),
      if (_error != null) ...[
        const SizedBox(height: 10),
        Aviso(_error!),
      ],
      const SizedBox(height: 14),
      FilledButton(
        onPressed: _procesando ? null : _pagar,
        child: _procesando
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
              )
            : Text('Pagar ${soles(_reserva.total)}'),
      ),
      TextButton(
        onPressed: _procesando ? null : _cancelar,
        child: const Text('Cancelar reserva'),
      ),
    ];
  }

  Widget _codigo(BuildContext context) {
    final r = _reserva;
    final entregada = r.estado == 'entregada';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.verde.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.verde.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          Icon(entregada ? Icons.verified_outlined : Icons.check_circle_outline, color: AppColors.verde, size: 36),
          const SizedBox(height: 6),
          Text(
            entregada ? 'Pedido entregado' : 'Pago confirmado',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (r.codigo != null) ...[
            const SizedBox(height: 10),
            const Text('Tu código de retiro', style: TextStyle(color: AppColors.textoSuave)),
            const SizedBox(height: 4),
            InkWell(
              onTap: () {
                Clipboard.setData(ClipboardData(text: r.codigo!));
                mostrarMensaje(context, 'Código copiado');
              },
              child: Text(
                r.codigo!,
                style: const TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 6,
                  color: AppColors.verde,
                ),
              ),
            ),
          ],
          if (!entregada) ...[
            const SizedBox(height: 8),
            Text(
              'Preséntalo en ${r.boticaNombre} para recoger tu pedido.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textoSuave),
            ),
            if (r.requiereReceta)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Recuerda llevar tu receta médica.',
                  style: TextStyle(color: Color(0xFFB7791F), fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
