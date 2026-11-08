import 'package:flutter_test/flutter_test.dart';
import 'package:powertech_tienda/datos/modelos/bloqueo_checkout.dart';
import 'package:powertech_tienda/datos/modelos/checkout.dart';

/// Pruebas de contrato del checkout.
///
/// Mismo criterio que las del carrito: verifican que la app lea exactamente
/// lo que manda `CheckoutResource` y, sobre todo, que **no derive nada**.
/// Varios casos usan combinaciones deliberadamente contradictorias —un
/// `puede_pagar` que no se condice con los bloqueos, un carrito impecable con
/// el pago bloqueado— para comprobar que la app respeta al servidor en vez de
/// razonar por su cuenta.
void main() {
  group('ResumenCheckout', () {
    test('lee el resumen completo', () {
      final resumen = ResumenCheckout.fromJson(_checkoutListo);

      expect(resumen.puedePagar, isTrue);
      expect(resumen.bloqueos, isEmpty);
      expect(resumen.carrito.total, 250000.0);
      expect(resumen.carrito.lineas, hasLength(1));
      expect(resumen.entrega.modo, 'retiro');
      expect(resumen.facturacion?.razonSocial, 'Pérez, Juan');
    });

    test('el carrito se parsea con el modelo del carrito, sin adaptarlo', () {
      final resumen = ResumenCheckout.fromJson(_checkoutListo);

      // Si esto compila y pasa, el ProductoResource anidado llegó entero.
      expect(resumen.carrito.lineas.first.producto?.nombre,
          'Monitor Samsung 24"');
      expect(resumen.carrito.lineas.first.subtotal, 250000.0);
      expect(resumen.carrito.puedeComprar, isTrue);
    });

    test('puede_pagar se lee, no se deriva de los bloqueos', () {
      // Combinación imposible a propósito: si la app dedujera la bandera
      // mirando la lista, diría false. El backend manda true.
      final resumen = ResumenCheckout.fromJson({
        ..._checkoutListo,
        'puede_pagar': true,
        'bloqueos': [
          {'codigo': 'carrito_vacio', 'mensaje': 'Tu carrito está vacío.'},
        ],
      });

      expect(resumen.puedePagar, isTrue);
      expect(resumen.bloqueos, hasLength(1));
    });

    test('puede_pagar es independiente de puede_comprar del carrito', () {
      // Carrito impecable, cliente que no puede facturar. Es el caso real
      // del responsable inscripto sin CUIT.
      final resumen = ResumenCheckout.fromJson({
        ..._checkoutListo,
        'puede_pagar': false,
        'facturacion': null,
        'bloqueos': [
          {
            'codigo': 'facturacion_incompleta',
            'mensaje': 'Como responsable inscripto necesitás tener cargado tu '
                'CUIT para que podamos facturarte.',
          },
        ],
      });

      expect(resumen.carrito.puedeComprar, isTrue);
      expect(resumen.puedePagar, isFalse);
    });

    test('tolera facturacion en null', () {
      final resumen = ResumenCheckout.fromJson({
        ..._checkoutListo,
        'facturacion': null,
      });

      expect(resumen.facturacion, isNull);
    });

    test('acepta booleanos como 1 y 0', () {
      final resumen = ResumenCheckout.fromJson({
        ..._checkoutListo,
        'puede_pagar': 0,
      });

      expect(resumen.puedePagar, isFalse);
    });
  });

  group('EntregaCheckout', () {
    test('lee el modo elegido y las opciones', () {
      final entrega = ResumenCheckout.fromJson(_checkoutListo).entrega;

      expect(entrega.modo, 'retiro');
      expect(entrega.estaElegido, isTrue);
      expect(entrega.modosDisponibles, hasLength(1));
      expect(entrega.modosDisponibles.first.etiqueta, 'Retiro en local');
    });

    test('un modo sin elegir no se da por elegido', () {
      final entrega = ResumenCheckout.fromJson({
        ..._checkoutListo,
        'entrega': {
          'modo': null,
          'observaciones': null,
          'modos_disponibles': [
            {'valor': 'retiro', 'etiqueta': 'Retiro en local'},
          ],
        },
      }).entrega;

      expect(entrega.modo, isNull);
      expect(entrega.estaElegido, isFalse);
      // Aunque haya una sola opción: elegirla es un acto del cliente, porque
      // esa columna la lee el webhook para armar la venta.
      expect(entrega.modosDisponibles, hasLength(1));
    });

    test('las opciones salen del backend y pueden ser más de una', () {
      final entrega = ResumenCheckout.fromJson({
        ..._checkoutListo,
        'entrega': {
          'modo': 'envio',
          'observaciones': null,
          'modos_disponibles': [
            {'valor': 'retiro', 'etiqueta': 'Retiro en local'},
            {'valor': 'envio', 'etiqueta': 'Envío a domicilio'},
          ],
        },
      }).entrega;

      expect(entrega.modosDisponibles, hasLength(2));
      expect(entrega.modo, 'envio');
    });
  });

  group('DatosFacturacion', () {
    test('arma el documento para mostrar', () {
      final datos = ResumenCheckout.fromJson(_checkoutListo).facturacion!;

      expect(datos.documento, 'DNI 30111222');
    });

    test('sin tipo de documento muestra solo el número', () {
      final datos = DatosFacturacion.fromJson({
        'razon_social': 'X',
        'tipo_documento': null,
        'nro_doc': '30111222',
        'condicion_iva': null,
      });

      expect(datos.documento, '30111222');
    });

    test('sin numero no hay documento que mostrar', () {
      final datos = DatosFacturacion.fromJson({
        'razon_social': 'X',
        'tipo_documento': 'DNI',
        'nro_doc': null,
        'condicion_iva': null,
      });

      expect(datos.documento, isNull);
    });
  });

  group('BloqueoCheckout', () {
    test('cada codigo conocido sabe a donde mandar al cliente', () {
      expect(_destinoDe('carrito_vacio'), DestinoBloqueo.catalogo);
      expect(_destinoDe('producto_no_disponible'), DestinoBloqueo.carrito);
      expect(_destinoDe('carrito_convertido'), DestinoBloqueo.carrito);
      expect(_destinoDe('carrito_no_disponible'), DestinoBloqueo.carrito);
      expect(_destinoDe('sin_datos_fiscales'), DestinoBloqueo.perfil);
      expect(_destinoDe('facturacion_incompleta'), DestinoBloqueo.perfil);
    });

    test('un codigo nuevo no rompe la pantalla', () {
      final bloqueo = BloqueoCheckout.fromJson({
        'codigo': 'algo_que_todavia_no_existe',
        'mensaje': 'Motivo nuevo del backend.',
      });

      expect(bloqueo.destino, DestinoBloqueo.desconocido);
      // Sin botón: inventar un destino sería adivinar.
      expect(bloqueo.textoAccion, isNull);
      // Pero el mensaje se muestra igual.
      expect(bloqueo.mensaje, 'Motivo nuevo del backend.');
    });

    test('el mensaje es el del backend, no uno propio', () {
      const original = 'Monitor Samsung 24" ya no está disponible en la '
          'tienda. Quitalo del carrito para seguir.';

      final bloqueo = BloqueoCheckout.fromJson({
        'codigo': 'producto_no_disponible',
        'mensaje': original,
      });

      expect(bloqueo.mensaje, original);
    });

    test('los codigos conocidos tienen texto de accion', () {
      for (final codigo in [
        'carrito_vacio',
        'producto_no_disponible',
        'sin_datos_fiscales',
      ]) {
        expect(
          BloqueoCheckout(codigo: codigo, mensaje: 'x').textoAccion,
          isNotNull,
          reason: 'el codigo $codigo deberia ofrecer una accion',
        );
      }
    });

    test('se leen todos los bloqueos, no solo el primero', () {
      final resumen = ResumenCheckout.fromJson({
        ..._checkoutListo,
        'puede_pagar': false,
        'bloqueos': [
          {'codigo': 'carrito_vacio', 'mensaje': 'Tu carrito está vacío.'},
          {
            'codigo': 'sin_datos_fiscales',
            'mensaje': 'Para comprar necesitás completar tus datos.',
          },
        ],
      });

      expect(resumen.bloqueos, hasLength(2));
      expect(
        resumen.bloqueos.map((b) => b.destino),
        containsAll([DestinoBloqueo.catalogo, DestinoBloqueo.perfil]),
      );
    });

    test('una lista vacia no es un error', () {
      expect(BloqueoCheckout.listaDe(<dynamic>[]), isEmpty);
      expect(BloqueoCheckout.listaDe(null), isEmpty);
    });
  });
}

DestinoBloqueo _destinoDe(String codigo) =>
    BloqueoCheckout(codigo: codigo, mensaje: 'x').destino;

// ====================================================================
// Datos de ejemplo, copiados de la forma real del contrato
// ====================================================================

final Map<String, dynamic> _checkoutListo = {
  'carrito': {
    'id': 15,
    'estado': 'activo',
    'cantidad_items': 1,
    'cantidad_lineas': 1,
    'vacio': false,
    'subtotal_lista': 270000,
    'descuento_total': 20000,
    'total': 250000,
    'tiene_preventa': false,
    'tiene_no_disponibles': false,
    'puede_comprar': true,
    'lineas': [
      {
        'id': 42,
        'producto_id': 7,
        'cantidad': 1,
        'producto': {
          'id': 7,
          'codigo': 'MON-0012',
          'nombre': 'Monitor Samsung 24"',
          'marca': 'Samsung',
          'imagen_url': null,
          'destacado': false,
          'stock_disponible': 5,
          'en_preventa': false,
          'categoria': {'id': 3, 'nombre': 'Monitores'},
          'precio': 270000,
          'precio_final': 250000,
          'tiene_descuento': true,
          'porcentaje_descuento': 7,
        },
        'disponible': true,
        'motivo_no_disponible': null,
        'stock_disponible': 5,
        'en_preventa': false,
        'unidades_en_preventa': 0,
        'precio_unitario': 270000,
        'precio_unitario_final': 250000,
        'tiene_descuento': true,
        'porcentaje_descuento': 7,
        'subtotal': 250000,
      },
    ],
  },
  'entrega': {
    'modo': 'retiro',
    'observaciones': 'Paso el viernes.',
    'modos_disponibles': [
      {'valor': 'retiro', 'etiqueta': 'Retiro en local'},
    ],
  },
  'facturacion': {
    'razon_social': 'Pérez, Juan',
    'tipo_documento': 'DNI',
    'nro_doc': '30111222',
    'condicion_iva': 'Consumidor final',
  },
  'puede_pagar': true,
  'bloqueos': <dynamic>[],
};
