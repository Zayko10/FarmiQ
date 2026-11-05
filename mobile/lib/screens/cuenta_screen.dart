import 'package:flutter/material.dart';

import '../services/sesion.dart';
import '../theme/app_theme.dart';
import '../utils/navegacion.dart';
import '../widgets/estado_vacio.dart';
import 'favoritos_screen.dart';
import 'perfil_screen.dart';
import 'registro_screen.dart';

/// Mi cuenta: perfil, favoritos y cierre de sesión. El invitado ve cómo iniciar sesión.
class CuentaScreen extends StatelessWidget {
  const CuentaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Sesion.instancia,
      builder: (context, _) {
        final usuario = Sesion.instancia.usuario;

        if (usuario == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Mi cuenta')),
            body: EstadoVacio(
              icono: Icons.person_outline,
              titulo: 'Inicia sesión para continuar',
              mensaje: 'Con tu cuenta puedes reservar medicamentos, guardar favoritos y ver tus reservas.',
              accion: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FilledButton(
                    onPressed: () => irAIniciarSesion(context),
                    child: const Text('Iniciar sesión'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const RegistroScreen()),
                    ),
                    child: const Text('Crear una cuenta'),
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(title: const Text('Mi cuenta')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: AppColors.azul.withValues(alpha: 0.12),
                    child: Text(
                      usuario.nombre.isEmpty ? '?' : usuario.nombre.characters.first.toUpperCase(),
                      style: const TextStyle(fontSize: 26, color: AppColors.azul, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          usuario.nombre,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        Text(usuario.email, style: const TextStyle(color: AppColors.textoSuave)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Card(
                color: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: AppColors.borde),
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.edit_outlined),
                      title: const Text('Editar perfil'),
                      subtitle: const Text('Nombre, celular y dirección'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => const PerfilScreen()),
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.favorite_border),
                      title: const Text('Mis favoritos'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => const FavoritosScreen()),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () async {
                  await Sesion.instancia.cerrar();
                },
                icon: const Icon(Icons.logout),
                label: const Text('Cerrar sesión'),
              ),
            ],
          ),
        );
      },
    );
  }
}
