import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../datos/modelos/categoria.dart';
import '../datos/modelos/vitrina.dart';
import 'proveedores_core.dart';

/// Lista de categorias del catalogo.
///
/// `ref.invalidate(categoriasProvider)` fuerza un refetch: es lo que usa el
/// boton "Reintentar" de la pantalla de diagnostico.
final categoriasProvider = FutureProvider<List<Categoria>>((ref) async {
  return ref.watch(catalogoRepositoryProvider).categorias();
});

/// La vitrina: promociones vigentes y las tres secciones de mas vendidos.
///
/// **Se invalida al iniciar y al cerrar sesion.** Lo hace
/// `SesionNotifier._invalidarCatalogo()`, y no es un detalle menor: son los
/// mismos productos, pero con sesion traen el bloque de precio y sin sesion
/// no. Sin esa invalidacion, el cliente que acaba de ingresar seguiria viendo
/// "Ingresá para ver el precio" sobre datos que ya podria ver.
///
/// No se cachea en disco por decision del proyecto: `MotorPromociones`
/// resuelve el descuento vigente al momento de mirar, y un precio viejo hace
/// que el backend aborte la compra por diferencia de importe.
final vitrinaProvider = FutureProvider<Vitrina>((ref) async {
  return ref.watch(catalogoRepositoryProvider).home();
});
