import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Pantalla de mensaje: sin resultados, sin conexión, estado inicial...
class EstadoVacio extends StatelessWidget {
  const EstadoVacio({
    super.key,
    required this.icono,
    required this.titulo,
    this.mensaje,
    this.accion,
  });

  final IconData icono;
  final String titulo;
  final String? mensaje;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final detalle = mensaje;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 56, color: AppColors.textoSuave),
            const SizedBox(height: 16),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: textos.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            if (detalle != null) ...[
              const SizedBox(height: 8),
              Text(
                detalle,
                textAlign: TextAlign.center,
                style: textos.bodyMedium?.copyWith(color: AppColors.textoSuave),
              ),
            ],
            if (accion != null) ...[
              const SizedBox(height: 20),
              accion!,
            ],
          ],
        ),
      ),
    );
  }
}
