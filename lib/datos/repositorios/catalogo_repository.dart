import '../../core/api_client.dart';
import '../../core/errores.dart';
import '../modelos/categoria.dart';

/// Acceso al catalogo publico. Todas estas rutas aceptan token pero no lo
/// exigen: con token vencido responden 200 tratando al visitante como
/// invitado, nunca 401.
class CatalogoRepository {
  const CatalogoRepository(this._api);

  final ApiClient _api;

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
