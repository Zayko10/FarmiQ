import 'package:flutter/material.dart';

import '../models/detalle.dart';
import '../services/api_client.dart';
import '../services/medicamentos_service.dart';
import '../services/sesion.dart';
import '../services/ubicacion_service.dart';
import '../theme/app_theme.dart';
import '../utils/formato.dart';
import '../utils/navegacion.dart';
import '../widgets/comunes.dart';
import '../widgets/estado_vacio.dart';
import '../widgets/reservar_sheet.dart';

/// Detalle de un medicamento: ficha técnica, boticas con stock (con distancia) y reserva.
class DetalleScreen extends StatefulWidget {
  const DetalleScreen({super.key, required this.medicamentoId, this.nombre});

  final String medicamentoId;
  final String? nombre;

  @override
  State<DetalleScreen> createState() => _DetalleScreenState();
}

class _DetalleScreenState extends State<DetalleScreen> {
  final _servicio = MedicamentosService();

  DetalleMedicamento? _detalle;
  List<DisponibilidadBotica>? _boticas;
  List<Alternativa> _alternativas = const [];
  String? _error;
  String? _avisoUbicacion;
  bool _buscandoUbicacion = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _error = null);
    try {
      final resultados = await Future.wait<Object>([
        _servicio.detalle(widget.medicamentoId),
        _servicio.disponibilidad(widget.medicamentoId, posicion: UbicacionService.ultima),
        _servicio.alternativas(widget.medicamentoId).catchError((_) => <Alternativa>[]),
      ]);
      if (!mounted) return;
      setState(() {
        _detalle = resultados[0] as DetalleMedicamento;
        _boticas = resultados[1] as List<DisponibilidadBotica>;
        _alternativas = resultados[2] as List<Alternativa>;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.mensaje);
    }
  }

  Future<void> _usarUbicacion() async {
    setState(() {
      _buscandoUbicacion = true;
      _avisoUbicacion = null;
    });
    final r = await UbicacionService.obtener();
    if (!mounted) return;
    if (r.posicion == null) {
      setState(() {
        _buscandoUbicacion = false;
        _avisoUbicacion = r.error;
      });
      if (r.abrirAjustes) await UbicacionService.abrirAjustes();
      return;
    }
    try {
      final boticas = await _servicio.disponibilidad(widget.medicamentoId, posicion: r.posicion);
      if (!mounted) return;
      setState(() {
        _boticas = boticas;
        _buscandoUbicacion = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _buscandoUbicacion = false;
        _avisoUbicacion = e.mensaje;
      });
    }
  }

  Future<void> _alternarFavorito() async {
    final d = _detalle;
    if (d == null) return;
    if (!Sesion.instancia.autenticado) {
      mostrarMensaje(
        context,
        'Inicia sesión para guardar favoritos.',
        accion: SnackBarAction(label: 'Iniciar sesión', onPressed: () => irAIniciarSesion(context)),
      );
      return;
    }
    final eraFavorito = d.esFavorito ?? false;
    setState(() => _detalle = d.conFavorito(!eraFavorito));
    try {
      if (eraFavorito) {
        await _servicio.quitarFavorito(d.id);
      } else {
        await _servicio.agregarFavorito(d.id);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _detalle = d.conFavorito(eraFavorito));
      mostrarMensaje(context, e.mensaje);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _detalle;

    Widget cuerpo;
    if (_error != null) {
      cuerpo = EstadoVacio(
        icono: Icons.wifi_off_outlined,
        titulo: 'No pudimos cargar el medicamento',
        mensaje: _error,
        accion: FilledButton(onPressed: _cargar, child: const Text('Reintentar')),
      );
    } else if (d == null || _boticas == null) {
      cuerpo = const Center(child: CircularProgressIndicator());
    } else {
      cuerpo = RefreshIndicator(
        onRefresh: _cargar,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            _encabezado(d),
            const SizedBox(height: 20),
            _seccionBoticas(d),
            const SizedBox(height: 20),
            _seccionFicha(d),
            if (_alternativas.isNotEmpty) ...[
              const SizedBox(height: 20),
              _seccionAlternativas(),
            ],
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(d?.nombre ?? widget.nombre ?? 'Medicamento', overflow: TextOverflow.ellipsis),
        actions: [
          if (d != null)
            IconButton(
              tooltip: (d.esFavorito ?? false) ? 'Quitar de favoritos' : 'Guardar en favoritos',
              icon: Icon(
                (d.esFavorito ?? false) ? Icons.favorite : Icons.favorite_border,
                color: (d.esFavorito ?? false) ? AppColors.alerta : null,
              ),
              onPressed: _alternarFavorito,
            ),
        ],
      ),
      body: cuerpo,
    );
  }

  Widget _encabezado(DetalleMedicamento d) {
    final textos = Theme.of(context).textTheme;
    return TarjetaBase(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(d.nombre, style: textos.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(d.subtitulo, style: textos.bodyMedium?.copyWith(color: AppColors.textoSuave)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              EtiquetaChip(d.categoria, color: AppColors.azul),
              if (d.esGenerico) const EtiquetaChip('Genérico', color: AppColors.verde),
              if (d.requiereReceta) const EtiquetaChip('Con receta', color: Color(0xFFB7791F)),
              EtiquetaChip(
                d.disponible ? 'Disponible' : 'Sin stock',
                color: d.disponible ? AppColors.verde : AppColors.alerta,
              ),
            ],
          ),
          if (d.descripcion != null) ...[
            const SizedBox(height: 12),
            Text(d.descripcion!),
          ],
          if (d.laboratorio != null) ...[
            const SizedBox(height: 6),
            Text('Laboratorio: ${d.laboratorio}', style: textos.bodySmall?.copyWith(color: AppColors.textoSuave)),
          ],
          if (d.precioDesde != null) ...[
            const SizedBox(height: 10),
            Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: 'Desde  '),
                  TextSpan(
                    text: soles(d.precioDesde),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 22, color: AppColors.azul),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _titulo(String texto) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(texto, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
      );

  Widget _seccionBoticas(DetalleMedicamento d) {
    final boticas = _boticas ?? const <DisponibilidadBotica>[];
    final conDistancia = boticas.any((b) => b.distanciaKm != null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _titulo('Dónde comprarlo'),
        if (!conDistancia) ...[
          TarjetaBase(
            child: Row(
              children: [
                const Icon(Icons.my_location, color: AppColors.azul),
                const SizedBox(width: 12),
                const Expanded(child: Text('Activa tu ubicación para ver las boticas más cercanas a ti.')),
                TextButton(
                  onPressed: _buscandoUbicacion ? null : _usarUbicacion,
                  child: _buscandoUbicacion
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Activar'),
                ),
              ],
            ),
          ),
          if (_avisoUbicacion != null) ...[
            const SizedBox(height: 8),
            Aviso(_avisoUbicacion!),
          ],
          const SizedBox(height: 10),
        ],
        if (boticas.isEmpty)
          const Aviso(
            'Ninguna botica afiliada tiene stock por ahora. Revisa los genéricos equivalentes más abajo.',
            color: AppColors.alerta,
            icono: Icons.inventory_2_outlined,
          )
        else
          for (final b in boticas) ...[
            _tarjetaBotica(d, b),
            const SizedBox(height: 10),
          ],
      ],
    );
  }

  Widget _tarjetaBotica(DetalleMedicamento d, DisponibilidadBotica b) {
    final poco = b.stock <= 3;
    return TarjetaBase(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(b.nombre, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              ),
              if (b.distanciaKm != null)
                EtiquetaChip('a ${distanciaTexto(b.distanciaKm)}', color: AppColors.azul),
            ],
          ),
          Text(b.direccion, style: const TextStyle(color: AppColors.textoSuave, fontSize: 13)),
          const SizedBox(height: 8),
          Row(
            children: [
              EtiquetaChip(
                poco ? 'Quedan ${b.stock}' : '${b.stock} disponibles',
                color: poco ? const Color(0xFFB7791F) : AppColors.verde,
              ),
              const Spacer(),
              Text(
                soles(b.precio),
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: AppColors.azul),
              ),
            ],
          ),
          if (b.minutosDesdeActualizacion != null) ...[
            const SizedBox(height: 6),
            Text(
              b.desactualizado
                  ? 'Stock actualizado ${tiempoRelativo(b.minutosDesdeActualizacion)}: confirma con la botica antes de ir.'
                  : 'Stock actualizado ${tiempoRelativo(b.minutosDesdeActualizacion)}',
              style: TextStyle(
                fontSize: 12,
                color: b.desactualizado ? const Color(0xFFB7791F) : AppColors.textoSuave,
              ),
            ),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: const Icon(Icons.shopping_bag_outlined),
              label: const Text('Reservar'),
              onPressed: () async {
                await mostrarReserva(
                  context,
                  boticaId: b.boticaId,
                  boticaNombre: b.nombre,
                  medicamentoId: d.id,
                  medicamentoNombre: d.nombre,
                  precio: b.precio,
                  stock: b.stock,
                  requiereReceta: d.requiereReceta,
                );
                // El stock pudo cambiar con la reserva
                if (mounted) _cargar();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _seccionFicha(DetalleMedicamento d) {
    final f = d.ficha;
    if (!f.disponible) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _titulo('Ficha técnica'),
          Aviso(
            f.mensaje ?? 'Ficha técnica no disponible',
            color: AppColors.textoSuave,
            icono: Icons.description_outlined,
          ),
        ],
      );
    }

    final bloques = <MapEntry<String, String?>>[
      MapEntry('Dosis referencial', f.dosisReferencial),
      MapEntry('Para qué se usa', f.indicaciones),
      MapEntry('Contraindicaciones', f.contraindicaciones),
      MapEntry('Efectos adversos', f.efectosAdversos),
      MapEntry('Conservación', f.conservacion),
    ].where((e) => e.value != null && e.value!.isNotEmpty).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _titulo('Ficha técnica'),
        Card(
          color: Colors.white,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.borde),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < bloques.length; i++)
                ExpansionTile(
                  initiallyExpanded: i == 0,
                  shape: const Border(),
                  collapsedShape: const Border(),
                  title: Text(bloques[i].key, style: const TextStyle(fontWeight: FontWeight.w600)),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  children: [Text(bloques[i].value!)],
                ),
              if (f.prospectoUrl != null)
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('Prospecto'),
                  subtitle: SelectableText(f.prospectoUrl!),
                ),
            ],
          ),
        ),
        if (f.aviso != null) ...[
          const SizedBox(height: 8),
          Text(f.aviso!, style: const TextStyle(fontSize: 12, color: AppColors.textoSuave)),
        ],
      ],
    );
  }

  Widget _seccionAlternativas() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _titulo('Alternativas más económicas'),
        for (final a in _alternativas) ...[
          TarjetaBase(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => DetalleScreen(medicamentoId: a.id, nombre: a.nombre)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.nombre, style: const TextStyle(fontWeight: FontWeight.w700)),
                      if (a.precioDesde != null) Text('Desde ${soles(a.precioDesde)}'),
                    ],
                  ),
                ),
                if (a.ahorroSoles != null && a.ahorroSoles! > 0)
                  EtiquetaChip(
                    'Ahorras ${soles(a.ahorroSoles)}'
                    '${a.ahorroPorcentaje != null ? ' (${a.ahorroPorcentaje!.round()}%)' : ''}',
                    color: AppColors.verde,
                  ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}
