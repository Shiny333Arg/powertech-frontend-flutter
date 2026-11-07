import 'dart:developer' as developer;

import 'package:dio/dio.dart';

import 'almacenamiento.dart';
import 'config.dart';
import 'errores.dart';

/// Cliente HTTP unico de la app.
///
/// Un solo Dio con la URL base de [Config] y dos interceptores:
///
///  1. Adjunta `Authorization: Bearer <token>` si hay token guardado.
///     Las rutas de catalogo son publicas con autenticacion OPCIONAL, asi
///     que mandar el token de mas no rompe nada: le devuelve precios al
///     cliente logueado y lo ignora si vencio.
///  2. Log de desarrollo.
///
/// El mapeo de DioException a [ErrorApi] se hace en [enviar], no en un
/// interceptor, para que el stack trace del error quede en el repositorio
/// que hizo la llamada.
class ApiClient {
  ApiClient({required AlmacenSeguro almacen, Dio? dio})
      : _almacen = almacen,
        dio = dio ?? Dio() {
    this.dio.options
      ..baseUrl = Config.urlBaseApi
      ..connectTimeout = const Duration(milliseconds: Config.timeoutConexionMs)
      ..receiveTimeout = const Duration(milliseconds: Config.timeoutRespuestaMs)
      ..headers.addAll(const {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        // Evita la pagina intersticial de aviso de ngrok, que devolveria
        // HTML donde esperamos JSON.
        'ngrok-skip-browser-warning': 'true',
      })
      // Nosotros decidimos que hacer con cada codigo; que Dio no tire
      // excepcion por 4xx antes de que podamos leer el cuerpo.
      ..validateStatus = (codigo) => codigo != null && codigo < 500;

    this.dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (opciones, handler) async {
              final token = await _almacen.leerToken();
              if (token != null && token.isNotEmpty) {
                opciones.headers['Authorization'] = 'Bearer $token';
              }
              _log('--> ${opciones.method} ${opciones.uri}');
              handler.next(opciones);
            },
            onResponse: (respuesta, handler) {
              _log(
                '<-- ${respuesta.statusCode} '
                '${respuesta.requestOptions.uri}',
              );
              handler.next(respuesta);
            },
            onError: (error, handler) {
              _log('<-- ERROR ${error.requestOptions.uri}: ${error.message}');
              handler.next(error);
            },
          ),
        );
  }

  final Dio dio;
  final AlmacenSeguro _almacen;

  /// Ejecuta una llamada y normaliza el resultado.
  ///
  /// Con `validateStatus` abierto hasta 499, un 401/403/422 llega como
  /// respuesta normal: hay que revisarlo a mano y convertirlo en [ErrorApi].
  Future<Response<dynamic>> enviar(
    Future<Response<dynamic>> Function(Dio dio) llamada,
  ) async {
    try {
      final respuesta = await llamada(dio);
      final codigo = respuesta.statusCode ?? 0;

      if (codigo >= 400) {
        throw mapearError(
          DioException.badResponse(
            statusCode: codigo,
            requestOptions: respuesta.requestOptions,
            response: respuesta,
          ),
        );
      }

      return respuesta;
    } on DioException catch (e) {
      throw mapearError(e);
    }
  }

  void _log(String mensaje) {
    if (Config.logHttp) {
      developer.log(mensaje, name: 'api');
    }
  }
}
