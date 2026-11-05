import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/inventario.dart';
import '../../services/api_client.dart';
import '../../services/panel_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/formato.dart';
import '../../widgets/comunes.dart';
import '../../widgets/estado_vacio.dart';
import 'agregar_producto_screen.dart';
import 'nuevo_producto_screen.dart';

const _ambar = Color(0xFFB7791F);

/// HU27: inventario de la botica. Se actualiza el stock y el precio de cada producto.
class PanelInventarioScreen extends StatefulWidget {
  const PanelInventarioScreen({super.key});

  @override
  State<PanelInventarioScreen> createState() => PanelInventarioScreenState();
}

class PanelInventarioScreenState extends State<PanelInventarioScreen> {
  static const _filtros = {
    'todos': 'Todos',
    'sin_stock': 'Sin stock',
    'bajo': 'Stock bajo',
    'desactualizados': 'Sin actualizar',
  };

  final _servicio = PanelService();
  final _busqueda = TextEditingController();
  Timer? _espera;

  List<ItemInventario>? _items;
  String _filtro = 'todos';
  String? _error;

  @override
  void initState() {
    super.initState();
    cargar();
  }

  @override
  void dispose() {
    _espera?.cancel();
    _busqueda.dispose();
    super.dispose();
  }

  void aplicarFiltro(String filtro) {
    setState(() => _filtro = filtro);
    cargar();
  }

  Future<void> cargar() async {
    try {
      final lista = await _servicio.inventario(q: _busqueda.text, filtro: _filtro);
      if (!mounted) return;
      setState(() {
        _items = lista;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.mensaje);
    }
  }

  void _alEscribir(String _) {
    _espera?.cancel();
    _espera = Timer(const Duration(milliseconds: 350), cargar);
  }

  Future<void> _editar(ItemInventario item) async {
    final actualizado = await showModalBottomSheet<ItemInventario>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _EditarSheet(item: item, servicio: _servicio),
      ),
    );
    if (actualizado != null && mounted) {
      mostrarMensaje(context, '${actualizado.nombre} actualizado');
      cargar();
    }
  }

  Future<void> _agregar() async {
    final opcion = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.search),
              title: const Text('Agregar del catálogo'),
              subtitle: const Text('El producto ya existe en FarmiQ: solo indica tu stock y precio'),
              onTap: () => Navigator.pop(ctx, 'catalogo'),
            ),
            ListTile(
              leading: const Icon(Icons.add_box_outlined),
              title: const Text('Crear producto nuevo'),
              subtitle: const Text('Registra un producto con su información completa'),
              onTap: () => Navigator.pop(ctx, 'nuevo'),
            ),
          ],
        ),
      ),
    );
    if (opcion == null || !mounted) return;

    final cambio = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => opcion == 'catalogo' ? const AgregarProductoScreen() : const NuevoProductoScreen(),
      ),
    );
    if (cambio == true && mounted) cargar();
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;

    Widget lista;
    if (_error != null && items == null) {
      lista = EstadoVacio(
        icono: Icons.wifi_off_outlined,
        titulo: 'No pudimos cargar el inventario',
        mensaje: _error,
        accion: FilledButton(onPressed: cargar, child: const Text('Reintentar')),
      );
    } else if (items == null) {
      lista = const Center(child: CircularProgressIndicator());
    } else if (items.isEmpty) {
      lista = const EstadoVacio(
        icono: Icons.inventory_2_outlined,
        titulo: 'No hay productos con ese filtro',
        mensaje: 'Cambia el filtro o agrega productos con el botón de abajo.',
      );
    } else {
      lista = RefreshIndicator(
        onRefresh: cargar,
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
          itemCount: items.length,
          separatorBuilder: (context, i) => const SizedBox(height: 8),
          itemBuilder: (context, i) => _fila(items[i]),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Inventario')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _agregar,
        backgroundColor: Theme.of(context).colorScheme.secondary,
        foregroundColor: Theme.of(context).colorScheme.onSecondary,
        icon: const Icon(Icons.add),
        label: const Text('Agregar producto'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _busqueda,
              onChanged: _alEscribir,
              decoration: InputDecoration(
                hintText: 'Buscar por nombre o principio activo',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: bordeRedondeado(),
                enabledBorder: bordeRedondeado(),
              ),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              children: [
                for (final f in _filtros.entries) ...[
                  ChoiceChip(
                    label: Text(f.value),
                    selected: _filtro == f.key,
                    onSelected: (_) => aplicarFiltro(f.key),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          Expanded(child: lista),
        ],
      ),
    );
  }

  Widget _fila(ItemInventario p) {
    final sinStock = p.disponible <= 0;
    final bajo = !sinStock && p.disponible <= 5;
    final colorStock = sinStock ? AppColors.alerta : (bajo ? _ambar : AppColors.verde);

    return TarjetaBase(
      onTap: () => _editar(p),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.nombre, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                Text(p.descripcion, style: const TextStyle(color: AppColors.textoSuave, fontSize: 12)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    EtiquetaChip('Físico ${p.stock}', color: AppColors.textoSuave),
                    if (p.stockReservado > 0) EtiquetaChip('Reservado ${p.stockReservado}', color: _ambar),
                    if (p.desactualizado)
                      EtiquetaChip('Actualizado ${tiempoRelativo(p.minutosDesdeActualizacion)}', color: _ambar),
                    if (p.requiereReceta) const EtiquetaChip('Con receta', color: AppColors.textoSuave),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${p.disponible}',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: colorStock),
              ),
              Text('disponibles', style: TextStyle(fontSize: 11, color: colorStock)),
              const SizedBox(height: 2),
              Text(soles(p.precio), style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Hoja para cambiar el stock y el precio de un producto.
class _EditarSheet extends StatefulWidget {
  const _EditarSheet({required this.item, required this.servicio});

  final ItemInventario item;
  final PanelService servicio;

  @override
  State<_EditarSheet> createState() => _EditarSheetState();
}

class _EditarSheetState extends State<_EditarSheet> {
  late final TextEditingController _stock = TextEditingController(text: '${widget.item.stock}');
  late final TextEditingController _precio = TextEditingController(text: widget.item.precio.toStringAsFixed(2));
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _stock.dispose();
    _precio.dispose();
    super.dispose();
  }

  void _sumar(int delta) {
    final actual = int.tryParse(_stock.text) ?? 0;
    final nuevo = actual + delta;
    _stock.text = '${nuevo < 0 ? 0 : nuevo}';
  }

  Future<void> _guardar() async {
    final stock = int.tryParse(_stock.text.trim());
    final precio = double.tryParse(_precio.text.trim().replaceAll(',', '.'));
    if (stock == null || stock < 0) {
      setState(() => _error = 'El stock debe ser un número entero, 0 o mayor.');
      return;
    }
    if (precio == null || precio < 0) {
      setState(() => _error = 'El precio debe ser un número válido.');
      return;
    }

    final navegador = Navigator.of(context);
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      // Se envía siempre ambos valores: refrescar el inventario también cuenta como "actualizado"
      final actualizado = await widget.servicio.actualizar(widget.item.medicamentoId, stock: stock, precio: precio);
      navegador.pop(actualizado);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _error = e.mensaje;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final i = widget.item;
    final textos = Theme.of(context).textTheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(i.nombre, style: textos.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            Text(i.descripcion, style: textos.bodySmall?.copyWith(color: AppColors.textoSuave)),
            if (i.stockReservado > 0) ...[
              const SizedBox(height: 8),
              Aviso(
                'Hay ${i.stockReservado} unidades reservadas por clientes. El stock físico no puede ser menor a esa cantidad.',
                color: _ambar,
                icono: Icons.lock_clock,
              ),
            ],
            const SizedBox(height: 16),
            Text('Stock físico en la botica', style: textos.labelLarge),
            const SizedBox(height: 6),
            Row(
              children: [
                IconButton.outlined(
                  onPressed: _guardando ? null : () => _sumar(-1),
                  icon: const Icon(Icons.remove),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _stock,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: textos.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                    decoration: InputDecoration(border: bordeRedondeado(), enabledBorder: bordeRedondeado()),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  onPressed: _guardando ? null : () => _sumar(1),
                  icon: const Icon(Icons.add),
                ),
                const SizedBox(width: 4),
                TextButton(onPressed: _guardando ? null : () => _sumar(10), child: const Text('+10')),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _precio,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Precio (S/)',
                prefixIcon: const Icon(Icons.sell_outlined),
                border: bordeRedondeado(),
                enabledBorder: bordeRedondeado(),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Aviso(_error!),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _guardando ? null : _guardar,
              child: _guardando
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                    )
                  : const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}
