import 'package:flutter/foundation.dart';

/// Avisos entre pantallas: cuando se crea, paga o cancela una reserva, la lista se actualiza sola.
class Eventos {
  Eventos._();

  static final ValueNotifier<int> reservasCambiaron = ValueNotifier<int>(0);

  static void avisarReservas() => reservasCambiaron.value++;
}
