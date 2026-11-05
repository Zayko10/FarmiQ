import 'package:flutter/material.dart';

import '../../services/sesion.dart';
import '../../theme/app_theme.dart';

class PanelCuentaScreen extends StatelessWidget {
  const PanelCuentaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final u = Sesion.instancia.usuario;
    final esquema = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Mi cuenta')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: esquema.primary.withValues(alpha: 0.12),
                child: Icon(Icons.storefront_outlined, color: esquema.primary, size: 30),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      u?.nombre ?? '',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(u?.email ?? '', style: const TextStyle(color: AppColors.textoSuave)),
                    if (u?.boticaNombre != null)
                      Text(
                        u!.boticaNombre!,
                        style: TextStyle(color: esquema.primary, fontWeight: FontWeight.w600),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Cuenta de personal de botica. Solo puedes ver y modificar el inventario y las reservas de tu botica.',
            style: TextStyle(color: AppColors.textoSuave),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => Sesion.instancia.cerrar(),
            icon: const Icon(Icons.logout),
            label: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
  }
}
