import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Etiqueta de color (Genérico, Con receta, Disponible...).
class EtiquetaChip extends StatelessWidget {
  const EtiquetaChip(this.texto, {super.key, required this.color});

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

/// Recuadro de aviso (error, información o advertencia).
class Aviso extends StatelessWidget {
  const Aviso(this.mensaje, {super.key, this.color = AppColors.alerta, this.icono = Icons.error_outline});

  final String mensaje;
  final Color color;
  final IconData icono;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(mensaje, style: TextStyle(color: color, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}

/// Tarjeta blanca con borde, el contenedor básico de las listas.
class TarjetaBase extends StatelessWidget {
  const TarjetaBase({super.key, required this.child, this.onTap, this.padding = const EdgeInsets.all(14)});

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        side: BorderSide(color: AppColors.borde),
      ),
      child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
    );
  }
}

void mostrarMensaje(BuildContext context, String mensaje, {SnackBarAction? accion}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(mensaje), action: accion));
}
