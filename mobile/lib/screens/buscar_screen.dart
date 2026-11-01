import 'dart:async';

import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/medicamentos_service.dart';
import '../theme/app_theme.dart';
import '../widgets/estado_vacio.dart';
import '../widgets/medicamento_card.dart';

enum _Estado { inicial, cargando, resultados, vacio, error }

/// Búsqueda de medicamentos (HU03) con orden y filtros (HU16).
class BuscarScreen extends StatefulWidget {
  const BuscarScreen({super.key, MedicamentosService? servicio}) : _servicio = servicio;

  final MedicamentosService? _servicio;

  @override
  State<BuscarScreen> createState() => BuscarScreenState();
}

class BuscarScreenState extends State<BuscarScreen> {
  static const Map<String, String> _ordenes = {
    'precio_asc': 'Menor precio',
    'precio_desc': 'Mayor precio',
    'disponibilidad': 'Disponibles primero',
  };

  final _controller = TextEditingController();
  final _foco = FocusNode();
  late final MedicamentosService _servicio = widget._servicio ?? MedicamentosService();
  Timer? _debounce;

  _Estado _estado = _Estado.inicial;
  ResultadoBusqueda? _resultado;
  String _error = '';
  String _orden = 'relevancia';
  bool _soloStock = false;
  int _peticion = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _foco.dispose();
    super.dispose();
  }

  /// La usa la pantalla de inicio para lanzar una búsqueda.
  void buscar(String consulta) {
    _controller.text = consulta;
    _controller.selection = TextSelection.collapsed(offset: consulta.length);
    if (consulta.trim().length >= 2) {
      _ejecutar();
    } else {
      setState(() => _estado = _Estado.inicial);
      WidgetsBinding.instance.addPostFrameCallback((_) => _foco.requestFocus());
    }
  }

  // HU03: busca sola cuando hay más de 3 caracteres; con menos, espera al botón de buscar del teclado.
  void _alEscribir(String texto) {
    setState(() {});
    _debounce?.cancel();
    final limpio = texto.trim();

    if (limpio.isEmpty) {
      _peticion++;
      setState(() => _estado = _Estado.inicial);
    } else if (limpio.length > 3) {
      _debounce = Timer(const Duration(milliseconds: 450), _ejecutar);
    }
  }

  void _borrar() {
    _debounce?.cancel();
    _controller.clear();
    _peticion++;
    setState(() => _estado = _Estado.inicial);
    _foco.requestFocus();
  }

  void _limpiarFiltros() {
    setState(() {
      _orden = 'relevancia';
      _soloStock = false;
    });
    _reejecutar();
  }

  void _reejecutar() {
    if (_controller.text.trim().length >= 2) _ejecutar();
  }

  Future<void> _ejecutar() async {
    final q = _controller.text.trim();
    if (q.length < 2) return;

    final id = ++_peticion;
    setState(() => _estado = _Estado.cargando);

    try {
      final resultado = await _servicio.buscar(q: q, orden: _orden, soloStock: _soloStock);
      if (!mounted || id != _peticion) return;
      setState(() {
        _resultado = resultado;
        _estado = resultado.medicamentos.isEmpty ? _Estado.vacio : _Estado.resultados;
      });
    } on ApiException catch (e) {
      if (!mounted || id != _peticion) return;
      setState(() {
        _error = e.mensaje;
        _estado = _Estado.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Buscar medicamentos')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _controller,
              focusNode: _foco,
              textInputAction: TextInputAction.search,
              onChanged: _alEscribir,
              onSubmitted: (_) => _ejecutar(),
              decoration: InputDecoration(
                hintText: 'Nombre o principio activo',
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                border: bordeRedondeado(),
                enabledBorder: bordeRedondeado(),
                focusedBorder: bordeRedondeado(color: AppColors.azul, ancho: 2),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _controller.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        tooltip: 'Borrar',
                        onPressed: _borrar,
                      ),
              ),
            ),
          ),
          _filtros(),
          Expanded(child: _cuerpo()),
        ],
      ),
    );
  }

  Widget _filtros() {
    final filtrosApi = _resultado?.filtrosActivos ?? 0;
    final hayAlgoQueLimpiar = _soloStock || _orden != 'relevancia';

    return Column(
      children: [
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            children: [
              FilterChip(
                label: const Text('Solo con stock'),
                selected: _soloStock,
                onSelected: (valor) {
                  setState(() => _soloStock = valor);
                  _reejecutar();
                },
              ),
              for (final entrada in _ordenes.entries) ...[
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text(entrada.value),
                  selected: _orden == entrada.key,
                  onSelected: (valor) {
                    setState(() => _orden = valor ? entrada.key : 'relevancia');
                    _reejecutar();
                  },
                ),
              ],
            ],
          ),
        ),
        if (hayAlgoQueLimpiar)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                if (filtrosApi > 0)
                  Text(
                    filtrosApi == 1 ? '1 filtro activo' : '$filtrosApi filtros activos',
                    style: const TextStyle(color: AppColors.textoSuave),
                  ),
                const Spacer(),
                TextButton(onPressed: _limpiarFiltros, child: const Text('Limpiar filtros')),
              ],
            ),
          ),
      ],
    );
  }

  Widget _cuerpo() {
    switch (_estado) {
      case _Estado.inicial:
        final escribiendo = _controller.text.trim().isNotEmpty;
        return EstadoVacio(
          icono: Icons.medication_outlined,
          titulo: 'Busca por nombre o principio activo',
          mensaje: escribiendo
              ? 'Escribe al menos 4 letras o pulsa el botón de buscar del teclado.'
              : 'Por ejemplo: Panadol o Paracetamol.',
        );
      case _Estado.cargando:
        return const Center(child: CircularProgressIndicator());
      case _Estado.error:
        return EstadoVacio(
          icono: Icons.wifi_off_outlined,
          titulo: 'No pudimos buscar',
          mensaje: _error,
          accion: FilledButton(onPressed: _ejecutar, child: const Text('Reintentar')),
        );
      case _Estado.vacio:
        return EstadoVacio(
          icono: Icons.search_off_outlined,
          titulo: _resultado?.mensaje ?? 'No se encontraron resultados',
          mensaje: _resultado?.sugerencia,
          accion: (_soloStock || _orden != 'relevancia')
              ? OutlinedButton(onPressed: _limpiarFiltros, child: const Text('Limpiar filtros'))
              : null,
        );
      case _Estado.resultados:
        final lista = _resultado?.medicamentos ?? [];
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          itemCount: lista.length + 1,
          separatorBuilder: (context, indice) => const SizedBox(height: 10),
          itemBuilder: (context, indice) {
            if (indice == 0) {
              final n = lista.length;
              return Text(
                '$n resultado${n == 1 ? '' : 's'}',
                style: const TextStyle(color: AppColors.textoSuave),
              );
            }
            return MedicamentoCard(medicamento: lista[indice - 1]);
          },
        );
    }
  }
}
