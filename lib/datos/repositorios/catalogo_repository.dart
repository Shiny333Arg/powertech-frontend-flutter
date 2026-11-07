import '../../core/api_client.dart';
import '../../core/errores.dart';
import '../modelos/categoria.dart';
import '../modelos/conversiones.dart';
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
}

/// Primeros caracteres del cuerpo, para que el mensaje de error diga algo
/// util cuando lo que volvio fue HTML en vez de JSON.
String _recorte(dynamic cuerpo) {
  final texto = '$cuerpo';
  return texto.length <= 160 ? texto : '${texto.substring(0, 160)}...';
}
