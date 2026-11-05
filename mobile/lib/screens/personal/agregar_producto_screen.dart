import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/inventario.dart';
import '../../services/api_client.dart';
import '../../services/panel_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/comunes.dart';
import '../../widgets/estado_vacio.dart';

/// Busca un producto que ya existe en el catálogo de FarmiQ y lo agrega al inventario de la botica.
class AgregarProductoScreen extends StatefulWidget {
  const AgregarProductoScreen({super.key});

  @override
  State<AgregarProductoScreen> createState() => _AgregarProductoScreenState();
}

class _AgregarProductoScreenState extends State<AgregarProductoScreen> {
  final _servicio = PanelService();
  final _busqueda = TextEditingController();
  Timer? _espera;

  List<ProductoCatalogo>? _resultados;
  bool _buscando = false;
  String? _error;

  @override
  void dispose() {
    _espera?.cancel();
    _busqueda.dispose();
    super.dispose();
  }

  void _alEscribir(String texto) {
    _espera?.cancel();
    if (texto.trim().length < 2) {
      setState(() => _resultados = null);
      return;
    }
    _espera = Timer(const Duration(milliseconds: 400), _buscar);
  }

  Future<void> _buscar() async {
    setState(() {
      _buscando = true;
      _error = null;
    });
    try {
      final r = await _servicio.buscarCatalogo(_busqueda.text);
      if (!mounted) return;
      setState(() {
        _resultados = r;
        _buscando = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.mensaje;
        _buscando = false;
      });
    }
  }

  Future<void> _agregar(ProductoCatalogo p) async {
    final navegador = Navigator.of(context);
    final stock = TextEditingController(text: '10');
    final precio = TextEditingController();
    String? error;
    bool guardando = false;

    final agregado = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(p.nombre),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: stock,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Stock inicial'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: precio,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Precio (S/)'),
              ),
              if (error != null) ...[
                const SizedBox(height: 10),
                Text(error!, style: const TextStyle(color: AppColors.alerta)),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(
              onPressed: guardando
                  ? null
                  : () async {
                      final s = int.tryParse(stock.text.trim());
                      final pr = double.tryParse(precio.text.trim().replaceAll(',', '.'));
                      if (s == null || s < 0 || pr == null || pr < 0) {
                        setLocal(() => error = 'Escribe un stock y un precio válidos.');
                        return;
                      }
                      setLocal(() {
                        guardando = true;
                        error = null;
                      });
                      try {
                        await _servicio.agregarAlInventario(p.medicamentoId, stock: s, precio: pr);
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      } on ApiException catch (e) {
                        setLocal(() {
                          guardando = false;
                          error = e.mensaje;
                        });
                      }
                    },
              child: const Text('Agregar'),
            ),
          ],
        ),
      ),
    );

    stock.dispose();
    precio.dispose();
    if (agregado == true && mounted) navegador.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final r = _resultados;

    Widget cuerpo;
    if (_error != null) {
      cuerpo = EstadoVacio(icono: Icons.error_outline, titulo: 'No pudimos buscar', mensaje: _error);
    } else if (r == null) {
      cuerpo = const EstadoVacio(
        icono: Icons.search,
        titulo: 'Busca en el catálogo',
        mensaje: 'Escribe al menos 2 letras del nombre o del principio activo.',
      );
    } else if (r.isEmpty && !_buscando) {
      cuerpo = const EstadoVacio(
        icono: Icons.search_off,
        titulo: 'No hay productos para agregar con ese nombre',
        mensaje: 'Puede que ya lo tengas en tu inventario, o crea un producto nuevo.',
      );
    } else {
      cuerpo = ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: r.length,
        separatorBuilder: (context, i) => const SizedBox(height: 8),
        itemBuilder: (context, i) => TarjetaBase(
          onTap: () => _agregar(r[i]),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r[i].nombre, style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(r[i].descripcion, style: const TextStyle(color: AppColors.textoSuave, fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.add_circle_outline),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Agregar del catálogo')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _busqueda,
              autofocus: true,
              onChanged: _alEscribir,
              decoration: InputDecoration(
                hintText: 'Nombre o principio activo',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: bordeRedondeado(),
                enabledBorder: bordeRedondeado(),
              ),
            ),
          ),
          if (_buscando) const LinearProgressIndicator(),
          Expanded(child: cuerpo),
        ],
      ),
    );
  }
}
