import 'conversiones.dart';
import 'filtros_catalogo.dart';
import 'pagina.dart';
import 'producto.dart';
import 'promocion.dart';

/// La respuesta completa de `GET /api/v1/productos`.
///
/// `ProductoResource::collection($paginator)->additional([...])` produce seis
/// claves de primer nivel: `data`, `links`, `meta`, y las tres que agrega el
/// controlador.
///
/// ```
/// { data: [...], links: {...}, meta: {...},
///   filtros: {q, categoria, marca, precio_min, precio_max, promocion, orden},
///   promocion: null | {...},
///   ordenes: [{valor, etiqueta}] }
/// ```
///
/// Las tres últimas son las que hacen que la pantalla de filtros no tenga nada
/// hardcodeado: `filtros` dice qué se aplicó, `ordenes` qué opciones ofrecer y
/// `promocion` cómo titular la lista.
class ResultadoCatalogo {
  const ResultadoCatalogo({
    required this.pagina,
    required this.filtrosAplicados,
    required this.ordenes,
    this.promocion,
  });

  final Pagina<Producto> pagina;

  /// **Lo que el backend aplicó, no lo que la app pidió.** Es desde acá que se
  /// reconstruye la UI de filtros: al invitado que pidió un rango de precio le
  /// vuelve en null, y la pantalla deja de mostrarlo en lugar de sostener un
  /// filtro fantasma.
  final FiltrosCatalogo filtrosAplicados;

  /// Las opciones de orden válidas para este visitante. Cuatro para el
  /// invitado, seis para el cliente.
  final List<OpcionOrden> ordenes;

  /// La promoción del filtro, si se pidió una y sigue vigente.
  ///
  /// `promocionDelFiltro()` devuelve null cuando el id no existe o la
  /// promoción venció, y en ese caso el controlador además descarta el filtro:
  /// un banner viejo guardado en favoritos muestra el catálogo completo en
  /// lugar de una lista vacía. Si esto es null y `filtrosAplicados.promocionId`
  /// también, puede ser que la promoción que se pidió ya no esté vigente.
  final Promocion? promocion;

  factory ResultadoCatalogo.fromJson(Map<String, dynamic> cuerpo) {
    final promocion = comoMapa(cuerpo['promocion']);

    return ResultadoCatalogo(
      pagina: Pagina<Producto>.fromJson(cuerpo, Producto.listaDe),
      filtrosAplicados:
          FiltrosCatalogo.fromJson(comoMapa(cuerpo['filtros']) ?? const {}),
      ordenes: OpcionOrden.listaDe(cuerpo['ordenes']),
      promocion: promocion == null ? null : Promocion.fromJson(promocion),
    );
  }
}
