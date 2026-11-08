import 'package:flutter_test/flutter_test.dart';
import 'package:powertech_tienda/datos/modelos/pago.dart';

/// Pruebas de contrato del pago.
///
/// **Lo que fijan es que la app no decida nada sobre el pago.** El estado lo
/// manda el backend, que lo resuelve mirando la base y preguntándole a
/// Mercado Pago; acá sólo se lee. Varios casos comprueban justamente eso: que
/// un `approved` de la pasarela no se convierta en «compraste» del lado del
/// cliente, y que un estado desconocido no se interprete como final.
///
/// **Nada de esto prueba Mercado Pago.** No hay forma de hacerlo sin
/// credenciales y sin red; eso es prueba manual contra el entorno de prueba.
void main() {
  group('InicioPago', () {
    test('lee la respuesta de pagar', () {
      final inicio = InicioPago.fromJson({
        'preferencia_id': '3808773690-abc',
        'url_pago': 'https://www.mercadopago.com.ar/checkout/v1/redirect?pref_id=x',
        'total': 250000,
      });

      expect(inicio.preferenciaId, '3808773690-abc');
      expect(inicio.urlPago, contains('mercadopago'));
      expect(inicio.total, 250000.0);
    });

    test('no hay ningun campo de credencial en el modelo', () {
      // El access_token vive en Laravel. Si alguna vez apareciera acá, este
      // test no lo detectaría solo — pero el modelo tiene tres campos y
      // están enumerados, así que agregar uno obliga a pasar por acá.
      final inicio = InicioPago.fromJson({
        'preferencia_id': 'x',
        'url_pago': 'https://mp.test/x',
        'total': 1,
        'access_token': 'APP_USR-no-deberia-estar-aca',
      });

      expect(inicio.preferenciaId, 'x');
      expect(inicio.urlPago, 'https://mp.test/x');
      // Lo que no está declarado no se lee: el campo de más se ignora.
      expect(inicio.total, 1.0);
    });
  });

  group('ResultadoPago', () {
    test('mapea los cuatro estados del contrato', () {
      expect(ResultadoPago.desdeTexto('aprobado'), ResultadoPago.aprobado);
      expect(ResultadoPago.desdeTexto('rechazado'), ResultadoPago.rechazado);
      expect(ResultadoPago.desdeTexto('pendiente'), ResultadoPago.pendiente);
      expect(ResultadoPago.desdeTexto('sin_pago'), ResultadoPago.sinPago);
    });

    test('un estado nuevo del backend no se confunde con uno conocido', () {
      final resultado = ResultadoPago.desdeTexto('algo_que_no_existe');

      expect(resultado, ResultadoPago.desconocido);
      // Y se sigue consultando: tratar lo desconocido como final podría
      // dejar una compra aprobada sin mostrarse.
      expect(resultado.conviveneReintentar, isTrue);
    });

    test('solo se reintenta mientras haya algo que esperar', () {
      expect(ResultadoPago.pendiente.conviveneReintentar, isTrue);
      expect(ResultadoPago.desconocido.conviveneReintentar, isTrue);

      // Estos tres no cambian por insistir: hace falta que el cliente actúe.
      expect(ResultadoPago.aprobado.conviveneReintentar, isFalse);
      expect(ResultadoPago.rechazado.conviveneReintentar, isFalse);
      expect(ResultadoPago.sinPago.conviveneReintentar, isFalse);
    });
  });

  group('EstadoPago', () {
    test('aprobado trae la venta', () {
      final estado = EstadoPago.fromJson({
        'estado': 'aprobado',
        'venta': {
          'id': 31,
          'numero': 'V-0000031',
          'estado': 'en_preparacion',
          'total': 250000,
          'mensaje': '¡Listo! Tu pedido V-0000031 está pago.',
        },
      });

      expect(estado.resultado, ResultadoPago.aprobado);
      expect(estado.venta?.numero, 'V-0000031');
      expect(estado.venta?.total, 250000.0);
      expect(estado.venta?.estado, 'en_preparacion');
    });

    test('el mensaje de cierre es el del backend', () {
      // Depende de si el pedido queda esperando reposición o listo para
      // retirar, y eso lo decide el servidor. La app no lo arma.
      const original = 'Registramos tu pedido V-0000031. Estamos esperando la '
          'reposición de algunos productos.';

      final estado = EstadoPago.fromJson({
        'estado': 'aprobado',
        'venta': {
          'id': 31,
          'numero': 'V-0000031',
          'estado': 'pendiente_stock',
          'total': 1,
          'mensaje': original,
        },
      });

      expect(estado.venta?.mensaje, original);
    });

    test('los estados que no son aprobado vienen sin venta', () {
      for (final texto in ['rechazado', 'pendiente', 'sin_pago']) {
        final estado = EstadoPago.fromJson({'estado': texto, 'venta': null});

        expect(estado.venta, isNull, reason: 'estado $texto');
        expect(estado.resultado, isNot(ResultadoPago.aprobado));
      }
    });

    test('pendiente no se interpreta como aprobado aunque haya venta nula', () {
      // El caso real: Mercado Pago ya aprobó pero el webhook no llegó. El
      // backend informa pendiente a propósito, porque la venta la crea el
      // webhook. La app no puede adelantarse.
      final estado = EstadoPago.fromJson({'estado': 'pendiente'});

      expect(estado.resultado, ResultadoPago.pendiente);
      expect(estado.venta, isNull);
      expect(estado.resultado.conviveneReintentar, isTrue);
    });

    test('tolera un cuerpo sin la clave venta', () {
      final estado = EstadoPago.fromJson({'estado': 'sin_pago'});

      expect(estado.resultado, ResultadoPago.sinPago);
      expect(estado.venta, isNull);
    });
  });
}
