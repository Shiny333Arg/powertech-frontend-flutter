import 'conversiones.dart';
import 'producto.dart';
import 'promocion.dart';

/// Una de las secciones de más vendidos de la vitrina.
///
/// El backend manda `{ clave, titulo, productos }` y las tres cosas importan:
/// `clave` identifica la sección (`perifericos`, `componentes`, `monitores`),
/// `titulo` ya viene escrito y acentuado desde Laravel —la app no lo traduce
/// ni lo arma a partir de la clave— y `productos` puede venir **vacío**.
///
/// Eso último no es un error: `masVendidosDe()` incluye los productos que
/// nunca se vendieron, pero si la categoría no tiene ninguno publicado la
/// sección llega sin nada. En el JSON de prueba, "Monitores" está así. La
/// pantalla las omite en lugar de mostrar un título suelto.
class SeccionVitrina {
  const SeccionVitrina({
    required this.clave,
    required this.titulo,
    required this.productos,
  });

  final String clave;
  final String titulo;
  final List<Producto> productos;

  bool get estaVacia => productos.isEmpty;

  factory SeccionVitrina.fromJson(Map<String, dynamic> json) {
    return SeccionVitrina(
      clave: comoTexto(json['clave']),
      titulo: comoTexto(json['titulo']),
      productos: Producto.listaDe(json['productos']),
    );
  }
}

/// La respuesta completa de `GET /api/v1/home`.
class Vitrina {
  const Vitrina({required this.promociones, required this.secciones});

  final List<Promocion> promociones;
  final List<SeccionVitrina> secciones;

  /// Las que tienen algo para mostrar. El orden es el que mandó el backend.
  List<SeccionVitrina> get seccionesConProductos =>
      secciones.where((s) => !s.estaVacia).toList();

  /// Nada que mostrar en ninguna parte. Pasa con una base recién sembrada o
  /// con todo despublicado, y merece un cartel propio en lugar de una
  /// pantalla en blanco.
  bool get estaVacia =>
      promociones.isEmpty && seccionesConProductos.isEmpty;

  factory Vitrina.fromJson(Map<String, dynamic> json) {
    final secciones = json['secciones'];

    return Vitrina(
      promociones: Promocion.listaDe(json['promociones']),
      secciones: secciones is! List
          ? const []
          : secciones
              .map(comoMapa)
              .whereType<Map<String, dynamic>>()
              .map(SeccionVitrina.fromJson)
              .toList(),
    );
  }
}
