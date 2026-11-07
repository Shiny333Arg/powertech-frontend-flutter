import 'conversiones.dart';

/// Una página de un recurso paginado de Laravel.
///
/// Es el `meta` que agrega `ResourceCollection` sobre un `LengthAwarePaginator`,
/// tal como llega en `/productos`:
///
/// ```
/// "meta": { "current_page":1, "from":1, "last_page":1, "links":[...],
///           "path":"...", "per_page":24, "to":8, "total":8 }
/// ```
///
/// **De `links` y de `meta.links` no se usa nada, y es deliberado.** Esas URL
/// las arma Laravel con el host del request —en el JSON de prueba dicen
/// `http://localhost:8000`— y además `meta.links[].label` trae entidades HTML
/// (`&laquo; Anterior`). Seguir esas URL ataría la paginación al host con el
/// que se generó la respuesta y a un formato pensado para pintar un paginador
/// de Blade. La app pide la página siguiente como `?page=N` sobre su propia
/// URL base, con los filtros que el backend confirmó. Es el mismo riesgo que
/// el plan ya anota para `route()` y `asset()`.
///
/// Genérica porque el mismo `meta` va a volver en `/compras` (etapa 6).
class Pagina<T> {
  const Pagina({
    required this.items,
    required this.paginaActual,
    required this.ultimaPagina,
    required this.porPagina,
    required this.total,
    this.desde,
    this.hasta,
  });

  final List<T> items;

  final int paginaActual;
  final int ultimaPagina;
  final int porPagina;
  final int total;

  /// Índice del primer y último elemento de esta página dentro del total.
  /// Vienen null cuando la página está vacía.
  final int? desde;
  final int? hasta;

  bool get hayMas => paginaActual < ultimaPagina;

  int get proximaPagina => paginaActual + 1;

  /// Página vacía de arranque, para no tener que modelar "todavía no pedí
  /// nada" con un nullable que después hay que chequear en cada lectura.
  static Pagina<T> vacia<T>() => Pagina<T>(
        items: const [],
        paginaActual: 0,
        ultimaPagina: 0,
        porPagina: 0,
        total: 0,
      );

  /// `cuerpo` es la respuesta completa: se leen `data` y `meta`.
  ///
  /// Si `meta` no viniera —una colección sin paginar— se asume una página
  /// única con todo lo que llegó, en lugar de fallar: el resto de la pantalla
  /// funciona igual y "Cargar más" simplemente no aparece.
  factory Pagina.fromJson(
    Map<String, dynamic> cuerpo,
    List<T> Function(dynamic) itemsDe,
  ) {
    final items = itemsDe(cuerpo['data']);
    final meta = comoMapa(cuerpo['meta']);

    if (meta == null) {
      return Pagina<T>(
        items: items,
        paginaActual: 1,
        ultimaPagina: 1,
        porPagina: items.length,
        total: items.length,
        desde: items.isEmpty ? null : 1,
        hasta: items.isEmpty ? null : items.length,
      );
    }

    return Pagina<T>(
      items: items,
      paginaActual: comoEnteroOpcional(meta['current_page']) ?? 1,
      ultimaPagina: comoEnteroOpcional(meta['last_page']) ?? 1,
      porPagina: comoEnteroOpcional(meta['per_page']) ?? items.length,
      total: comoEnteroOpcional(meta['total']) ?? items.length,
      desde: comoEnteroOpcional(meta['from']),
      hasta: comoEnteroOpcional(meta['to']),
    );
  }
}
