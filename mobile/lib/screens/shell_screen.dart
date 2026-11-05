import 'package:flutter/material.dart';

import 'buscar_screen.dart';
import 'inicio_screen.dart';
import 'cuenta_screen.dart';
import 'reservas_screen.dart';
import 'sedes_screen.dart';

/// Estructura principal del cliente: barra de navegación inferior con las 5 secciones del diseño.
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
          const SedesScreen(),
          const ReservasScreen(),
          const CuentaScreen(),
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
