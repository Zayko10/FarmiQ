import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/botica.dart';
import '../services/api_client.dart';
import '../services/boticas_service.dart';
import '../services/ubicacion_service.dart';
import '../theme/app_theme.dart';
import '../utils/formato.dart';
import '../widgets/comunes.dart';
import '../widgets/estado_vacio.dart';
import 'botica_detalle_screen.dart';

/// Sedes: boticas cercanas según la ubicación del cliente, con mapa, radio de búsqueda y acceso a su stock.
class SedesScreen extends StatefulWidget {
  const SedesScreen({super.key});

  @override
  State<SedesScreen> createState() => _SedesScreenState();
}

class _SedesScreenState extends State<SedesScreen> {
  static const _radios = <double?>[null, 1, 3, 5, 10];

  final _servicio = BoticasService();

  ResultadoSedes? _resultado;
  PosicionCliente? _posicion = UbicacionService.ultima;
  double? _radio;
  String? _error;
  String? _avisoUbicacion;
  bool _abrirAjustes = false;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _iniciar();
  }

  Future<void> _iniciar() async {
    await _pedirUbicacion(silencioso: true);
    await _cargar();
  }

  Future<void> _pedirUbicacion({bool silencioso = false}) async {
    final r = await UbicacionService.obtener();
    if (!mounted) return;
    setState(() {
      _posicion = r.posicion ?? _posicion;
      _avisoUbicacion = r.posicion == null ? r.error : null;
      _abrirAjustes = r.abrirAjustes;
    });
    if (!silencioso && r.posicion != null) await _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final r = await _servicio.listar(posicion: _posicion, radioKm: _radio);
      if (!mounted) return;
      setState(() {
        _resultado = r;
        _cargando = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.mensaje;
        _cargando = false;
      });
    }
  }

  void _abrir(Botica b) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => BoticaDetalleScreen(botica: b)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sedes cercanas'),
        actions: [
          IconButton(
            tooltip: 'Actualizar mi ubicación',
            icon: const Icon(Icons.my_location),
            onPressed: () => _pedirUbicacion(),
          ),
        ],
      ),
      body: _cuerpo(),
    );
  }

  Widget _cuerpo() {
    if (_error != null && _resultado == null) {
      return EstadoVacio(
        icono: Icons.wifi_off_outlined,
        titulo: 'No pudimos cargar las sedes',
        mensaje: _error,
        accion: FilledButton(onPressed: _cargar, child: const Text('Reintentar')),
      );
    }
    final resultado = _resultado;
    if (resultado == null) return const Center(child: CircularProgressIndicator());

    final boticas = resultado.boticas;
    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          if (_posicion == null) ...[
            Aviso(
              _avisoUbicacion ?? 'Activa tu ubicación para ordenar las boticas por cercanía.',
              color: AppColors.azul,
              icono: Icons.location_off_outlined,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () async {
                  await _pedirUbicacion();
                  if (_abrirAjustes) await UbicacionService.abrirAjustes();
                },
                icon: const Icon(Icons.my_location),
                label: const Text('Activar ubicación'),
              ),
            ),
          ] else ...[
            Text('Radio de búsqueda', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                for (final r in _radios)
                  ChoiceChip(
                    label: Text(r == null ? 'Todas' : '${r.toStringAsFixed(0)} km'),
                    selected: _radio == r,
                    onSelected: (_) {
                      setState(() => _radio = r);
                      _cargar();
                    },
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          if (boticas.any((b) => b.tieneCoordenadas)) _mapa(boticas),
          const SizedBox(height: 12),
          if (_cargando) const LinearProgressIndicator(),
          if (boticas.isEmpty && !_cargando)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: EstadoVacio(
                icono: Icons.storefront_outlined,
                titulo: resultado.mensaje ?? 'No hay boticas disponibles',
                mensaje: resultado.sugerencia,
              ),
            ),
          for (final b in boticas) ...[
            _tarjeta(b),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Widget _mapa(List<Botica> boticas) {
    final conCoordenadas = boticas.where((b) => b.tieneCoordenadas).toList();
    final centro = _posicion != null
        ? LatLng(_posicion!.lat, _posicion!.lng)
        : LatLng(conCoordenadas.first.latitud!, conCoordenadas.first.longitud!);
    // Radio elegido -> zoom aproximado; sin radio, un zoom que muestra la zona cercana
    final zoom = _radio == null
        ? 13.0
        : _radio! <= 1
            ? 15.0
            : _radio! <= 3
                ? 14.0
                : _radio! <= 5
                    ? 13.0
                    : 12.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 240,
        child: FlutterMap(
          key: ValueKey('mapa-${centro.latitude}-${centro.longitude}-$zoom'),
          options: MapOptions(initialCenter: centro, initialZoom: zoom),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'pe.farmiq.farmiq',
            ),
            MarkerLayer(
              markers: [
                for (final b in conCoordenadas)
                  Marker(
                    point: LatLng(b.latitud!, b.longitud!),
                    width: 44,
                    height: 44,
                    alignment: Alignment.topCenter,
                    child: GestureDetector(
                      onTap: () => _abrir(b),
                      child: const Icon(Icons.location_on, color: AppColors.azul, size: 40),
                    ),
                  ),
                if (_posicion != null)
                  Marker(
                    point: LatLng(_posicion!.lat, _posicion!.lng),
                    width: 28,
                    height: 28,
                    child: const Icon(Icons.circle, color: AppColors.verde, size: 22),
                  ),
              ],
            ),
            const RichAttributionWidget(
              attributions: [TextSourceAttribution('© OpenStreetMap')],
            ),
          ],
        ),
      ),
    );
  }

  Widget _tarjeta(Botica b) {
    return TarjetaBase(
      onTap: () => _abrir(b),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.azul.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.storefront_outlined, color: AppColors.azul),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(b.nombre, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                Text(b.direccion, style: const TextStyle(color: AppColors.textoSuave, fontSize: 13)),
                const SizedBox(height: 4),
                Text(
                  '${b.productosConStock} productos con stock',
                  style: const TextStyle(fontSize: 12, color: AppColors.verde, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          if (b.distanciaKm != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  distanciaTexto(b.distanciaKm),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.azul),
                ),
                const Text('de ti', style: TextStyle(fontSize: 11, color: AppColors.textoSuave)),
              ],
            ),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}
