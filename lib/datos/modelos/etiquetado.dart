import 'conversiones.dart';

/// Un valor del backend junto con su texto para mostrar: `{valor, etiqueta}`.
///
/// Es la forma en que la API devuelve los enums de PHP cuando la app necesita
/// las dos cosas: el `valor` crudo para comparar y la `etiqueta` para pintar.
/// En compras aparece en el canal, el modo de entrega, el método de pago y el
/// estado de cada pago y comprobante.
///
/// **La etiqueta la escribe el backend y no se traduce acá.** Sale de
/// `ModoEntrega::etiqueta()`, `MetodoPago::etiqueta()` y compañía, que son los
/// mismos textos que muestra la web. Un `switch` en Dart sobre el `valor`
/// serviría hasta el día que alguien renombre una etiqueta en PHP y la app
/// siga diciendo lo de antes.
///
/// **Y por eso la app compara por `valor`, nunca por `etiqueta`.** El valor es
/// la columna de la base; la etiqueta es copy y puede cambiar.
///
/// `OpcionEntrega`, en `checkout.dart`, es esta misma forma y es anterior. No
/// se unificó a propósito: pertenece al contrato del checkout, que ya está
/// entregado y probado.
class Etiquetado {
  const Etiquetado({required this.valor, required this.etiqueta});

  /// El valor de la columna: `retiro`, `online`, `acreditado`...
  final String valor;

  /// El texto que lee el cliente.
  final String etiqueta;

  bool get estaVacio => valor.isEmpty;

  bool es(String otro) => valor == otro;

  /// Null cuando la clave no vino o no es un objeto. Quien lo necesite
  /// obligatorio usa [Etiquetado.obligatorio].
  static Etiquetado? opcional(dynamic crudo) {
    final mapa = comoMapa(crudo);

    if (mapa == null) return null;

    return Etiquetado(
      valor: comoTexto(mapa['valor']),
      etiqueta: comoTexto(mapa['etiqueta']),
    );
  }

  /// Para las claves que el contrato garantiza. Si faltara, devuelve un
  /// etiquetado vacío en lugar de reventar: una pantalla sin la palabra
  /// "Retiro en local" sigue siendo utilizable, una que no abre no.
  static Etiquetado obligatorio(dynamic crudo) =>
      opcional(crudo) ?? const Etiquetado(valor: '', etiqueta: '');
}
