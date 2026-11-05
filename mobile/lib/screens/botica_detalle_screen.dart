import 'dart:async';

import 'package:flutter/material.dart';

import '../models/botica.dart';
import '../services/api_client.dart';
import '../services/boticas_service.dart';
import '../theme/app_theme.dart';
import '../utils/formato.dart';
import '../widgets/comunes.dart';
import '../widgets/estado_vacio.dart';
import '../widgets/reservar_sheet.dart';
import 'detalle_screen.dart';

/// Una botica: sus datos y todos sus productos con stock y precio; permite reservar desde aquí.
class BoticaDetalleScreen extends StatefulWidget {
  const BoticaDetalleScreen({super.key, required this.botica});

  final Botica botica;

  @override
  State<BoticaDetalleScreen> createState() => _BoticaDetalleScreenState();
}

class _BoticaDetalleScreenState extends State<BoticaDetalleScreen> {
  final _servicio = BoticasService();
  final _busqueda = TextEditingController();
  Timer? _espera;

  List<ProductoBotica>? _productos;
  String? _error;
  bool _soloStock = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _espera?.cancel();
    _busqueda.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() => _error = null);
    try {
      final lista = await _servicio.productos(
        widget.botica.id,
        q: _busqueda.text,
        soloStock: _soloStock,
      );
      if (!mounted) return;
      setState(() => _productos = lista);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.mensaje);
    }
  }

  void _alEscribir(String _) {
    _espera?.cancel();
    _espera = Timer(const Duration(milliseconds: 350), _cargar);
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.botica;
    final productos = _productos;

    Widget lista;
    if (_error != null) {
      lista = EstadoVacio(
        icono: Icons.wifi_off_outlined,
        titulo: 'No pudimos cargar los productos',
        mensaje: _error,
        accion: FilledButton(onPressed: _cargar, child: const Text('Reintentar')),
      );
    } else if (productos == null) {
      lista = const Center(child: CircularProgressIndicator());
    } else if (productos.isEmpty) {
      lista = const EstadoVacio(
        icono: Icons.search_off,
        titulo: 'No encontramos productos',
        mensaje: 'Prueba con otro nombre o quita el filtro "Solo con stock".',
      );
    } else {
      lista = RefreshIndicator(
        onRefresh: _cargar,
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          itemCount: productos.length,
          separatorBuilder: (context, i) => const SizedBox(height: 8),
          itemBuilder: (context, i) => _fila(productos[i]),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(b.nombre, overflow: TextOverflow.ellipsis)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TarjetaBase(
              child: Row(
                children: [
                  const Icon(Icons.place_outlined, color: AppColors.azul),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(b.direccion, style: const TextStyle(fontWeight: FontWeight.w600)),
                        if (b.distanciaKm != null)
                          Text('A ${distanciaTexto(b.distanciaKm)} de ti', style: const TextStyle(color: AppColors.textoSuave)),
                        if (b.telefono != null) Text('Tel. ${b.telefono}'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _busqueda,
              onChanged: _alEscribir,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Buscar en esta botica',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: bordeRedondeado(),
                enabledBorder: bordeRedondeado(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FilterChip(
                label: const Text('Solo con stock'),
                selected: _soloStock,
                onSelected: (v) {
                  setState(() => _soloStock = v);
                  _cargar();
                },
              ),
            ),
          ),
          Expanded(child: lista),
        ],
      ),
    );
  }

  Widget _fila(ProductoBotica p) {
    final hayStock = p.stock > 0;
    return TarjetaBase(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => DetalleScreen(medicamentoId: p.id, nombre: p.nombre)),
      ),
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
                    EtiquetaChip(
                      hayStock ? (p.stock <= 3 ? 'Quedan ${p.stock}' : '${p.stock} disponibles') : 'Sin stock',
                      color: hayStock ? (p.stock <= 3 ? const Color(0xFFB7791F) : AppColors.verde) : AppColors.alerta,
                    ),
                    if (p.esGenerico) const EtiquetaChip('Genérico', color: AppColors.verde),
                    if (p.requiereReceta) const EtiquetaChip('Con receta', color: Color(0xFFB7791F)),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(soles(p.precio), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: AppColors.azul)),
              const SizedBox(height: 4),
              if (hayStock)
                SizedBox(
                  height: 34,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 34),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                    onPressed: () async {
                      await mostrarReserva(
                        context,
                        boticaId: widget.botica.id,
                        boticaNombre: widget.botica.nombre,
                        medicamentoId: p.id,
                        medicamentoNombre: p.nombre,
                        precio: p.precio,
                        stock: p.stock,
                        requiereReceta: p.requiereReceta,
                      );
                      if (mounted) _cargar();
                    },
                    child: const Text('Reservar'),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
