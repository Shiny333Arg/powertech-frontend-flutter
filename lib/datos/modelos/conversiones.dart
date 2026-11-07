/// Conversores compartidos por los `fromJson` escritos a mano.
///
/// Existen porque PHP y PDO no son consistentes con los tipos: un `id` puede
/// llegar como numero o como string segun el driver, y un booleano como
/// `true`, `1` o `"1"`. Sin esto, cada modelo repetiria el mismo `is int ?`
/// y el primero que se olvide revienta en tiempo de ejecucion.
library;

/// Entero obligatorio. Devuelve 0 si no hay forma de interpretarlo, que es
/// un id invalido y se nota enseguida.
int comoEntero(dynamic valor) {
  if (valor is int) return valor;
  if (valor is num) return valor.toInt();
  return int.tryParse('$valor') ?? 0;
}

/// Entero que puede faltar. Distinto de [comoEntero]: aca `null` es un valor
/// legitimo y no un error.
int? comoEnteroOpcional(dynamic valor) {
  if (valor == null) return null;
  if (valor is int) return valor;
  if (valor is num) return valor.toInt();
  return int.tryParse('$valor');
}

/// Importe que puede faltar.
///
/// **La clave ausente y el cero son cosas distintas y por eso devuelve
/// `double?`.** Al invitado no le llega `precio`, y un default 0 haria que la
/// vitrina mostrara "$ 0,00", o sea "gratis". No hay version no-opcional de
/// esta funcion a proposito: ningun importe de este contrato es obligatorio.
///
/// Laravel manda `round($lista, 2)`, que serializa 30000 como `30000` (int) y
/// 104.55 como `104.55` (double). Los dos tienen que entrar.
double? comoDecimalOpcional(dynamic valor) {
  if (valor == null) return null;
  if (valor is double) return valor;
  if (valor is num) return valor.toDouble();
  return double.tryParse('$valor');
}

/// Texto obligatorio. Una clave ausente se vuelve cadena vacia.
String comoTexto(dynamic valor) => valor == null ? '' : '$valor';

/// Texto que puede faltar. La cadena vacia se trata como ausente: Laravel
/// devuelve `null` para un `telefono` sin cargar, pero un formulario puede
/// haber guardado `""`, y para la UI significan lo mismo.
String? comoTextoOpcional(dynamic valor) {
  if (valor == null) return null;
  final texto = '$valor'.trim();
  return texto.isEmpty ? null : texto;
}

/// Booleano tolerante: acepta `true`, `1` y `"1"`.
bool comoBool(dynamic valor) {
  if (valor is bool) return valor;
  if (valor is num) return valor != 0;
  final texto = '$valor'.toLowerCase();
  return texto == 'true' || texto == '1';
}

/// Fecha ISO 8601 que puede faltar. `expira_el` llega como `null` cuando el
/// token no tiene vencimiento.
DateTime? comoFechaOpcional(dynamic valor) {
  if (valor == null) return null;
  if (valor is DateTime) return valor;
  return DateTime.tryParse('$valor');
}

/// Mapa anidado, o null si la clave no vino o no es un objeto.
Map<String, dynamic>? comoMapa(dynamic valor) {
  if (valor is Map<String, dynamic>) return valor;
  if (valor is Map) return Map<String, dynamic>.from(valor);
  return null;
}
