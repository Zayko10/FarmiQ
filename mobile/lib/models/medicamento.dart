/// Medicamento tal como lo devuelve la búsqueda de la API (HU03).
class Medicamento {
  const Medicamento({
    required this.id,
    required this.nombre,
    required this.principioActivo,
    required this.concentracion,
    required this.presentacion,
    required this.esGenerico,
    required this.requiereReceta,
    required this.disponible,
    this.precioDesde,
  });

  final String id;
  final String nombre;
  final String principioActivo;
  final String concentracion;
  final String presentacion;
  final bool esGenerico;
  final bool requiereReceta;
  final bool disponible;
  final double? precioDesde;

  factory Medicamento.fromJson(Map<String, dynamic> json) {
    return Medicamento(
      id: json['id'].toString(),
      nombre: json['nombre'] as String,
      principioActivo: json['principio_activo'] as String,
      concentracion: json['concentracion'] as String? ?? '',
      presentacion: json['presentacion'] as String? ?? '',
      esGenerico: json['es_generico'] as bool? ?? false,
      requiereReceta: json['requiere_receta'] as bool? ?? false,
      disponible: json['disponible'] as bool? ?? false,
      precioDesde: (json['precio_desde'] as num?)?.toDouble(),
    );
  }

  /// Ejemplo: "Paracetamol · 500 mg · Tabletas x 20"
  String get descripcion {
    return [principioActivo, concentracion, presentacion]
        .where((parte) => parte.isNotEmpty)
        .join(' · ');
  }

  String get precioTexto {
    final precio = precioDesde;
    return precio == null ? '—' : 'S/ ${precio.toStringAsFixed(2)}';
  }
}
