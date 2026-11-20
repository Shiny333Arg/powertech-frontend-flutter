# PowerTech — Aplicación móvil (Flutter)

Aplicación móvil de clientes de **PowerTech**, el sistema de gestión comercial y tienda online de una tienda informática. Es el canal de compra: permite explorar el catálogo, armar un carrito, pagar con Mercado Pago y seguir el estado de los pedidos desde el teléfono.

El nombre interno del proyecto es `powertech_tienda`, y eso describe su alcance: **la aplicación no tiene pantallas de gestión**. Toda la administración del negocio (productos, stock, ventas de mostrador, compras, facturación) se hace desde el panel web del backend.

Requiere el backend corriendo. Vive en el repositorio complementario [`powertech-backend-laravel`](https://github.com/Shiny333Arg/powertech-backend-laravel), que documenta la instalación del servidor, la base de datos y la configuración de Mercado Pago.

---

## Contexto académico

| | |
|---|---|
| **Asignatura** | Laboratorio de Desarrollo de Aplicaciones |
| **Carrera** | Ingeniería en Sistemas |
| **Institución** | Universidad Nacional de la Patagonia Austral (UNPA) — Unidad Académica Caleta Olivia |

---

## Tabla de contenidos

- [Funcionalidades principales](#funcionalidades-principales)
- [Tecnologías utilizadas](#tecnologías-utilizadas)
- [Arquitectura general](#arquitectura-general)
- [Requisitos previos](#requisitos-previos)
- [Instalación desde cero](#instalación-desde-cero)
- [Configuración de la URL del backend](#configuración-de-la-url-del-backend)
- [Ejecución diaria](#ejecución-diaria)
- [Configuración según dispositivo](#configuración-según-dispositivo)
- [Generación del APK](#generación-del-apk)
- [Solución de problemas frecuentes](#solución-de-problemas-frecuentes)

---

## Funcionalidades principales

Verificadas contra las pantallas y los repositorios de `lib/`:

- **Vitrina** — pantalla de inicio con destacados y carrusel de promociones.
- **Catálogo** — listado paginado de productos con búsqueda, filtros (categoría, marca, precio) y detalle de producto con precio promocional.
- **Carrito** — alta de líneas, cambio de cantidad, eliminación y vaciado, con resumen de totales.
- **Checkout** — elección de datos fiscales y modalidad de entrega (envío a domicilio o retiro en el local), con aviso de los bloqueos que impiden avanzar.
- **Pago con Mercado Pago** — la app abre el link de pago en el **navegador del sistema** y luego espera la acreditación consultando al backend.
- **Mis compras** — historial de pedidos con estado y seguimiento, y detalle de cada compra con sus líneas y comprobantes.
- **Cuenta** — registro con verificación de correo, inicio y cierre de sesión, perfil editable, cambio de contraseña y recuperación por correo.

La sesión no es obligatoria para arrancar: tanto el invitado como el cliente autenticado empiezan en la vitrina, y el inicio de sesión es un destino que se apila cuando hace falta (carrito y checkout lo exigen).

---

## Tecnologías utilizadas

### SDK

| | Versión |
|---|---|
| Declarado en `pubspec.yaml` | Dart `^3.12.0`, Flutter `>=3.44.0` |
| **Exigido por `pubspec.lock`** | **Dart `>=3.13.0`, Flutter `>=3.47.0`** |
| Versión con la que se trabaja el proyecto | Flutter 3.47.7 *stable*, Dart 3.13.5 |

El mínimo real es el del `pubspec.lock`: los paquetes ya resueltos requieren Flutter 3.47 o superior. La restricción más laxa de `pubspec.yaml` corresponde a una resolución anterior.

### Dependencias

Versiones resueltas en `pubspec.lock`:

| Paquete | Versión | Para qué |
|---|---|---|
| `flutter_riverpod` | 3.5.0 | Manejo de estado y inyección de dependencias |
| `dio` | 5.11.1 | Cliente HTTP con interceptores de token, log y mapeo de errores |
| `flutter_secure_storage` | 11.2.0 | Guarda el token de Sanctum en el almacenamiento cifrado del sistema operativo |
| `intl` | 0.20.3 | Formato de precios en es-AR y de fechas |
| `url_launcher` | 6.3.3 | Abre el link de pago de Mercado Pago en el navegador del sistema |
| `go_router` | 18.1.3 | **Declarado, todavía no utilizado** (ver [Arquitectura](#arquitectura-general)) |

De desarrollo: `flutter_lints` 6.0.0, `flutter_launcher_icons` 0.14.4 y `flutter_native_splash` 2.4.8. Los iconos y la pantalla de arranque **ya están generados y versionados** en `android/app/src/main/res/`: no hace falta regenerarlos para compilar.

### Android

| | |
|---|---|
| `applicationId` / `namespace` | `com.powertech.powertech_frontend_flutter` |
| Gradle wrapper | 9.3.1 |
| Java / Kotlin JVM target | 17 |
| `compileSdk`, `targetSdk`, `minSdk` | los valores por defecto del SDK de Flutter (`flutter.*`), sin fijar en el proyecto |
| Permisos | únicamente `android.permission.INTERNET` |
| Configuración de red | `android/app/src/main/res/xml/network_security_config.xml` |

El repositorio incluye además las carpetas `web/` y `windows/` generadas por `flutter create`, pero **la plataforma soportada es Android**: `lib/core/dispositivo.dart` usa `dart:io`, que no compila para web. No hay carpeta `ios/`.

---

## Arquitectura general

```
lib/
├── main.dart                 Punto de entrada: ProviderScope + MaterialApp
├── core/                     Configuración, cliente HTTP, almacenamiento, errores, formato
├── datos/
│   ├── modelos/              22 modelos con fromJson escrito a mano
│   └── repositorios/         7 repositorios, uno por área de la API
├── estado/                   9 archivos de providers y notifiers de Riverpod
└── ui/
    ├── pantallas/            15 pantallas
    └── widgets/              19 componentes reutilizables
```

**Flujo de datos.** Las pantallas observan *providers* de Riverpod; los providers delegan en repositorios; los repositorios hablan con un único `Dio` configurado en `lib/core/api_client.dart`. Los modelos se deserializan a mano, sin generación de código.

**Navegación.** `MaterialApp` con `home` y navegación imperativa con `Navigator`. La vitrina es la primera ruta de la pila y las demás pantallas vuelven a ella. `go_router` está entre las dependencias pero todavía no está integrado: el propio `main.dart` lo documenta como pendiente.

**Comunicación con el backend.** La app consume la **API de tienda** de Laravel, bajo el prefijo `/api/v1`:

| Aspecto | Cómo funciona |
|---|---|
| URL base | `API_URL_BASE` (origen) + `API_PREFIJO` (por defecto `/api/v1`), compuestos en `lib/core/config.dart` |
| Cabeceras fijas | `Accept: application/json` y `ngrok-skip-browser-warning: true`, esta última para que un túnel de ngrok no devuelva su página intersticial en HTML |
| Autenticación | Token *bearer* de Sanctum que un interceptor de Dio agrega a cada petición |
| Guardado del token | `flutter_secure_storage` (almacenamiento cifrado del sistema operativo) |
| Ámbito del token | En el login la app envía `ambito: 'tienda'`, de modo que el token nazca con la *ability* `tienda`, que es la que exigen las rutas de carrito, checkout y compras. Vigencia: 30 días |
| Identificación del equipo | Se envía un nombre de dispositivo (`App PowerTech (Android)`), que el backend guarda junto al token |
| Tiempos de espera | 10 s para conectar y 15 s para recibir respuesta, configurables |
| Restauración de sesión | Al arrancar, valida el token guardado contra `GET /auth/yo` y muestra una pantalla de carga mientras lo hace |

**Pago con Mercado Pago.** La app nunca ve los datos de la tarjeta ni las credenciales de la pasarela: pide al backend el link de pago y lo abre en el **navegador externo** del teléfono. Esto es deliberado, para que el cliente pueda usar su sesión de Mercado Pago y saltar a la aplicación de su banco, algo que una vista embebida rompe.

Para volver, la app **no usa un *deep link***: la pantalla de espera consulta `GET /api/v1/checkout/estado` de forma periódica y cada vez que la aplicación vuelve al primer plano. El camino autoritativo del cobro es el webhook que recibe el backend, así que el pedido se crea aunque el cliente cierre el navegador y no regrese.

---

## Requisitos previos

- **Flutter 3.47 o superior** con su Dart correspondiente (3.13+). Verificar con `flutter --version`.
- **Android SDK** y un destino donde correr la app: emulador de Android o teléfono físico con depuración por USB habilitada.
- **JDK 17**, que es el nivel de compatibilidad configurado en Gradle.
- **El backend de PowerTech corriendo y accesible** desde el dispositivo. Ver el [repositorio del backend](https://github.com/Shiny333Arg/powertech-backend-laravel).
- **Git**

Antes de instalar, conviene ejecutar `flutter doctor` y resolver lo que marque.

---

## Instalación desde cero

Todos los comandos se ejecutan **desde la raíz de este repositorio**.

### 1. Clonar el repositorio

```bash
git clone https://github.com/Shiny333Arg/powertech-frontend-flutter.git
cd powertech-frontend-flutter
git checkout etapa-03
```

### 2. Verificar la versión de Flutter

```bash
flutter --version
```

Debe informar Flutter 3.47 o superior. Si es anterior, actualizar con `flutter upgrade`.

### 3. Descargar las dependencias

```bash
flutter pub get
```

### 4. Verificar que el entorno compila

```bash
flutter analyze
```

No hay más pasos de instalación: **la app no tiene archivo de configuración**. La dirección del backend se pasa en el comando de ejecución, como se explica a continuación.

---

## Configuración de la URL del backend

La URL del backend **no está escrita en el código**: entra como variable de compilación con `--dart-define`, y la lee `lib/core/config.dart`.

| Variable | Valor por defecto | Qué es |
|---|---|---|
| `API_URL_BASE` | *(ninguno: es obligatoria)* | Origen del backend, **sin el prefijo de la API y sin barra final**. Ejemplo: `http://10.0.2.2:8000` |
| `API_PREFIJO` | `/api/v1` | Prefijo de la API. Separado del origen para que al cambiar de entorno solo haya que cambiar el host |
| `API_TIMEOUT_CONEXION_MS` | `10000` | Milisegundos para establecer la conexión |
| `API_TIMEOUT_RESPUESTA_MS` | `15000` | Milisegundos para recibir la respuesta |
| `API_LOG_HTTP` | `true` | Imprime cada petición y respuesta de Dio en la consola |

La URL final que usa la app es la suma de las dos primeras: `http://10.0.2.2:8000` + `/api/v1`.

> **`--dart-define` se resuelve al compilar.** Si se cambia la URL, un *hot reload* no alcanza: hay que detener la ejecución y volver a correr el comando.

Si se olvida `--dart-define=API_URL_BASE=...`, la app lo detecta y avisa en lugar de fallar con un error de red confuso.

### Para no reescribir el comando cada vez

Se puede dejar la configuración en `.vscode/launch.json`. El procedimiento está en `README-PASO-0.md`, en la raíz de este repositorio. Ese archivo documenta el andamiaje inicial del proyecto y parte de su contenido ya quedó desactualizado, pero la guía de entorno sigue siendo útil.

---

## Ejecución diaria

Con el backend ya levantado (Mailpit, `composer run dev`, ngrok y el trabajador de colas; ver el [README del backend](https://github.com/Shiny333Arg/powertech-backend-laravel)), desde la raíz de este repositorio:

```bash
flutter run --dart-define=API_URL_BASE=http://10.0.2.2:8000
```

Este es el comando habitual de desarrollo, con el **emulador de Android** y el backend servido en el puerto 8000 de la máquina anfitriona.

`10.0.2.2` no es un valor arbitrario: es el alias con el que el emulador de Android alcanza el `localhost` de la máquina que lo hospeda. Usar `localhost` no funciona, porque dentro del emulador `localhost` es el propio emulador.

Para probar el **pago con Mercado Pago**, el backend tiene que estar accesible por la URL pública de ngrok. En ese caso hay que apuntar la app al túnel:

```bash
flutter run --dart-define=API_URL_BASE=https://<subdominio>.ngrok-free.dev
```

---

## Configuración según dispositivo

### Emulador de Android

No requiere ninguna configuración adicional: `network_security_config.xml` ya autoriza tráfico sin cifrar hacia `10.0.2.2`, `localhost` y `127.0.0.1`, que son los hosts de desarrollo. El resto de los dominios sigue exigiendo HTTPS.

```bash
flutter run --dart-define=API_URL_BASE=http://10.0.2.2:8000
```

### Teléfono físico en la misma red Wi-Fi

> Procedimiento documentado en `README-PASO-0.md`. **No fue verificado al redactar este README.**

Requiere tres cosas, porque el teléfono llega al backend por la IP de la máquina en la red local y no por el alias del emulador:

1. **Averiguar la IP de la máquina** (en Windows, `ipconfig`, campo «Dirección IPv4» del adaptador Wi-Fi) y usarla en el comando:

   ```bash
   flutter run --dart-define=API_URL_BASE=http://192.168.0.15:8000
   ```

2. **Autorizar esa IP para tráfico sin cifrar.** En `android/app/src/main/res/xml/network_security_config.xml` hay una línea comentada de ejemplo: hay que descomentarla y poner la IP real. **No acepta comodines**, la dirección va escrita completa.

3. **Abrir el puerto 8000 en el firewall de Windows** (PowerShell como administrador):

   ```powershell
   New-NetFirewallRule -DisplayName "Laravel 8000" -Direction Inbound `
     -Protocol TCP -LocalPort 8000 -Action Allow -Profile Private
   ```

Si el backend se sirve en `127.0.0.1`, puede ser necesario levantarlo escuchando hacia la red local con `php artisan serve --host=0.0.0.0 --port=8000`. En la rutina habitual de desarrollo con emulador esto no hace falta.

### Teléfono fuera de la red, o para probar HTTPS

> Procedimiento documentado en `README-PASO-0.md`. **No fue verificado al redactar este README.**

Con el túnel de ngrok ya levantado en el backend:

```bash
flutter run --dart-define=API_URL_BASE=https://<subdominio>.ngrok-free.dev
```

Como ngrok sirve por HTTPS, no hay que tocar la configuración de seguridad de red. El cliente HTTP ya envía la cabecera que evita la página intersticial de aviso de ngrok.

---

## Generación del APK

> **No verificado:** el procedimiento no se ejecutó al redactar este README.

El comando estándar de Flutter, desde la raíz del repositorio, incluyendo la URL del backend que va a usar la app compilada:

```bash
flutter build apk --dart-define=API_URL_BASE=https://<subdominio>.ngrok-free.dev
```

El archivo resultante queda en `build/app/outputs/flutter-apk/app-release.apk`.

Dos advertencias importantes:

- **La URL del backend queda fija en el binario.** Como `--dart-define` se resuelve al compilar, un APK generado apuntando a `10.0.2.2` solo sirve dentro de un emulador. Para un teléfono hay que compilar con una dirección que el teléfono pueda alcanzar.
- **La configuración de firma de release usa las claves de depuración.** `android/app/build.gradle.kts` mantiene el valor que genera `flutter create` (`signingConfig = signingConfigs.getByName("debug")`, con su `TODO` original). El APK se puede instalar para probar, pero **no está firmado para distribución**. Definir un *keystore* propio queda pendiente.

Si la app compilada va a hablar por HTTP sin cifrar, el host correspondiente tiene que estar autorizado en `network_security_config.xml`, igual que en desarrollo.

---

## Solución de problemas frecuentes

| Síntoma | Causa y solución |
|---|---|
| «La app se compiló sin URL base» | Faltó `--dart-define=API_URL_BASE=...` en el comando |
| «No se pudo conectar» y la URL dice `localhost` | Dentro del emulador, `localhost` es el emulador. Hay que usar `10.0.2.2` |
| «No se pudo conectar» con `10.0.2.2` | El backend no está levantado. Verificar que `composer run dev` esté corriendo y que responda en `http://localhost:8000` desde la máquina |
| «No se pudo conectar» con una IP de la red local | Firewall de Windows bloqueando el puerto 8000, o falta agregar esa IP en `network_security_config.xml` |
| `CLEARTEXT communication not permitted` en el log | El host al que se apunta no está autorizado para tráfico sin cifrar en `network_security_config.xml` |
| «Ruta inexistente (404)» | `API_URL_BASE` quedó con `/api/v1` incluido y el prefijo se duplicó. La variable lleva **solo el origen** |
| «La respuesta no es la API» | Volvió HTML en lugar de JSON: la URL apunta a la web Blade del backend, o a la página intersticial de ngrok |
| El cambio de URL no surte efecto | `--dart-define` se resuelve al compilar: hay que detener y volver a ejecutar, no basta un *hot reload* |
| Gradle se queja de `minSdkVersion` | Alguna dependencia exige un nivel de API mayor que el valor por defecto. `README-PASO-0.md` documenta fijar `minSdk = 23` en `android/app/build.gradle.kts`. **Modificación no aplicada en el repositorio** y no verificada |
| `flutter pub get` falla por la versión del SDK | La versión de Flutter instalada es anterior a 3.47. Ejecutar `flutter upgrade` |
| Vuelve del pago y el pedido no aparece | La pantalla de espera consulta el estado al backend. Si el pedido no se crea, el problema está en el webhook de Mercado Pago: ver la sección correspondiente en el README del backend |
| Las imágenes de los productos no se ven | Las fotos no están versionadas en el backend y hay que cargarlas desde el panel web. Ver el README del backend |
| Sesión cerrada inesperadamente | El token de la tienda vive 30 días y no hay renovación automática: al vencer, hay que iniciar sesión otra vez |

Para leer el tráfico HTTP durante el diagnóstico, `API_LOG_HTTP` ya viene activado por defecto y cada petición y respuesta aparece en la consola de `flutter run`.

---

## Documentación de referencia

| Documento | Contenido |
|---|---|
| [Repositorio del backend](https://github.com/Shiny333Arg/powertech-backend-laravel) | Instalación del servidor, base de datos, Mercado Pago y rutina diaria completa |
| `docs/api-gestion.md` (en el backend) | API de gestión, con las convenciones de respuesta que comparte con la API de tienda |
| `README-PASO-0.md` (este repositorio) | Guía de entorno del andamiaje inicial: emulador, IP de red local, firewall y túnel |
