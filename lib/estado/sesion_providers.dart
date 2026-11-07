import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/errores.dart';
import '../datos/modelos/usuario.dart';
import 'catalogo_providers.dart';
import 'proveedores_core.dart';

// ====================================================================
// Estado
// ====================================================================

/// Los tres estados del ciclo de sesion.
///
/// **No confundir con los tres estados del contrato** (invitado / cliente sin
/// verificar / cliente verificado). Son ejes distintos: este describe que
/// sabe la app en este momento, y el otro describe que puede hacer el
/// cliente. El segundo vive dentro de [SesionAutenticada], en
/// `usuario.emailVerificado`, que es donde el backend lo pone.
///
/// Un enum de cuatro casos mezclaria los dos ejes y despues no se sabria
/// cual mirar.
sealed class EstadoSesion {
  const EstadoSesion();
}

/// Arrancando: hay un token guardado y se esta validando contra Laravel.
/// Dura lo que tarda `/auth/yo`.
class SesionCargando extends EstadoSesion {
  const SesionCargando();
}

/// Sin sesion util. Es el estado normal de quien nunca inicio sesion.
///
/// [aviso] lleva texto solo cuando se llego aca por una expulsion —token
/// vencido, cuenta pasada a gestion— para poder explicarlo en el login en
/// lugar de dejar al usuario preguntandose por que volvio ahi.
class SesionInvitado extends EstadoSesion {
  const SesionInvitado({this.aviso});

  final String? aviso;
}

/// Hay token valido y usuario cargado.
class SesionAutenticada extends EstadoSesion {
  const SesionAutenticada(this.usuario);

  final Usuario usuario;
}

// ====================================================================
// Notifier
// ====================================================================

final sesionProvider = NotifierProvider<SesionNotifier, EstadoSesion>(
  SesionNotifier.new,
);

class SesionNotifier extends Notifier<EstadoSesion> {
  @override
  EstadoSesion build() {
    // La restauracion es asincronica y `build` no puede serlo. Se difiere a
    // la proxima microtarea: para entonces el provider ya existe y se le
    // puede escribir el estado.
    Future.microtask(restaurar);

    return const SesionCargando();
  }

  /// Recupera el token guardado y lo valida contra `/auth/yo`.
  ///
  /// **Ante un error de red no se borra nada.** Perder la sesion porque se
  /// cayo el wifi, o porque Laravel esta apagado, es el peor comportamiento
  /// posible: el token sigue siendo bueno y lo va a seguir siendo cuando
  /// vuelva la conexion. Solo se limpia cuando el servidor contesta que la
  /// sesion ya no vale.
  Future<void> restaurar() async {
    final repo = ref.read(authRepositoryProvider);

    final token = await repo.tokenGuardado();

    if (token == null || token.isEmpty) {
      state = const SesionInvitado();
      return;
    }

    // Si la fecha guardada ya paso, no hay para que gastar una llamada que
    // sabemos que va a dar 401.
    final expira = await repo.expiracionGuardada();

    if (expira != null && !expira.isAfter(DateTime.now())) {
      await repo.olvidarSesion();
      state = const SesionInvitado(
        aviso: 'Tu sesión venció. Ingresá de nuevo para ver precios y comprar.',
      );
      return;
    }

    state = const SesionCargando();

    try {
      final usuario = await repo.usuarioActual();
      _entrar(usuario);
    } on ErrorSesionVencida {
      // 401: el token vencio antes de lo previsto o fue revocado desde otro
      // dispositivo.
      await repo.olvidarSesion();
      state = const SesionInvitado(
        aviso: 'Tu sesión venció. Ingresá de nuevo para ver precios y comprar.',
      );
    } on ErrorAccesoDenegado catch (e) {
      // 403: `api.ambito` rechaza la cuenta. Pasa si el rol cambio a gestion
      // despues de que se emitio el token.
      await repo.olvidarSesion();
      state = SesionInvitado(aviso: e.mensaje);
    } on ErrorApi {
      // Red caida, 500, respuesta rara: el token se conserva. La app queda
      // como invitado y se puede reintentar sin tener que volver a escribir
      // la contraseña.
      state = const SesionInvitado();
    }
  }

  /// Inicia sesion. Deja que los errores suban: la pantalla de login es la
  /// que sabe donde mostrar cada uno.
  Future<void> iniciarSesion({
    required String email,
    required String password,
  }) async {
    final sesion = await ref
        .read(authRepositoryProvider)
        .iniciarSesion(email: email, password: password);

    _entrar(sesion.usuario);
  }

  /// Registra un cliente nuevo. El backend emite token igual aunque el
  /// correo no este verificado, asi que se entra directo.
  Future<void> registrar({
    required String nombres,
    required String apellido,
    required String email,
    required String password,
    required String passwordConfirmation,
    required int tipoDocumentoId,
    required String nroDoc,
    required int condicionIvaId,
    String? razonSocial,
    String? telefono,
  }) async {
    final sesion = await ref.read(authRepositoryProvider).registrar(
          nombres: nombres,
          apellido: apellido,
          email: email,
          password: password,
          passwordConfirmation: passwordConfirmation,
          tipoDocumentoId: tipoDocumentoId,
          nroDoc: nroDoc,
          condicionIvaId: condicionIvaId,
          razonSocial: razonSocial,
          telefono: telefono,
        );

    _entrar(sesion.usuario);
  }

  /// Cierra sesion en este dispositivo. No propaga errores: el usuario
  /// apretó cerrar sesion y la sesion queda cerrada aunque el servidor no
  /// conteste.
  Future<void> cerrarSesion() async {
    try {
      await ref.read(authRepositoryProvider).cerrarSesion();
    } on ErrorApi {
      // El repositorio ya borro el token local en su `finally`.
    }

    state = const SesionInvitado();
    _invalidarCatalogo();
  }

  /// Vuelve a pedir `/auth/yo`. Lo usa la pantalla de inicio despues de
  /// reenviar el correo de verificacion, para ver si ya quedo verificado.
  Future<void> refrescarUsuario() async {
    try {
      _entrar(await ref.read(authRepositoryProvider).usuarioActual());
    } on ErrorSesionVencida {
      await ref.read(authRepositoryProvider).olvidarSesion();
      state = const SesionInvitado(aviso: 'Tu sesión venció.');
    } on ErrorAccesoDenegado catch (e) {
      await ref.read(authRepositoryProvider).olvidarSesion();
      state = SesionInvitado(aviso: e.mensaje);
    }
  }

  /// Borra un aviso de expulsion ya leido, para que no quede pegado en la
  /// pantalla de login despues de que el usuario empiece a escribir.
  void descartarAviso() {
    final actual = state;

    if (actual is SesionInvitado && actual.aviso != null) {
      state = const SesionInvitado();
    }
  }

  void _entrar(Usuario usuario) {
    state = SesionAutenticada(usuario);
    _invalidarCatalogo();
  }

  /// **El detalle de integracion que mas se olvida.** Al pasar de invitado a
  /// cliente —y al reves— los mismos productos cambian: con sesion vienen
  /// con precio y sin sesion no. Todo lo que dependa del catalogo tiene que
  /// volver a pedirse.
  ///
  /// Cada provider nuevo del catalogo se agrega aca. Si falta uno, el sintoma
  /// es que el cliente inicia sesion y sigue viendo "Ingresá para ver el
  /// precio" hasta que cierra y reabre la app.
  void _invalidarCatalogo() {
    ref.invalidate(categoriasProvider);
    ref.invalidate(vitrinaProvider);
  }
}

// ====================================================================
// Atajos de lectura
// ====================================================================

/// El usuario, o null si no hay sesion. Evita que cada widget haga el
/// `switch` completo solo para mostrar un nombre.
final usuarioProvider = Provider<Usuario?>((ref) {
  final estado = ref.watch(sesionProvider);
  return estado is SesionAutenticada ? estado.usuario : null;
});
