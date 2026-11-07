import '../../core/api_client.dart';
import '../../core/errores.dart';
import '../modelos/conversiones.dart';
import '../modelos/opcion_fiscal.dart';

/// `GET /datos-fiscales`: las dos listas que el formulario de registro
/// necesita para sus desplegables.
///
/// Ruta publica y de solo lectura. Es a proposito que no exija token:
/// pedirlo obligaria a tener cuenta para poder crear una cuenta.
class DatosFiscalesRepository {
  const DatosFiscalesRepository(this._api);

  final ApiClient _api;

  Future<DatosFiscales> obtener() async {
    final respuesta = await _api.enviar((dio) => dio.get('/datos-fiscales'));

    final cuerpo = comoMapa(respuesta.data);

    if (cuerpo == null ||
        cuerpo['tipos_documento'] is! List ||
        cuerpo['condiciones_iva'] is! List) {
      throw ErrorFormato(
        'La respuesta de /datos-fiscales no trae las dos listas esperadas. '
        '¿Aplicaste el parche de routes/api.php?',
      );
    }

    final datos = DatosFiscales.fromJson(cuerpo);

    if (datos.tiposDocumento.isEmpty || datos.condicionesIva.isEmpty) {
      throw const ErrorFormato(
        'El backend devolvió alguna de las listas fiscales vacía. '
        'Revisá que el seeder de tipos_documento y condiciones_iva haya corrido.',
      );
    }

    return datos;
  }
}
