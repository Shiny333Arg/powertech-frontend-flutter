import 'package:url_launcher/url_launcher.dart';

/// Abre una URL en el navegador del sistema.
///
/// **Navegador externo y no una vista embebida, a propósito.** Es la decisión
/// que importa de toda la integración del lado de la app: el cliente necesita
/// poder usar su sesión de Mercado Pago, saltar a la aplicación de su banco y
/// completar la autenticación de la tarjeta. Una `WebView` embebida rompe
/// esos saltos y varios emisores directamente la bloquean. Además deja el
/// cobro fuera del proceso de la app, que es donde tiene que estar: la app
/// nunca ve los datos de la tarjeta.
///
/// Devuelve false si no se pudo abrir —URL mal formada, ningún navegador
/// disponible— en lugar de lanzar: el llamador tiene que poder decirle al
/// cliente que reintente, no romperse.
Future<bool> abrirEnNavegador(String url) async {
  final uri = Uri.tryParse(url);

  if (uri == null || !uri.hasScheme) return false;

  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } on Exception {
    return false;
  }
}
