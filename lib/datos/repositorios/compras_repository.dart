import '../../core/api_client.dart';
import '../../core/errores.dart';
import '../modelos/compra.dart';
import '../modelos/compra_detalle.dart';
import '../modelos/conversiones.dart';
import '../modelos/pagina.dart';

/// Historial y detalle de compras del cliente: `/api/v1/compras`.
///
/// **Las dos rutas exigen sesión.** La cadena del backend es `auth:sanctum` +
/// `api.activo` + `api.ambito:tienda`, así que de acá pueden salir:
///
///   401   sesión vencida, token revocado o cuenta dada de baja
///   403   cuenta de gestión intentando entrar a la app de clientes
///   404   la compra no es de este cliente, no existe, o es un presupuesto
///
/// **Falta `api.verificado` a propósito y eso se nota acá**: a diferencia del
/// carrito, estas rutas NO pueden devolver `email_no_verificado`. Es la misma
/// regla que la web: mirar el historial no necesita correo confirmado, armar
/// un pedido sí. Un cliente que se registró, compró en el mostrador y todavía
/// no confirmó el correo tiene que poder ver esa compra, así que la pantalla
/// no mira `usuario.emailVerificado` antes de pedir.
///
/// Los errores los mapea [mapearError] y suben tipados: el notifier es el que
/// sabe qué hacer con cada uno.
///
/// **Sólo lectura.** No hay forma de cancelar ni modificar un pedido desde la
/// app, porque no hay endpoint: cancelar una venta pagada libera stock
/// comprometido y, con factura autorizada, exige nota de crédito.
class ComprasRepository {
  const ComprasRepository(this._api);

  final ApiClient _api;

  /// GET /compras
  ///
  /// **Nunca lleva un id de cliente**: el historial es siempre el de quien
  /// trae el token. No hay nada que manipular en la URL.
  ///
  /// `pagina` se manda como `?page=N` y no se siguen las URL de `links`:
  /// Laravel las arma con el host del request, y seguirlas ataría la
  /// paginación a ese host. Es el mismo criterio que `CatalogoRepository` y la
  /// razón por la que [Pagina] ignora `links`.
  ///
  /// **Un cliente sin compras no es un error**: responde 200 con `data` vacío.
  /// Tampoco lo es un usuario sin ficha en `clientes`.
  Future<Pagina<Compra>> historial({int pagina = 1}) async {
    final respuesta = await _api.enviar(
      (dio) => dio.get<dynamic>(
        '/compras',
        queryParameters: <String, dynamic>{'page': pagina},
      ),
    );

    final cuerpo = comoMapa(respuesta.data);

    // `data` es lo que siempre viene, incluso como lista vacía. Si no está, lo
    // que volvió no es esta API: casi siempre HTML de la web Blade o la página
    // de aviso de ngrok.
    if (cuerpo == null || cuerpo['data'] is! List) {
      throw ErrorFormato(
        'La respuesta de /compras no trae el historial. '
        'Llego: ${_recorte(respuesta.data)}',
      );
    }

    return Pagina<Compra>.fromJson(cuerpo, Compra.listaDe);
  }

  /// GET /compras/{id}
  ///
  /// **Un 404 no significa sólo "no existe".** El backend responde lo mismo
  /// para una compra de otro cliente —un 403 confirmaría que ese número de
  /// pedido existe— y para un presupuesto, que no es una compra. La app no
  /// necesita distinguirlos: en los tres casos el mensaje para el cliente es
  /// el mismo.
  Future<CompraDetalle> detalle(int compraId) async {
    final respuesta = await _api.enviar(
      (dio) => dio.get<dynamic>('/compras/$compraId'),
    );

    final cuerpo = comoMapa(respuesta.data);
    final datos = comoMapa(cuerpo?['data']) ?? cuerpo;

    if (datos == null || datos['id'] == null) {
      throw ErrorFormato(
        'La respuesta de /compras/$compraId no trae la compra. '
        'Llego: ${_recorte(respuesta.data)}',
      );
    }

    return CompraDetalle.fromJson(datos);
  }
}

/// Primeros caracteres del cuerpo, para que el mensaje diga algo util cuando
/// lo que volvio fue HTML en vez de JSON.
String _recorte(dynamic cuerpo) {
  final texto = '$cuerpo';
  return texto.length <= 160 ? texto : '${texto.substring(0, 160)}...';
}
