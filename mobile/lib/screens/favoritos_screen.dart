import 'package:flutter/material.dart';

import '../models/medicamento.dart';
import '../services/api_client.dart';
import '../services/medicamentos_service.dart';
import '../theme/app_theme.dart';
import '../widgets/comunes.dart';
import '../widgets/estado_vacio.dart';
import '../widgets/medicamento_card.dart';
import 'detalle_screen.dart';

/// HU17: mis medicamentos favoritos. Desliza una tarjeta para quitarla.
class FavoritosScreen extends StatefulWidget {
  const FavoritosScreen({super.key});

  @override
  State<FavoritosScreen> createState() => _FavoritosScreenState();
}

class _FavoritosScreenState extends State<FavoritosScreen> {
  final _servicio = MedicamentosService();
  List<Medicamento>? _lista;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _error = null);
    try {
      final lista = await _servicio.favoritos();
      if (!mounted) return;
      setState(() => _lista = lista);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.mensaje);
    }
  }

  Future<void> _quitar(Medicamento m) async {
    setState(() => _lista = _lista?.where((x) => x.id != m.id).toList());
    try {
      await _servicio.quitarFavorito(m.id);
    } on ApiException catch (e) {
      if (!mounted) return;
      mostrarMensaje(context, e.mensaje);
      _cargar();
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget cuerpo;
    final lista = _lista;
    if (_error != null) {
      cuerpo = EstadoVacio(
        icono: Icons.wifi_off_outlined,
        titulo: 'No pudimos cargar tus favoritos',
        mensaje: _error,
        accion: FilledButton(onPressed: _cargar, child: const Text('Reintentar')),
      );
    } else if (lista == null) {
      cuerpo = const Center(child: CircularProgressIndicator());
    } else if (lista.isEmpty) {
      cuerpo = const EstadoVacio(
        icono: Icons.favorite_border,
        titulo: 'Aún no tienes medicamentos favoritos',
        mensaje: 'Toca el corazón en la ficha de un medicamento para guardarlo aquí.',
      );
    } else {
      cuerpo = ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: lista.length,
        separatorBuilder: (context, i) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final m = lista[i];
          return Dismissible(
            key: ValueKey('fav-${m.id}'),
            direction: DismissDirection.endToStart,
            onDismissed: (_) => _quitar(m),
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              decoration: BoxDecoration(
                color: AppColors.alerta,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.delete_outline, color: Colors.white),
            ),
            child: MedicamentoCard(
              medicamento: m,
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => DetalleScreen(medicamentoId: m.id, nombre: m.nombre)),
                );
                if (mounted) _cargar();
              },
            ),
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Mis favoritos')),
      body: cuerpo,
    );
  }
}
