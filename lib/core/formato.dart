import 'package:intl/intl.dart';

/// Formato de importes en pesos argentinos: `$ 1.234,56`.
///
/// `intl` ya estaba en el pubspec desde el paso 0 justamente para esto. El
/// locale se fija a `es_AR` y no se toma del dispositivo: un teléfono
/// configurado en inglés mostraría `$1,234.56`, que para un precio en pesos
/// se lee mal.
class Formato {
  const Formato._();

  static final NumberFormat _pesos = NumberFormat.currency(
    locale: 'es_AR',
    symbol: '\$',
    decimalDigits: 2,
  );

  /// `$ 1.234,56`.
  ///
  /// **No tiene versión para null a propósito.** Un importe ausente no se
  /// formatea como "$ 0,00" ni como cadena vacía: quien no tiene precio no
  /// muestra un precio, muestra otra cosa. De eso se encarga
  /// `PrecioProducto`.
  static String pesos(double importe) => _pesos.format(importe);
}
