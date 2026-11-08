import '../../core/api_client.dart';
import '../../core/errores.dart';
import '../modelos/carrito.dart';
import '../modelos/conversiones.dart';

/// Carrito del cliente: `/api/v1/carrito`.
///
/// **Las cinco rutas exigen sesión**, a diferencia del catálogo. La cadena del
/// backend es `auth:sanctum` + `api.activo` + `api.ambito:tienda` +
/// `api.verificado`, así que de acá pueden salir cuatro errores que el
/// catálogo nunca produce:
///
///   401                        sesión vencida o cuenta dada de baja
///   403 sin codigo             cuenta de gestión
///   403 email_no_verificado    falta confirmar el correo
///   404                        la línea no es de este cliente, o no existe
///
/// Los mapea [mapearError] y no hace falta tratarlos acá: suben tipados hasta
/// el notifier, que es el que sabe qué hacer con cada uno.
///
/// **El carrito nunca se nombra en la URL.** Siempre es el carrito abierto de
/// quien trae el token; no hay id que mandar ni que manipular. Lo único que
/// lleva id es la línea.
///
/// **Las cinco operaciones devuelven el carrito completo y recalculado**, así
/// que ninguna necesita un `ver()` de seguimiento. Eso no es una comodidad:
/// es lo que garantiza que los totales en pantalla sean siempre los que
/// acaba de calcular el backend.
class CarritoRepository {
  const CarritoRepository(this._api);

  final ApiClient _api;

  /// GET /carrito
  ///
  /// **Nunca da 404**: un cliente que no tiene carrito recibe uno vacío
  /// recién creado. No hay caso "todavía no compré nunca" que manejar.
  Future<Carrito> ver() async {
    final respuesta = await _api.enviar((dio) => dio.get('/carrito'));

    return _leer(respuesta.data, 'GET /carrito');
  }

  /// POST /carrito
  ///
  /// Si el producto ya estaba, el backend **suma** sobre la línea existente
  /// en vez de crear otra: `carrito_lineas` tiene UK `(carrito_id,
  /// producto_id)`.
  ///
  /// Responde 201 y no 200. El cuerpo es el mismo carrito completo.
  ///
  /// Un producto despublicado o dado de baja sale por [ErrorValidacion] con
  /// el campo `producto_id`, no por 404.
  Future<Carrito> agregar({
    required int productoId,
    required int cantidad,
  }) async {
    final respuesta = await _api.enviar(
      (dio) => dio.post(
        '/carrito',
        data: {'producto_id': productoId, 'cantidad': cantidad},
      ),
    );

    return _leer(respuesta.data, 'POST /carrito');
  }

  /// PATCH /carrito/{linea}
  ///
  /// **Fija** la cantidad, no la incrementa.
  ///
  /// `cantidad` tiene que estar entre 1 y 99: el backend devuelve 422 para 0,
  /// porque quitar es [quitar] y no una actualización disfrazada.
  Future<Carrito> cambiarCantidad({
    required int lineaId,
    required int cantidad,
  }) async {
    final respuesta = await _api.enviar(
      (dio) => dio.patch('/carrito/$lineaId', data: {'cantidad': cantidad}),
    );

    return _leer(respuesta.data, 'PATCH /carrito/$lineaId');
  }

  /// DELETE /carrito/{linea}
  Future<Carrito> quitar(int lineaId) async {
    final respuesta = await _api.enviar(
      (dio) => dio.delete('/carrito/$lineaId'),
    );

    return _leer(respuesta.data, 'DELETE /carrito/$lineaId');
  }

  /// DELETE /carrito
  ///
  /// El carrito **no se borra**: conserva su id y queda utilizable. Es
  /// idempotente, así que no hay que preguntar si ya estaba vacío.
  Future<Carrito> vaciar() async {
    final respuesta = await _api.enviar((dio) => dio.delete('/carrito'));

    return _leer(respuesta.data, 'DELETE /carrito');
  }

  /// Desenvuelve la respuesta y la convierte en [Carrito].
  ///
  /// El controlador devuelve el Resource directo, así que Laravel lo envuelve
  /// en `data`. Se acepta también el objeto plano, igual que hace
  /// `CatalogoRepository.producto()`: es una línea y evita que la pantalla
  /// entera deje de abrir por un cambio de envoltorio.
  Carrito _leer(dynamic cuerpo, String ruta) {
    final raiz = comoMapa(cuerpo);
    final datos = comoMapa(raiz?['data']) ?? raiz;

    // `lineas` es la clave que siempre viene, incluso vacía. `id` no sirve
    // para validar: un carrito recién creado lo tiene, pero si el cuerpo
    // fuera HTML tampoco habría `lineas`.
    if (datos == null || datos['lineas'] is! List) {
      throw ErrorFormato(
        'La respuesta de $ruta no trae el carrito. '
        'Llego: ${_recorte(cuerpo)}',
      );
    }

    return Carrito.fromJson(datos);
  }
}

/// Primeros caracteres del cuerpo, para que el mensaje diga algo util cuando
/// lo que volvio fue HTML en vez de JSON.
String _recorte(dynamic cuerpo) {
  final texto = '$cuerpo';
  return texto.length <= 160 ? texto : '${texto.substring(0, 160)}...';
}
