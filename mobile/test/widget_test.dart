import 'package:farmiq/app.dart';
import 'package:farmiq/models/medicamento.dart';
import 'package:farmiq/services/sesion.dart';
import 'package:farmiq/widgets/medicamento_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Medicamento _ejemplo({bool generico = false, bool disponible = true}) {
  return Medicamento.fromJson({
    'id': '1',
    'nombre': generico ? 'Paracetamol MK' : 'Panadol Forte',
    'principio_activo': 'Paracetamol',
    'concentracion': '500 mg',
    'presentacion': 'Tabletas x 20',
    'es_generico': generico,
    'requiere_receta': false,
    'precio_desde': 12.9,
    'disponible': disponible,
  });
}

Future<void> _abrirComoInvitado(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  await Sesion.instancia.cerrar();
  await tester.pumpWidget(FarmiQApp(tema: ThemeData(useMaterial3: true)));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Continuar como invitado'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('al abrir la app se ve el login de clientes y un acceso discreto para el personal', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await Sesion.instancia.cerrar();
    await tester.pumpWidget(FarmiQApp(tema: ThemeData(useMaterial3: true)));
    await tester.pumpAndSettle();

    expect(find.text('Bienvenido'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(find.text('Continuar como invitado'), findsOneWidget);
    expect(find.textContaining('Acceso para personal'), findsOneWidget);
  });

  testWidgets('el acceso del personal abre su propia pantalla de login', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await Sesion.instancia.cerrar();
    await tester.pumpWidget(FarmiQApp(tema: ThemeData(useMaterial3: true)));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Acceso para personal'));
    await tester.pumpAndSettle();

    expect(find.text('Acceso para personal de botica'), findsOneWidget);
  });

  testWidgets('muestra la barra inferior con las 5 secciones', (tester) async {
    await _abrirComoInvitado(tester);

    for (final etiqueta in ['Inicio', 'Buscar', 'Sedes', 'Reservas', 'Mi cuenta']) {
      expect(find.text(etiqueta), findsOneWidget);
    }
  });

  testWidgets('la pestaña Buscar invita a buscar por nombre o principio activo', (tester) async {
    await _abrirComoInvitado(tester);

    await tester.tap(find.text('Buscar'));
    await tester.pumpAndSettle();

    expect(find.text('Busca por nombre o principio activo'), findsOneWidget);
  });

  testWidgets('la tarjeta muestra nombre, estado y precio', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: MedicamentoCard(medicamento: _ejemplo()))),
    );

    expect(find.text('Panadol Forte'), findsOneWidget);
    expect(find.text('Disponible'), findsOneWidget);
    expect(find.text('Desde'), findsOneWidget);
    expect(find.text('S/ 12.90'), findsOneWidget);
    expect(find.text('Genérico'), findsNothing);
  });

  testWidgets('la tarjeta marca los genéricos sin stock', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MedicamentoCard(medicamento: _ejemplo(generico: true, disponible: false)),
        ),
      ),
    );

    expect(find.text('Genérico'), findsOneWidget);
    expect(find.text('Sin stock'), findsOneWidget);
  });
}
