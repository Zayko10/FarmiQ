import 'package:flutter/material.dart';

import '../../services/api_client.dart';
import '../../services/panel_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/comunes.dart';

const _categorias = [
  'Dolor y fiebre',
  'Dolor muscular',
  'Alergias',
  'Digestivo',
  'Tos y gripe',
  'Garganta',
  'Vitaminas',
  'Primeros auxilios',
  'Antibióticos',
  'Diabetes',
  'Presión arterial',
  'Colesterol',
  'Respiratorio',
  'Otros',
];

/// Crea un producto nuevo (con su ficha técnica) y lo deja en el inventario de la botica.
class NuevoProductoScreen extends StatefulWidget {
  const NuevoProductoScreen({super.key});

  @override
  State<NuevoProductoScreen> createState() => _NuevoProductoScreenState();
}

class _NuevoProductoScreenState extends State<NuevoProductoScreen> {
  final _servicio = PanelService();

  final _nombre = TextEditingController();
  final _principio = TextEditingController();
  final _concentracion = TextEditingController();
  final _presentacion = TextEditingController();
  final _laboratorio = TextEditingController();
  final _dosis = TextEditingController();
  final _descripcion = TextEditingController();
  final _indicaciones = TextEditingController();
  final _contraindicaciones = TextEditingController();
  final _efectos = TextEditingController();
  final _stock = TextEditingController(text: '10');
  final _precio = TextEditingController();

  String _categoria = _categorias.first;
  bool _generico = false;
  bool _receta = false;
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [
      _nombre, _principio, _concentracion, _presentacion, _laboratorio, _dosis,
      _descripcion, _indicaciones, _contraindicaciones, _efectos, _stock, _precio,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  InputDecoration _campo(String etiqueta, {String? ayuda}) => InputDecoration(
        labelText: etiqueta,
        helperText: ayuda,
        filled: true,
        fillColor: Colors.white,
        border: bordeRedondeado(),
        enabledBorder: bordeRedondeado(),
      );

  Widget _texto(TextEditingController c, String etiqueta, {String? ayuda, int lineas = 1, TextInputType? teclado}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        minLines: lineas,
        maxLines: lineas,
        keyboardType: teclado,
        decoration: _campo(etiqueta, ayuda: ayuda),
      ),
    );
  }

  Widget _titulo(String t) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 10),
        child: Text(t, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
      );

  Future<void> _guardar() async {
    final obligatorios = {
      'el nombre': _nombre,
      'el principio activo': _principio,
      'la concentración': _concentracion,
      'la presentación': _presentacion,
    };
    for (final e in obligatorios.entries) {
      if (e.value.text.trim().isEmpty) {
        setState(() => _error = 'Escribe ${e.key}.');
        return;
      }
    }
    final stock = int.tryParse(_stock.text.trim());
    final precio = double.tryParse(_precio.text.trim().replaceAll(',', '.'));
    if (stock == null || stock < 0) {
      setState(() => _error = 'El stock debe ser un número entero, 0 o mayor.');
      return;
    }
    if (precio == null || precio < 0) {
      setState(() => _error = 'Escribe un precio válido.');
      return;
    }

    final navegador = Navigator.of(context);
    final mensajero = ScaffoldMessenger.of(context);
    String? opcional(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

    final cuerpo = <String, dynamic>{
      'nombre': _nombre.text.trim(),
      'principio_activo': _principio.text.trim(),
      'concentracion': _concentracion.text.trim(),
      'presentacion': _presentacion.text.trim(),
      'categoria': _categoria,
      'es_generico': _generico,
      'requiere_receta': _receta,
      'stock': stock,
      'precio': precio,
      'laboratorio': opcional(_laboratorio),
      'dosis_referencial': opcional(_dosis),
      'descripcion': opcional(_descripcion),
      'indicaciones': opcional(_indicaciones),
      'contraindicaciones': opcional(_contraindicaciones),
      'efectos_adversos': opcional(_efectos),
    }..removeWhere((clave, valor) => valor == null);

    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      final item = await _servicio.crearProducto(cuerpo);
      mensajero.showSnackBar(SnackBar(content: Text('${item.nombre} agregado a tu inventario')));
      navegador.pop(true);
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
    return Scaffold(
      appBar: AppBar(title: const Text('Producto nuevo')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _titulo('Datos del producto'),
          _texto(_nombre, 'Nombre comercial *'),
          _texto(_principio, 'Principio activo *'),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _texto(_concentracion, 'Concentración *', ayuda: 'Ej.: 500 mg')),
              const SizedBox(width: 10),
              Expanded(child: _texto(_presentacion, 'Presentación *', ayuda: 'Ej.: Tabletas x 20')),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: DropdownButtonFormField<String>(
              value: _categoria,
              decoration: _campo('Categoría *'),
              items: [for (final c in _categorias) DropdownMenuItem(value: c, child: Text(c))],
              onChanged: (v) => setState(() => _categoria = v ?? _categoria),
            ),
          ),
          _texto(_laboratorio, 'Laboratorio (opcional)'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Es genérico'),
            value: _generico,
            onChanged: (v) => setState(() => _generico = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Requiere receta médica'),
            value: _receta,
            onChanged: (v) => setState(() => _receta = v),
          ),
          _titulo('Ficha técnica (opcional)'),
          const Text(
            'Esta información la verán los clientes. Si dejas la dosis vacía, la ficha figurará como "no disponible".',
            style: TextStyle(color: AppColors.textoSuave, fontSize: 12),
          ),
          const SizedBox(height: 10),
          _texto(_dosis, 'Dosis referencial', lineas: 2),
          _texto(_descripcion, 'Descripción', lineas: 2),
          _texto(_indicaciones, 'Para qué se usa', lineas: 2),
          _texto(_contraindicaciones, 'Contraindicaciones', lineas: 2),
          _texto(_efectos, 'Efectos adversos', lineas: 2),
          _titulo('Stock y precio en tu botica'),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _texto(_stock, 'Stock inicial *', teclado: TextInputType.number)),
              const SizedBox(width: 10),
              Expanded(
                child: _texto(_precio, 'Precio (S/) *', teclado: const TextInputType.numberWithOptions(decimal: true)),
              ),
            ],
          ),
          if (_error != null) ...[
            Aviso(_error!),
            const SizedBox(height: 12),
          ],
          FilledButton(
            onPressed: _guardando ? null : _guardar,
            child: _guardando
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                  )
                : const Text('Guardar producto'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
