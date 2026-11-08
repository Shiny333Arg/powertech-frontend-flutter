import '../../core/api_client.dart';
import '../../core/errores.dart';
import '../modelos/checkout.dart';
import '../modelos/conversiones.dart';

/// Centinela para distinguir "no mandar el campo" de "mandarlo en null".
///
/// El PATCH aplica sólo las claves presentes: omitir `observaciones` las deja
/// como estaban, mandarlas en null las borra. En Dart un parámetro
/// `String? observaciones` no puede expresar esa diferencia —null significa
/// las dos cosas— así que el default es este objeto y no null.
const Object _sinCambio = Object();

/// Checkout del cliente: `/api/v1/checkout`.
///
/// **Mismo middleware que el carrito**, así que salen los mismos errores
/// tipados: 401 sesión vencida, 403 de ámbito, 403 `email_no_verificado`,
/// 422 de validación. Los mapea [mapearError] y suben hasta el notifier.
///
/// **No hay recurso que nombrar en la URL.** El checkout es la vista previa
/// del carrito abierto de quien trae el token.
///
/// **Acá no se paga nada.** La preferencia de Mercado Pago es el paso 10;
/// este repositorio sólo consulta el resumen y guarda las preferencias de
/// entrega.
class CheckoutRepository {
  const CheckoutRepository(this._api);

  final ApiClient _api;

  /// GET /checkout
  ///
  /// Los precios que vuelven son los vigentes en este momento, no los de
  /// cuando se armó el carrito.
  Future<ResumenCheckout> ver() async {
    final respuesta = await _api.enviar((dio) => dio.get('/checkout'));

    return _leer(respuesta.data, 'GET /checkout');
  }

  /// PATCH /checkout
  ///
  /// Guarda el modo de entrega y las observaciones **en el carrito**, que es
  /// de donde las va a leer el webhook de Mercado Pago: llega desde los
  /// servidores de MP, sin sesión, y no tiene otro lugar de donde sacarlas.
  ///
  /// Manda sólo lo que cambió. Para borrar las observaciones hay que pasar
  /// `observaciones: null` explícitamente; omitirlas las deja intactas.
  ///
  /// No cambia el estado del carrito: elegir cómo retirar no compromete
  /// nada y el cliente puede volver atrás. El salto a `en_checkout` ocurre al
  /// crear la preferencia de pago, en el paso 10.
  Future<ResumenCheckout> guardarPreferencias({
    String? modoEntrega,
    Object? observaciones = _sinCambio,
  }) async {
    final cuerpo = <String, dynamic>{};

    if (modoEntrega != null) {
      cuerpo['modo_entrega'] = modoEntrega;
    }

    if (!identical(observaciones, _sinCambio)) {
      cuerpo['observaciones'] = observaciones;
    }

    final respuesta = await _api.enviar(
      (dio) => dio.patch('/checkout', data: cuerpo),
    );

    return _leer(respuesta.data, 'PATCH /checkout');
  }

  /// Desenvuelve la respuesta y la convierte en [ResumenCheckout].
  ///
  /// Se acepta el objeto plano además del envuelto en `data`, igual que en
  /// `CarritoRepository`: una línea que evita que la pantalla entera deje de
  /// abrir por un cambio de envoltorio.
  ResumenCheckout _leer(dynamic cuerpo, String ruta) {
    final raiz = comoMapa(cuerpo);
    final datos = comoMapa(raiz?['data']) ?? raiz;

    // `carrito` y `bloqueos` son las dos claves que siempre vienen, con o sin
    // problemas. Si falta alguna, lo que llegó no es el checkout: lo más
    // probable es que sea HTML, de pegarle a una URL que no es la API.
    if (datos == null ||
        comoMapa(datos['carrito']) == null ||
        datos['bloqueos'] is! List) {
      throw ErrorFormato(
        'La respuesta de $ruta no trae el resumen del checkout. '
        'Llego: ${_recorte(cuerpo)}',
      );
    }

    return ResumenCheckout.fromJson(datos);
  }
}

/// Primeros caracteres del cuerpo, para que el mensaje diga algo util cuando
/// lo que volvio fue HTML en vez de JSON.
String _recorte(dynamic cuerpo) {
  final texto = '$cuerpo';
  return texto.length <= 160 ? texto : '${texto.substring(0, 160)}...';
}
