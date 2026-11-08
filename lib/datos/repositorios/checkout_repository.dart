import '../../core/api_client.dart';
import '../../core/errores.dart';
import '../modelos/checkout.dart';
import '../modelos/conversiones.dart';
import '../modelos/pago.dart';

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
/// **Las credenciales de Mercado Pago no pasan por acá.** El `access_token`
/// vive en Laravel; lo único que la app recibe es la URL pública del checkout
/// y lo único que manda es la confirmación del cliente.
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

  /// POST /checkout/pagar
  ///
  /// Pide la orden de cobro. El backend revalida todo —carrito, productos,
  /// precios, datos fiscales— y calcula el importe desde cero: nada de lo que
  /// mande la app participa del total.
  ///
  /// **No crea el pedido.** Devuelve a dónde mandar al cliente a pagar; la
  /// venta nace cuando el pago se acredita, por el webhook.
  ///
  /// `confirma` es la conformidad explícita del cliente con que el pago es
  /// previo al pedido. El backend la exige.
  ///
  /// Errores propios de esta llamada, los dos como [ErrorServidor] con su
  /// `codigo`, porque `errores.dart` manda ahí todo lo que no sean los
  /// códigos que ya tenían clase propia:
  ///
  ///   409  el carrito dejó de ser pagable mientras tanto. El cuerpo trae
  ///        `bloqueos`, pero la pantalla no los lee de acá: vuelve a pedir el
  ///        checkout y los muestra donde ya los muestra. Una segunda forma de
  ///        dibujar los mismos bloqueos es una segunda forma de que queden
  ///        distintos.
  ///   502  Mercado Pago no respondió. Es reintentable, y por eso el backend
  ///        lo distingue de un 500.
  Future<InicioPago> iniciarPago({
    String? modoEntrega,
    Object? observaciones = _sinCambio,
  }) async {
    final cuerpo = <String, dynamic>{'confirma': true};

    if (modoEntrega != null) {
      cuerpo['modo_entrega'] = modoEntrega;
    }

    if (!identical(observaciones, _sinCambio)) {
      cuerpo['observaciones'] = observaciones;
    }

    final respuesta = await _api.enviar(
      (dio) => dio.post('/checkout/pagar', data: cuerpo),
    );

    final datos = _desenvolver(respuesta.data, 'POST /checkout/pagar', 'url_pago');

    return InicioPago.fromJson(datos);
  }

  /// GET /checkout/estado
  ///
  /// En qué quedó el último intento de pago. Lo decide el backend mirando la
  /// base y, si hace falta, preguntándole a Mercado Pago por la referencia
  /// del carrito.
  ///
  /// **Es lo que se consulta al volver del navegador.** No se le cree nada a
  /// la URL de retorno: puede venir editada y puede no llegar nunca.
  Future<EstadoPago> estadoDelPago() async {
    final respuesta = await _api.enviar((dio) => dio.get('/checkout/estado'));

    final datos = _desenvolver(respuesta.data, 'GET /checkout/estado', 'estado');

    return EstadoPago.fromJson(datos);
  }

  /// Saca el objeto de adentro de `data` y comprueba que traiga [claveEsperada].
  ///
  /// Mismo criterio que [_leer]: la clave que se exige es una que el contrato
  /// siempre manda, así una respuesta que no sea la esperada —HTML de una URL
  /// equivocada, el aviso de ngrok— falla con un mensaje que dice qué llegó
  /// en lugar de un error de casteo tres capas más arriba.
  Map<String, dynamic> _desenvolver(
    dynamic cuerpo,
    String ruta,
    String claveEsperada,
  ) {
    final raiz = comoMapa(cuerpo);
    final datos = comoMapa(raiz?['data']) ?? raiz;

    if (datos == null || !datos.containsKey(claveEsperada)) {
      throw ErrorFormato(
        'La respuesta de $ruta no tiene la forma esperada. '
        'Llego: ${_recorte(cuerpo)}',
      );
    }

    return datos;
  }
}

/// Primeros caracteres del cuerpo, para que el mensaje diga algo util cuando
/// lo que volvio fue HTML en vez de JSON.
String _recorte(dynamic cuerpo) {
  final texto = '$cuerpo';
  return texto.length <= 160 ? texto : '${texto.substring(0, 160)}...';
}
