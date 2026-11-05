/// "S/ 12.90"
String soles(num? valor) => valor == null ? '—' : 'S/ ${valor.toStringAsFixed(2)}';

/// "850 m", "1.2 km", "182 km"
String distanciaTexto(double? km) {
  if (km == null) return '';
  if (km < 1) return '${(km * 1000).round()} m';
  if (km < 10) return '${km.toStringAsFixed(1)} km';
  return '${km.round()} km';
}

/// "hace 5 min", "hace 3 h", "hace 2 días"
String tiempoRelativo(int? minutos) {
  if (minutos == null) return '';
  if (minutos < 1) return 'hace un momento';
  if (minutos < 60) return 'hace $minutos min';
  final horas = minutos ~/ 60;
  if (horas < 24) return 'hace $horas h';
  final dias = horas ~/ 24;
  return 'hace $dias ${dias == 1 ? 'día' : 'días'}';
}

/// 905 -> "15:05"
String mmss(int segundos) {
  final s = segundos < 0 ? 0 : segundos;
  final m = (s ~/ 60).toString().padLeft(2, '0');
  final r = (s % 60).toString().padLeft(2, '0');
  return '$m:$r';
}

int entero(dynamic valor, [int porDefecto = 0]) => (valor as num?)?.toInt() ?? porDefecto;

double? decimal(dynamic valor) => (valor as num?)?.toDouble();
