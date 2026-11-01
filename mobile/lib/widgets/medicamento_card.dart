import 'package:flutter/material.dart';

import '../models/medicamento.dart';
import '../theme/app_theme.dart';

/// Tarjeta de un medicamento en la lista de resultados.
class MedicamentoCard extends StatelessWidget {
  const MedicamentoCard({super.key, required this.medicamento, this.onTap});

  final Medicamento medicamento;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final m = medicamento;

    return Material(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        side: BorderSide(color: AppColors.borde),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.nombre,
                      style: textos.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      m.descripcion,
                      style: textos.bodySmall?.copyWith(color: AppColors.textoSuave),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (m.esGenerico) const _Etiqueta('Genérico', color: AppColors.verde),
                        _Etiqueta(
                          m.disponible ? 'Disponible' : 'Sin stock',
                          color: m.disponible ? AppColors.verde : AppColors.textoSuave,
                        ),
                        if (m.requiereReceta) const _Etiqueta('Con receta', color: AppColors.azul),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Desde',
                    style: textos.bodySmall?.copyWith(color: AppColors.textoSuave),
                  ),
                  Text(
                    m.precioTexto,
                    style: textos.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.azul,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Etiqueta extends StatelessWidget {
  const _Etiqueta(this.texto, {required this.color});

  final String texto;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        texto,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}
