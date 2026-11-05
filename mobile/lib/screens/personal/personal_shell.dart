import 'package:flutter/material.dart';

import 'panel_cuenta_screen.dart';
import 'panel_inventario_screen.dart';
import 'panel_reservas_screen.dart';
import 'panel_resumen_screen.dart';

/// Estructura de la interfaz del personal de botica (distinta a la del cliente):
/// Resumen, Inventario, Reservas y Cuenta.
class PersonalShell extends StatefulWidget {
  const PersonalShell({super.key});

  @override
  State<PersonalShell> createState() => _PersonalShellState();
}

class _PersonalShellState extends State<PersonalShell> {
  int _indice = 0;
  final _inventarioKey = GlobalKey<PanelInventarioScreenState>();
  final _reservasKey = GlobalKey<PanelReservasScreenState>();
  final _resumenKey = GlobalKey<PanelResumenScreenState>();

  void _irAInventario(String filtro) {
    setState(() => _indice = 1);
    _inventarioKey.currentState?.aplicarFiltro(filtro);
  }

  void _irAReservas(String estado) {
    setState(() => _indice = 2);
    _reservasKey.currentState?.aplicarEstado(estado);
  }

  void _alCambiarPestana(int i) {
    setState(() => _indice = i);
    // Al volver al resumen, sus números se actualizan
    if (i == 0) _resumenKey.currentState?.cargar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _indice,
        children: [
          PanelResumenScreen(
            key: _resumenKey,
            onIrInventario: _irAInventario,
            onIrReservas: _irAReservas,
          ),
          PanelInventarioScreen(key: _inventarioKey),
          PanelReservasScreen(key: _reservasKey),
          const PanelCuentaScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indice,
        onDestinationSelected: _alCambiarPestana,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Resumen',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Inventario',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Reservas',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Cuenta',
          ),
        ],
      ),
    );
  }
}
