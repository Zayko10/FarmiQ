import 'package:flutter/material.dart';

import 'buscar_screen.dart';
import 'inicio_screen.dart';
import 'proximamente_screen.dart';

/// Estructura principal: barra de navegación inferior con las 5 secciones del diseño.
class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  int _indice = 0;
  final _buscarKey = GlobalKey<BuscarScreenState>();

  void _irABuscar(String consulta) {
    setState(() => _indice = 1);
    _buscarKey.currentState?.buscar(consulta);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _indice,
        children: [
          InicioScreen(onBuscar: _irABuscar),
          BuscarScreen(key: _buscarKey),
          const ProximamenteScreen(
            titulo: 'Sedes',
            icono: Icons.place_outlined,
            mensaje: 'Aquí verás las boticas cercanas en un mapa.',
          ),
          const ProximamenteScreen(
            titulo: 'Reservas',
            icono: Icons.receipt_long_outlined,
            mensaje: 'Aquí verás tus reservas. Se activa en el Sprint 2.',
          ),
          const ProximamenteScreen(
            titulo: 'Mi cuenta',
            icono: Icons.person_outline,
            mensaje: 'Aquí iniciarás sesión y verás tus favoritos.',
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indice,
        onDestinationSelected: (i) => setState(() => _indice = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.search),
            selectedIcon: Icon(Icons.search),
            label: 'Buscar',
          ),
          NavigationDestination(
            icon: Icon(Icons.place_outlined),
            selectedIcon: Icon(Icons.place),
            label: 'Sedes',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Reservas',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Mi cuenta',
          ),
        ],
      ),
    );
  }
}
