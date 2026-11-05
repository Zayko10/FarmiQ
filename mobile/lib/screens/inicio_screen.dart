import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/logo_farmiq.dart';

/// Pantalla de inicio: buscador prominente y accesos rápidos.
class InicioScreen extends StatelessWidget {
  const InicioScreen({super.key, required this.onBuscar});

  /// Lleva a la pestaña Buscar. Si [consulta] viene con texto, busca de inmediato.
  final void Function(String consulta) onBuscar;

  static const List<String> _frecuentes = [
    'Paracetamol',
    'Ibuprofeno',
    'Loratadina',
    'Omeprazol',
    'Losartán',
  ];

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: LogoFarmiq(alto: 34),
            ),
            const SizedBox(height: 28),
            Text(
              '¿Qué necesitas hoy?',
              style: textos.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Busca un medicamento y mira qué botica lo tiene en stock.',
              style: textos.bodyMedium?.copyWith(color: AppColors.textoSuave),
            ),
            const SizedBox(height: 18),
            Material(
              color: Colors.white,
              shape: const StadiumBorder(side: BorderSide(color: AppColors.borde)),
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: () => onBuscar(''),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    children: [
                      const Icon(Icons.search, color: AppColors.azul),
                      const SizedBox(width: 12),
                      Text(
                        'Nombre o principio activo',
                        style: textos.bodyLarge?.copyWith(color: AppColors.textoSuave),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'Búsquedas frecuentes',
              style: textos.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final nombre in _frecuentes)
                  ActionChip(label: Text(nombre), onPressed: () => onBuscar(nombre)),
              ],
            ),
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.verde.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.savings_outlined, color: AppColors.verde, size: 32),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Compara y ahorra',
                          style: textos.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Te mostramos los genéricos con el mismo principio activo y cuánto te ahorras.',
                          style: textos.bodyMedium?.copyWith(color: AppColors.textoSuave),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
