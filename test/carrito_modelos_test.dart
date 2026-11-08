import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:powertech_tienda/core/errores.dart';
import 'package:powertech_tienda/datos/modelos/carrito.dart';
import 'package:powertech_tienda/datos/modelos/linea_carrito.dart';

/// Pruebas del parseo del carrito y del mapeo de errores.
///
/// **Son pruebas de contrato, no de UI.** Lo que verifican es que la app lea
/// exactamente lo que `CarritoResource` y `CarritoLineaResource` mandan, y
/// sobre todo que no calcule nada por su cuenta: varios casos usan importes
/// deliberadamente inconsistentes para comprobar que la app muestra lo que
/// vino y no lo que "debería dar".
void main() {
  group('LineaCarrito', () {
    test('lee una línea normal con descuento', () {
      final linea = LineaCarrito.fromJson(_lineaConDescuento);

      expect(linea.id, 42);
      expect(linea.productoId, 7);
      expect(linea.cantidad, 2);
      expect(linea.disponible, isTrue);
      expect(linea.motivoNoDisponible, isNull);
      expect(linea.precioUnitario, 100000.0);
      expect(linea.precioUnitarioFinal, 90000.0);
      expect(linea.tieneDescuento, isTrue);
      expect(linea.porcentajeDescuento, 10);
      expect(linea.subtotal, 180000.0);
      expect(linea.producto?.nombre, 'Monitor Samsung 24"');
    });

    test('el subtotal es el del backend, no cantidad por precio', () {
      // Importes incoherentes a propósito: si la app multiplicara, daría
      // 180000. Tiene que devolver lo que vino.
      final linea = LineaCarrito.fromJson({
        ..._lineaConDescuento,
        'subtotal': 12345.67,
      });

      expect(linea.subtotal, 12345.67);
    });

    test('distingue la preventa del producto de la de la línea', () {
      // Producto con 3 disponibles y una línea de 5: el PRODUCTO no está en
      // preventa, pero 2 unidades de la LÍNEA sí.
      final linea = LineaCarrito.fromJson({
        ..._lineaConDescuento,
        'cantidad': 5,
        'stock_disponible': 3,
        'en_preventa': false,
        'unidades_en_preventa': 2,
      });

      expect(linea.enPreventa, isFalse);
      expect(linea.unidadesEnPreventa, 2);
      expect(linea.requierePreventa, isTrue);
    });

    test('una línea cubierta por stock no requiere preventa', () {
      final linea = LineaCarrito.fromJson(_lineaConDescuento);

      expect(linea.enPreventa, isFalse);
      expect(linea.unidadesEnPreventa, 0);
      expect(linea.requierePreventa, isFalse);
    });

    test('lee una línea no disponible con importes en cero', () {
      final linea = LineaCarrito.fromJson(_lineaNoDisponible);

      expect(linea.disponible, isFalse);
      expect(linea.motivoNoDisponible, isNotNull);
      expect(linea.subtotal, 0);
      expect(linea.precioUnitario, 0);
      expect(linea.ahorro, isNull);
    });

    test('el ahorro sale de restar dos importes del backend', () {
      final linea = LineaCarrito.fromJson(_lineaConDescuento);

      // (100000 - 90000) * 2
      expect(linea.ahorro, 20000.0);
    });

    test('sin descuento no hay ahorro', () {
      final linea = LineaCarrito.fromJson({
        ..._lineaConDescuento,
        'precio_unitario_final': 100000,
        'tiene_descuento': false,
        'porcentaje_descuento': 0,
      });

      expect(linea.ahorro, isNull);
    });

    test('tolera un producto ausente sin romperse', () {
      final json = Map<String, dynamic>.from(_lineaConDescuento)
        ..remove('producto');

      final linea = LineaCarrito.fromJson(json);

      expect(linea.producto, isNull);
      expect(linea.nombre, 'Producto #7');
    });

    test('acepta enteros donde el contrato admite decimales', () {
      // Laravel serializa round(30000, 2) como 30000, no como 30000.0.
      final linea = LineaCarrito.fromJson({
        ..._lineaConDescuento,
        'precio_unitario': 30000,
        'precio_unitario_final': 30000,
        'subtotal': 60000,
      });

      expect(linea.precioUnitario, 30000.0);
      expect(linea.subtotal, 60000.0);
    });
  });

  group('Carrito', () {
    test('lee el carrito completo', () {
      final carrito = Carrito.fromJson(_carritoCompleto);

      expect(carrito.id, 15);
      expect(carrito.estado, 'activo');
      expect(carrito.cantidadItems, 3);
      expect(carrito.cantidadLineas, 2);
      expect(carrito.vacio, isFalse);
      expect(carrito.subtotalLista, 270000.0);
      expect(carrito.descuentoTotal, 20000.0);
      expect(carrito.total, 250000.0);
      expect(carrito.lineas, hasLength(2));
    });

    test('los totales son los del backend, no la suma de las líneas', () {
      // La suma de los subtotales de _carritoCompleto es 250000. Se cambia
      // el total a un valor distinto: la app tiene que respetarlo.
      final carrito = Carrito.fromJson({
        ..._carritoCompleto,
        'total': 999.99,
      });

      expect(carrito.total, 999.99);
    });

    test('puede_comprar se lee, no se deriva', () {
      // El carrito tiene una línea no disponible: si la app dedujera la
      // bandera, diría false. El backend dice true y eso es lo que vale.
      final carrito = Carrito.fromJson({
        ..._carritoCompleto,
        'puede_comprar': true,
      });

      expect(carrito.tieneNoDisponibles, isTrue);
      expect(carrito.puedeComprar, isTrue);
    });

    test('un carrito con todo despublicado no es vacío pero no se compra', () {
      final carrito = Carrito.fromJson({
        'id': 15,
        'estado': 'activo',
        'cantidad_items': 2,
        'cantidad_lineas': 1,
        'vacio': false,
        'subtotal_lista': 0,
        'descuento_total': 0,
        'total': 0,
        'tiene_preventa': false,
        'tiene_no_disponibles': true,
        'puede_comprar': false,
        'lineas': [_lineaNoDisponible],
      });

      expect(carrito.vacio, isFalse);
      expect(carrito.puedeComprar, isFalse);
      expect(carrito.lineasNoDisponibles, hasLength(1));
    });

    test('lee un carrito vacío', () {
      final carrito = Carrito.fromJson({
        'id': 20,
        'estado': 'activo',
        'cantidad_items': 0,
        'cantidad_lineas': 0,
        'vacio': true,
        'subtotal_lista': 0,
        'descuento_total': 0,
        'total': 0,
        'tiene_preventa': false,
        'tiene_no_disponibles': false,
        'puede_comprar': false,
        'lineas': <dynamic>[],
      });

      expect(carrito.vacio, isTrue);
      expect(carrito.lineas, isEmpty);
      expect(carrito.puedeComprar, isFalse);
    });

    test('cantidad_items cuenta también las unidades no disponibles', () {
      final carrito = Carrito.fromJson(_carritoCompleto);

      // 2 del disponible + 1 del que se despublicó.
      expect(carrito.cantidadItems, 3);
      expect(carrito.lineasNoDisponibles, hasLength(1));
    });

    test('acepta booleanos como 1 y 0', () {
      // PDO puede devolver los booleanos de MariaDB como enteros.
      final carrito = Carrito.fromJson({
        ..._carritoCompleto,
        'vacio': 0,
        'puede_comprar': 1,
        'tiene_preventa': 1,
      });

      expect(carrito.vacio, isFalse);
      expect(carrito.puedeComprar, isTrue);
      expect(carrito.tienePreventa, isTrue);
    });
  });

  group('mapeo del 403', () {
    test('sin codigo es acceso denegado', () {
      final error = mapearError(
        _respuesta403({'message': 'Esta cuenta no tiene acceso.'}),
      );

      expect(error, isA<ErrorAccesoDenegado>());
    });

    test('con codigo email_no_verificado es su propio error', () {
      final error = mapearError(
        _respuesta403({
          'message': 'Necesitás confirmar tu correo.',
          'codigo': 'email_no_verificado',
        }),
      );

      expect(error, isA<ErrorEmailNoVerificado>());
      expect(error.mensaje, 'Necesitás confirmar tu correo.');
    });

    test('un codigo desconocido no cambia el comportamiento viejo', () {
      final error = mapearError(
        _respuesta403({'message': 'Nope.', 'codigo': 'otra_cosa'}),
      );

      expect(error, isA<ErrorAccesoDenegado>());
    });
  });
}

// ====================================================================
// Datos de ejemplo, copiados de la forma real del contrato
// ====================================================================

final Map<String, dynamic> _lineaConDescuento = {
  'id': 42,
  'producto_id': 7,
  'cantidad': 2,
  'producto': {
    'id': 7,
    'codigo': 'MON-0012',
    'nombre': 'Monitor Samsung 24"',
    'marca': 'Samsung',
    'imagen_url': 'https://powertech.test/storage/productos/mon-0012.jpg',
    'destacado': false,
    'stock_disponible': 5,
    'en_preventa': false,
    'categoria': {'id': 3, 'nombre': 'Monitores'},
    'precio': 100000,
    'precio_final': 90000,
    'tiene_descuento': true,
    'porcentaje_descuento': 10,
  },
  'disponible': true,
  'motivo_no_disponible': null,
  'stock_disponible': 5,
  'en_preventa': false,
  'unidades_en_preventa': 0,
  'precio_unitario': 100000,
  'precio_unitario_final': 90000,
  'tiene_descuento': true,
  'porcentaje_descuento': 10,
  'subtotal': 180000,
};

final Map<String, dynamic> _lineaNoDisponible = {
  'id': 43,
  'producto_id': 11,
  'cantidad': 1,
  'producto': {
    'id': 11,
    'codigo': 'TEC-0003',
    'nombre': 'Teclado mecánico',
    'marca': 'Redragon',
    'imagen_url': null,
    'destacado': false,
    'stock_disponible': 0,
    'en_preventa': true,
    'categoria': {'id': 5, 'nombre': 'Periféricos'},
  },
  'disponible': false,
  'motivo_no_disponible': 'Este producto ya no está disponible en la tienda.',
  'stock_disponible': 0,
  'en_preventa': false,
  'unidades_en_preventa': 0,
  'precio_unitario': 0,
  'precio_unitario_final': 0,
  'tiene_descuento': false,
  'porcentaje_descuento': 0,
  'subtotal': 0,
};

final Map<String, dynamic> _carritoCompleto = {
  'id': 15,
  'estado': 'activo',
  'cantidad_items': 3,
  'cantidad_lineas': 2,
  'vacio': false,
  'subtotal_lista': 270000,
  'descuento_total': 20000,
  'total': 250000,
  'tiene_preventa': false,
  'tiene_no_disponibles': true,
  'puede_comprar': false,
  'lineas': [_lineaConDescuento, _lineaNoDisponible],
};

/// Arma la excepción que produciría Dio ante un 403 con este cuerpo.
DioException _respuesta403(Map<String, dynamic> cuerpo) {
  final peticion = RequestOptions(path: '/carrito');

  return DioException.badResponse(
    statusCode: 403,
    requestOptions: peticion,
    response: Response<dynamic>(
      statusCode: 403,
      data: cuerpo,
      requestOptions: peticion,
    ),
  );
}
