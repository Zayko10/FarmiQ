import '../utils/formato.dart';

/// Ficha técnica de un medicamento (HU15).
class Ficha {
  const Ficha({
    required this.disponible,
    this.mensaje,
    this.dosisReferencial,
    this.prospectoUrl,
    this.indicaciones,
    this.contraindicaciones,
    this.efectosAdversos,
    this.conservacion,
    this.aviso,
  });

  final bool disponible;
  final String? mensaje;
  final String? dosisReferencial;
  final String? prospectoUrl;
  final String? indicaciones;
  final String? contraindicaciones;
  final String? efectosAdversos;
  final String? conservacion;
  final String? aviso;

  factory Ficha.fromJson(Map<String, dynamic> json) {
    return Ficha(
      disponible: json['disponible'] as bool? ?? false,
      mensaje: json['mensaje'] as String?,
      dosisReferencial: json['dosis_referencial'] as String?,
      prospectoUrl: json['prospecto_url'] as String?,
      indicaciones: json['indicaciones'] as String?,
      contraindicaciones: json['contraindicaciones'] as String?,
      efectosAdversos: json['efectos_adversos'] as String?,
      conservacion: json['conservacion'] as String?,
      aviso: json['aviso'] as String?,
    );
  }
}

/// Detalle de un medicamento: datos, ficha técnica y si es favorito del cliente.
class DetalleMedicamento {
  const DetalleMedicamento({
    required this.id,
    required this.nombre,
    required this.principioActivo,
    required this.concentracion,
    required this.presentacion,
    required this.categoria,
    required this.esGenerico,
    required this.requiereReceta,
    required this.disponible,
    required this.ficha,
    this.laboratorio,
    this.descripcion,
    this.precioDesde,
    this.esFavorito,
  });

  final String id;
  final String nombre;
  final String principioActivo;
  final String concentracion;
  final String presentacion;
  final String categoria;
  final bool esGenerico;
  final bool requiereReceta;
  final bool disponible;
  final String? laboratorio;
  final String? descripcion;
  final double? precioDesde;
  final Ficha ficha;

  /// null = invitado (sin sesión)
  final bool? esFavorito;

  String get subtitulo => [principioActivo, concentracion, presentacion]
      .where((p) => p.isNotEmpty)
      .join(' · ');

  DetalleMedicamento conFavorito(bool valor) => DetalleMedicamento(
        id: id,
        nombre: nombre,
        principioActivo: principioActivo,
        concentracion: concentracion,
        presentacion: presentacion,
        categoria: categoria,
        esGenerico: esGenerico,
        requiereReceta: requiereReceta,
        disponible: disponible,
        laboratorio: laboratorio,
        descripcion: descripcion,
        precioDesde: precioDesde,
        ficha: ficha,
        esFavorito: valor,
      );

  factory DetalleMedicamento.fromJson(Map<String, dynamic> json) {
    final m = json['medicamento'] as Map<String, dynamic>;
    return DetalleMedicamento(
      id: m['id'].toString(),
      nombre: m['nombre'] as String,
      principioActivo: m['principio_activo'] as String? ?? '',
      concentracion: m['concentracion'] as String? ?? '',
      presentacion: m['presentacion'] as String? ?? '',
      categoria: m['categoria'] as String? ?? '',
      esGenerico: m['es_generico'] as bool? ?? false,
      requiereReceta: m['requiere_receta'] as bool? ?? false,
      disponible: m['disponible'] as bool? ?? false,
      laboratorio: m['laboratorio'] as String?,
      descripcion: m['descripcion'] as String?,
      precioDesde: decimal(m['precio_desde']),
      ficha: Ficha.fromJson((json['ficha'] as Map<String, dynamic>?) ?? const {}),
      esFavorito: json['es_favorito'] as bool?,
    );
  }
}

/// Una botica que tiene el medicamento en stock (HU04).
class DisponibilidadBotica {
  const DisponibilidadBotica({
    required this.boticaId,
    required this.nombre,
    required this.direccion,
    required this.stock,
    required this.precio,
    this.latitud,
    this.longitud,
    this.distanciaKm,
    this.minutosDesdeActualizacion,
  });

  final String boticaId;
  final String nombre;
  final String direccion;
  final int stock;
  final double precio;
  final double? latitud;
  final double? longitud;
  final double? distanciaKm;
  final int? minutosDesdeActualizacion;

  /// HU27: el stock no se actualiza hace más de 24 horas
  bool get desactualizado => (minutosDesdeActualizacion ?? 0) > 24 * 60;

  factory DisponibilidadBotica.fromJson(Map<String, dynamic> json) {
    return DisponibilidadBotica(
      boticaId: json['id'].toString(),
      nombre: json['nombre'] as String,
      direccion: json['direccion'] as String? ?? '',
      stock: entero(json['stock']),
      precio: decimal(json['precio']) ?? 0,
      latitud: decimal(json['latitud']),
      longitud: decimal(json['longitud']),
      distanciaKm: decimal(json['distancia_km']),
      minutosDesdeActualizacion: (json['minutos_desde_actualizacion'] as num?)?.toInt(),
    );
  }
}

/// Genérico equivalente con el ahorro que representa (HU05).
class Alternativa {
  const Alternativa({
    required this.id,
    required this.nombre,
    required this.disponible,
    this.precioDesde,
    this.ahorroSoles,
    this.ahorroPorcentaje,
  });

  final String id;
  final String nombre;
  final bool disponible;
  final double? precioDesde;
  final double? ahorroSoles;
  final double? ahorroPorcentaje;

  factory Alternativa.fromJson(Map<String, dynamic> json) {
    return Alternativa(
      id: json['id'].toString(),
      nombre: json['nombre'] as String,
      disponible: json['disponible'] as bool? ?? false,
      precioDesde: decimal(json['precio_desde']),
      ahorroSoles: decimal(json['ahorro_soles']),
      ahorroPorcentaje: decimal(json['ahorro_porcentaje']),
    );
  }
}
