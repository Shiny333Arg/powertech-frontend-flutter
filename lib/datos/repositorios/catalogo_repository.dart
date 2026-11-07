import '../../core/api_client.dart';
import '../../core/errores.dart';
import '../modelos/categoria.dart';
import '../modelos/conversiones.dart';
import '../modelos/filtros_catalogo.dart';
import '../modelos/producto_detalle.dart';
import '../modelos/resultado_catalogo.dart';
import '../modelos/vitrina.dart';

/// Acceso al catalogo publico. Todas estas rutas aceptan token pero no lo
/// exigen: con token vencido responden 200 tratando al visitante como
/// invitado, nunca 401.
///
/// **Este repositorio no sabe si hay sesion y no tiene que saberlo.** Pide, y
/// lo que vuelve viene con precio o sin precio segun lo que haya decidido
/// `VisitanteTienda` del lado del servidor. El interceptor de [ApiClient]
/// adjunta el token si existe; de ahi en adelante decide el backend. Dos
/// lugares decidiendo lo mismo es el bug.
class CatalogoRepository {
  const CatalogoRepository(this._api);

  final ApiClient _api;

  /// GET /home -> { promociones: [...], secciones: [{clave, titulo, productos}] }
  ///
  /// La respuesta no lleva envoltorio `data`: el controlador arma el
  /// `response()->json([...])` a mano y las colecciones anidadas no se
  /// envuelven. Es la misma asimetria que ya resolvimos en `/auth/yo`, al
  /// reves.
  Future<Vitrina> home() async {
    final respuesta = await _api.enviar((dio) => dio.get('/home'));

    final cuerpo = comoMapa(respuesta.data);

    if (cuerpo == null || cuerpo['secciones'] is! List) {
      throw ErrorFormato(
        'La respuesta de /home no tiene la clave "secciones" con una lista. '
        'Llego: ${_recorte(respuesta.data)}',
      );
    }

    return Vitrina.fromJson(cuerpo);
  }

  /// GET /categorias -> { data: [ {id, nombre, slug} ] }
  Future<List<Categoria>> categorias() async {
    final respuesta = await _api.enviar((dio) => dio.get('/categorias'));

    final cuerpo = respuesta.data;
    if (cuerpo is! Map || cuerpo['data'] is! List) {
      throw ErrorFormato(
        'La respuesta de /categorias no tiene la clave "data" con una lista. '
        'Llego: ${_recorte(cuerpo)}',
      );
    }

    return (cuerpo['data'] as List)
        .whereType<Map>()
        .map((fila) => Categoria.fromJson(Map<String, dynamic>.from(fila)))
        .toList();
  }

  /// GET /productos -> data + links + meta + filtros + promocion + ordenes
  ///
  /// `pagina` se manda como `?page=N` junto con los mismos filtros, y no se
  /// sigue el `links.next` de la respuesta: esas URL las arma Laravel con el
  /// host del request y seguirlas ataria la paginacion a ese host. El backend
  /// usa `withQueryString()`, asi que de todos modos hay que reenviar los
  /// filtros para que la pagina 2 no devuelva el catalogo entero.
  Future<ResultadoCatalogo> buscar(
    FiltrosCatalogo filtros, {
    int pagina = 1,
  }) async {
    final respuesta = await _api.enviar(
      (dio) => dio.get(
        '/productos',
        queryParameters: filtros.aQueryString(pagina: pagina),
      ),
    );

    final cuerpo = comoMapa(respuesta.data);

    if (cuerpo == null || cuerpo['data'] is! List) {
      throw ErrorFormato(
        'La respuesta de /productos no tiene la clave "data" con una lista. '
        'Llego: ${_recorte(respuesta.data)}',
      );
    }

    return ResultadoCatalogo.fromJson(cuerpo);
  }

  /// GET /productos/{id} -> { data: { ...producto, descripcion, promociones,
  /// relacionados } }
  ///
  /// El controlador devuelve el Resource directo, asi que Laravel lo envuelve
  /// en `data`, igual que en `/auth/yo`. Se acepta tambien el objeto plano por
  /// si en algun momento se envuelve distinto: el costo es una linea y evita
  /// que la ficha entera deje de abrir por un cambio de envoltorio.
  ///
  /// **Un 404 llega como [ErrorNoEncontrado]** y significa que el producto se
  /// despublico o se dio de baja: `show()` hace
  /// `abort_unless($producto->activo && $producto->publicado_app, 404)`. Es un
  /// caso real, no un error de programacion: la tarjeta pudo haberse dibujado
  /// con datos de hace un rato.
  Future<ProductoDetalle> producto(int id) async {
    final respuesta = await _api.enviar((dio) => dio.get('/productos/$id'));

    final cuerpo = comoMapa(respuesta.data);
    final datos = comoMapa(cuerpo?['data']) ?? cuerpo;

    if (datos == null || datos['id'] == null) {
      throw ErrorFormato(
        'La respuesta de /productos/$id no trae el producto. '
        'Llego: ${_recorte(respuesta.data)}',
      );
    }

    return ProductoDetalle.fromJson(datos);
  }

  /// GET /marcas -> { data: ["AMD", "Corsair", ...] }
  ///
  /// Texto libre, no una tabla: el backend lo saca con `distinct()` sobre la
  /// columna `marca` de los productos publicados, asi que viaja como lista de
  /// cadenas y no como recurso con id.
  Future<List<String>> marcas() async {
    final respuesta = await _api.enviar((dio) => dio.get('/marcas'));

    final cuerpo = comoMapa(respuesta.data);

    if (cuerpo == null || cuerpo['data'] is! List) {
      throw ErrorFormato(
        'La respuesta de /marcas no tiene la clave "data" con una lista. '
        'Llego: ${_recorte(respuesta.data)}',
      );
    }

    return (cuerpo['data'] as List)
        .map(comoTextoOpcional)
        .whereType<String>()
        .toList();
  }
}

/// Primeros caracteres del cuerpo, para que el mensaje de error diga algo
/// util cuando lo que volvio fue HTML en vez de JSON.
String _recorte(dynamic cuerpo) {
  final texto = '$cuerpo';
  return texto.length <= 160 ? texto : '${texto.substring(0, 160)}...';
}
