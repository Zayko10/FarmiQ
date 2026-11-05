import '../utils/formato.dart';

/// Sede de una botica (pantalla Sedes).
class Botica {
  const Botica({
    required this.id,
    required this.nombre,
    required this.direccion,
    this.telefono,
    this.latitud,
    this.longitud,
    this.distanciaKm,
    this.productosConStock = 0,
  });

  final String id;
  final String nombre;
  final String direccion;
  final String? telefono;
  final double? latitud;
  final double? longitud;
  final double? distanciaKm;
  final int productosConStock;

  bool get tieneCoordenadas => latitud != null && longitud != null;

  factory Botica.fromJson(Map<String, dynamic> json) {
    return Botica(
      id: json['id'].toString(),
      nombre: json['nombre'] as String,
      direccion: json['direccion'] as String? ?? '',
      telefono: json['telefono'] as String?,
      latitud: decimal(json['latitud']),
      longitud: decimal(json['longitud']),
      distanciaKm: decimal(json['distancia_km']),
      productosConStock: entero(json['productos_con_stock']),
    );
  }
}

/// Producto en la lista de una botica, con el stock disponible ya descontadas las reservas.
class ProductoBotica {
  const ProductoBotica({
    required this.id,
    required this.nombre,
    required this.principioActivo,
    required this.concentracion,
    required this.presentacion,
    required this.categoria,
    required this.esGenerico,
    required this.requiereReceta,
    required this.stock,
    required this.precio,
    this.minutosDesdeActualizacion,
  });

  final String id;
  final String nombre;
  final String principioActivo;
  final String concentracion;
  final String presentacion;
  final String categoria;
  final bool esGenerico;
  final bool requiereReceta;
  final int stock;
  final double precio;
  final int? minutosDesdeActualizacion;

  String get descripcion => [principioActivo, concentracion, presentacion]
      .where((p) => p.isNotEmpty)
      .join(' · ');

  factory ProductoBotica.fromJson(Map<String, dynamic> json) {
    return ProductoBotica(
      id: json['id'].toString(),
      nombre: json['nombre'] as String,
      principioActivo: json['principio_activo'] as String? ?? '',
      concentracion: json['concentracion'] as String? ?? '',
      presentacion: json['presentacion'] as String? ?? '',
      categoria: json['categoria'] as String? ?? '',
      esGenerico: json['es_generico'] as bool? ?? false,
      requiereReceta: json['requiere_receta'] as bool? ?? false,
      stock: entero(json['stock']),
      precio: decimal(json['precio']) ?? 0,
      minutosDesdeActualizacion: (json['minutos_desde_actualizacion'] as num?)?.toInt(),
    );
  }
}
