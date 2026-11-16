import 'package:intl/intl.dart';

/// Formato de importes y fechas para la interfaz.
///
/// `intl` ya estaba en el pubspec desde el paso 0 justamente para esto.
class Formato {
  const Formato._();

  /// El locale se fija a `es_AR` y no se toma del dispositivo: un teléfono
  /// configurado en inglés mostraría `$1,234.56`, que para un precio en pesos
  /// se lee mal.
  ///
  /// Esto funciona sin inicializar nada porque los símbolos NUMÉRICOS de todos
  /// los locales vienen compilados en `intl`. Con las fechas no pasa lo mismo:
  /// ver abajo.
  static final NumberFormat _pesos = NumberFormat.currency(
    locale: 'es_AR',
    symbol: '\$',
    decimalDigits: 2,
  );

  /// **Sin locale, y es a propósito.** `DateFormat` con un locale distinto del
  /// que viene cargado exige llamar a `initializeDateFormatting()` de
  /// `intl/date_symbol_data_local.dart` en el arranque de la app; sin eso tira
  /// `LocaleDataException` la primera vez que se formatea una fecha. Hoy nadie
  /// la llama, y no hace falta: estos patrones son puramente numéricos, así que
  /// dan el mismo resultado con cualquier locale cargado.
  ///
  /// El día que se quiera "16 de noviembre de 2026" —con el nombre del mes— sí
  /// hay que inicializar `es_AR` en `main()`. Mientras eso no pase, esta clase
  /// no ofrece un formato que dependa de nombres de meses o de días, para que
  /// nadie lo use sin darse cuenta.
  static final DateFormat _fecha = DateFormat('dd/MM/yyyy');

  static final DateFormat _fechaHora = DateFormat('dd/MM/yyyy HH:mm');

  /// `$ 1.234,56`.
  ///
  /// **No tiene versión para null a propósito.** Un importe ausente no se
  /// formatea como "$ 0,00" ni como cadena vacía: quien no tiene precio no
  /// muestra un precio, muestra otra cosa. De eso se encarga
  /// `PrecioProducto`.
  static String pesos(double importe) => _pesos.format(importe);

  /// `16/11/2026`. El mismo formato que usan las vistas Blade de compras, para
  /// que la app y la web no muestren la misma fecha de dos maneras.
  ///
  /// **Las fechas sí tienen versión para null**, al revés que los importes: una
  /// fecha ausente es un dato que falta y no una decisión de negocio, así que
  /// se muestra un guion y la pantalla sigue andando.
  ///
  /// El backend las manda en ISO 8601 con el offset de Buenos Aires;
  /// `toLocal()` las lleva a la zona del teléfono, que es lo que el cliente
  /// espera leer.
  static String fecha(DateTime? momento, {String siFalta = '—'}) {
    return momento == null ? siFalta : _fecha.format(momento.toLocal());
  }

  /// `16/11/2026 10:32`. Para los pagos, donde la hora distingue dos intentos
  /// del mismo día.
  static String fechaHora(DateTime? momento, {String siFalta = '—'}) {
    return momento == null ? siFalta : _fechaHora.format(momento.toLocal());
  }
}
