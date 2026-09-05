# ChatSystem — Sistema de mensajería en tiempo real tipo WeChat

Un sistema de mensajería tipo WeChat **totalmente separado entre frontend y backend**:

- **Servidor**: ASP.NET Core 10 + SignalR (WebSocket) + PostgreSQL + autenticación JWT
- **Cliente**: Flutter (`client/flutter_chat`), compatible con Web / Android / iOS
- **Administración**: Flutter (`client/flutter_admin`), compatible con Web / Android / iOS

El contrato de API del servidor y el protocolo SignalR tienen como fuente autoritativa [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md); la ayuda de uso del cliente está en [`docs/HELP.md`](docs/HELP.md).

---

## Alcance de funciones (MVP)

- Registro / inicio de sesión de cuenta (JWT, autenticación `Bearer`)
- Amigos: buscar usuarios, enviar / aceptar solicitudes de amistad, lista de amigos
- Grupos: crear grupos, mi lista de grupos
- Conversaciones: lista de conversaciones (con último mensaje, no leídos, estado en línea)
- Mensajería en tiempo real: chat privado / de grupo basado en SignalR, envío/recepción en tiempo real + aviso de estado en línea / fuera de línea
- Imágenes / archivos: subir y luego enviar; las imágenes se muestran en línea y los archivos ofrecen un enlace de descarga

---

## Estructura de directorios

```
chat/
├── server/                 # Servidor ASP.NET Core 10
│   ├── ChatServer/         # API principal + SignalR Hub (Controllers / Hubs / Services / Entities / Data)
│   ├── AdminServer/        # API de administración
│   └── docker-compose.yml  # PostgreSQL con un clic
├── client/
│   ├── flutter_chat/       # Cliente de usuario (Flutter, compilación verificada)
│   └── flutter_admin/      # Cliente de administración (Flutter, compilación verificada)
└── docs/
    ├── ARCHITECTURE.md     # Contrato de API / protocolo (autoritativo)
    └── HELP.md             # Ayuda de uso del cliente
```

---

## 1. Iniciar el servidor

### Requisitos previos
- SDK de .NET 10
- PostgreSQL (se recomienda inicio con Docker en un clic)

### Iniciar la base de datos
```bash
cd server
docker compose up -d          # Inicia PostgreSQL (puerto 5432; bd/usuario/contraseña en docker-compose.yml)
```

### Configuración (multientorno)
La configuración se divide por entorno y se cambia con la variable de entorno `ASPNETCORE_ENVIRONMENT=Development|Production`
(predeterminado: Development). Consulte los archivos de cada servicio:

- `appsettings.json` —— configuración base común
- `appsettings.Development.json` —— desarrollo (localhost, clave de desarrollo, CORS permisivo)
- `appsettings.Production.json` —— producción (**valores de marcador — deben reemplazarse u omitirse vía variables de entorno antes del despliegue**:
  `CONNECTIONSTRINGS__DEFAULT`, `Jwt__Key`, `SeedAdmin__Password`, etc.)

Claves comunes: `ConnectionStrings:Default` (cadena de conexión PostgreSQL), `Jwt:Key` (clave de firma),
`Urls` (dirección de escucha), `Cors:Origins` (orígenes de frontend permitidos).

### Ejecutar
```bash
cd server/ChatServer
dotnet run -c Release
# o publicar
dotnet publish -c Release -o out
```
Tras el inicio:
- Base de la API: `http://localhost:5298`
- Documentación Swagger: `http://localhost:5298/swagger`
- Hub de SignalR: `http://localhost:5298/hubs/chat`
- Comprobación de estado: `http://localhost:5298/health` (devuelve `Healthy` cuando el proceso y la BD están bien)
- Archivos estáticos / subidos: `http://localhost:5298/files/...`

> EF Core hace `EnsureCreated()` automáticamente al iniciar (demo). Para producción, use migraciones:
> `dotnet ef migrations add Init && dotnet ef database update`.

AdminServer es igual (`http://localhost:5299`, `/health` también disponible).

---

## 2. Cliente Flutter

El código fuente está en `client/flutter_chat` (cliente de usuario) y `client/flutter_admin` (cliente de administración).

### Desarrollo local
```bash
cd client/flutter_chat
flutter pub get
flutter run -d chrome      # Web
flutter run -d android     # Dispositivo/emulador Android
```

Formas de definir la dirección de la API (elija una):
- **En compilación**: `flutter build web --dart-define=API_BASE=https://your.api`
- **En ejecución**: sobrescribir manualmente en "Ajustes" de la página de inicio de sesión, o importar con un enlace de configuración (ver `docs/HELP.md`)

### Compilación y publicación
La compilación del cliente, el empaquetado dividido del APK de Android, la compilación de iOS y la publicación del sitio estático los hace automáticamente la CI — ver Sección 4.
Las funciones del cliente (escaneo, enlaces de configuración, página de descarga, etc.) están en [`docs/HELP.md`](docs/HELP.md).

---

## 3. Contrato de API y protocolo

Las API REST, el protocolo del Hub SignalR y las estructuras de mensajes siguen [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).
Puntos clave de un vistazo:

- Auth: `POST /api/auth/register`, `POST /api/auth/login` (devuelve `token` + `user`)
- Usuario / Amigos: `GET /api/users/search`, `POST /api/friends/request`, `GET /api/friends`, etc.
- Grupos / Conversaciones: `POST /api/groups`, `GET /api/conversations`
- Archivos: `POST /api/files/upload` (multipart, campo `file`)
- Tiempo real: `/hubs/chat` (`SendPrivateMessage` / `SendGroupMessage` / `JoinGroup`; empuja `ReceiveMessage` / `UserOnline` / `UserOffline`)

Todas las peticiones REST necesitan `Authorization: Bearer <token>` en la cabecera.

---

## 4. CI/CD y publicación estática de frontend

`.github/workflows/ci-cd.yml` ejecuta puertas de calidad (compilación .NET + Flutter analyze) en push / PR,
y además compila las dos apps Flutter Web **y el APK de Android** al hacer push a `main`, publicándolas juntas:

| Artefacto | Ruta de publicación |
| --- | --- |
| `client/flutter_chat` (cliente de usuario) | <https://servestatic.github.io/Chat/> |
| `client/flutter_admin` (cliente de administración) | <https://servestatic.github.io/Chat/admin/> |
| Página de descarga del APK de Android | <https://servestatic.github.io/Chat/download/> |
| Generador de enlaces de configuración | <https://servestatic.github.io/Chat/config/> |

El sitio se aloja en la rama `gh-pages` del repositorio [`ServeStatic/Chat`](https://github.com/ServeStatic/Chat).

### APK de Android

Cada despliegue compila los paquetes de instalación **divididos por arquitectura de CPU** (el paquete universal se eliminó por superar el límite de 100 MB por archivo de GitHub):

| Archivo | Descripción |
| --- | --- |
| `chat-arm64-v8a.apk` | La mayoría de los teléfonos modernos, tamaño mínimo (recomendado) |
| `chat-armeabi-v7a.apk` | Dispositivos de 32 bits más antiguos |
| `chat-x86_64.apk` | Emuladores y algunas tablets |

La página de descarga la genera `.github/scripts/gen-download-page.sh`; cada tarjeta de APK incrusta un código QR de su URL de descarga,
y el pie añade códigos QR directos de "App de chat" y "Generador de configuración".

#### Sobre la firma

La compilación de release se firma con la clave debug predeterminada de la plantilla de Flutter, por lo que la CI no necesita keystore, pero:
1. Al instalar, Google Play Protect avisa "Publicador desconocido"; elija "Instalar de todas formas";
2. Cambiar la clave de firma impide a los usuarios ya instalados actualizar sin desinstalar primero.

Antes de la publicación oficial, defina `signingConfigs.release` en `build.gradle.kts`, guarde el keystore en base64
en secrets (p. ej. `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEY_*`), y descódelo en el job `build-android` antes de compilar.

#### Compilación de iOS y subida a TestFlight

`build-ios` se ejecuta en un runner `macos-latest` (Xcode solo está en macOS). Por defecto produce un
`Runner.app` **sin firmar** (solo comprobación de compilación).

##### IPA firmado (instalable en dispositivos)

Cuando se configuran los siguientes secrets produce automáticamente un `Runner.ipa` **firmado**:

| Secret | Descripción |
| --- | --- |
| `IOS_DIST_CERT_BASE64` | Certificado de distribución p12, en base64 |
| `IOS_DIST_CERT_PASSWORD` | Contraseña p12 |
| `IOS_PROVISIONING_PROFILE_BASE64` | `.mobileprovision`, en base64 (**debe ser tipo App Store Connect para TestFlight**, no Ad Hoc) |
| `IOS_TEAM_ID` (opcional) | Apple Team ID |

Si no se configuran los secrets, retrocede a una compilación sin firmar y la CI no falla. `ExportOptions.plist` está en
`client/flutter_chat/ios/ExportOptions.plist`, con `method` ya en `app-store`.

##### Subir a TestFlight

Además de la firma, configure estos tres secrets de la API Key de App Store Connect y la CI subirá automáticamente el IPA a App Store Connect (luego cree un grupo en TestFlight):

| Secret | Descripción |
| --- | --- |
| `IOS_APP_STORE_CONNECT_API_KEY_BASE64` | `AuthKey_XXXX.p8`, en base64 |
| `IOS_APP_STORE_CONNECT_KEY_ID` | API Key ID (10 caracteres, p. ej. `ABCD123456`) |
| `IOS_APP_STORE_CONNECT_ISSUER_ID` | Issuer ID (UUID) |

**Cómo obtener la API Key de App Store Connect:**
1. Inicie sesión en [App Store Connect](https://appstoreconnect.apple.com) → Usuarios y acceso → **Integraciones** → App Store Connect API → "+" para crear (la clave está en la pestaña **Integraciones**, no en **Usuarios**).
2. Elija una **Clave de equipo** (no una clave personal).
3. El acceso debe ser **App Manager**; una clave "Developer" no puede subir IPAs.
4. El **Issuer ID** (UUID) que aparece arriba de la página es `IOS_APP_STORE_CONNECT_ISSUER_ID`; el **Key ID** que aparece al crear es `IOS_APP_STORE_CONNECT_KEY_ID`.
5. Haga clic en "Descargar API Key" para obtener `AuthKey_XXXX.p8` (**solo se descarga una vez** — guárdela localmente), luego codifíquela en base64 en `IOS_APP_STORE_CONNECT_API_KEY_BASE64`:
   - macOS/Linux: `base64 -w0 AuthKey_XXXX.p8`
   - Windows PowerShell: `[Convert]::ToBase64String([IO.File]::ReadAllBytes("AuthKey_XXXX.p8"))`

### Configuración única

> La rama `gh-pages` la crea automáticamente el workflow en el primer despliegue (force push) — no es necesario crearla manualmente; pero la configuración de Pages
> solo lista ramas existentes, así que "Activar Pages" debe ir después del primer despliegue.

1. **Token de despliegue**: genere un PAT con permiso de escritura (`repo`) sobre `ServeStatic/Chat`, y añádalo en este repo en
   **Settings → Secrets and variables → Actions** como `SERVESTATIC_DEPLOY_TOKEN`.
2. **(Opcional) Dirección de API en línea**: en **Settings → Secrets and variables → Actions → Variables** añada
   - `PUBLIC_API_BASE` —— base de la API del cliente (`--dart-define=API_BASE`)
   - `PUBLIC_ADMIN_API_BASE` —— base de la API de administración (`--dart-define=ADMIN_API_BASE`)
   - `PUBLIC_WEB_BASE` —— raíz del sitio estático, predeterminado `https://servestatic.github.io/Chat/`,
     afecta al destino del código QR de la página de descarga (defínalo para dominios propios)

   Si no se define, la compilación publicada sigue conectando a `http://localhost:5298 / :5299`; los usuarios también pueden sobrescribirlo en "Ajustes".
3. **(Opcional) Dirección de la página de descarga**: si el sitio estático y la API están en dominios distintos, inyecte
   `DOWNLOAD_URL` en compilación (`--dart-define=DOWNLOAD_URL=https://example.com/download/`),
   y el botón "Descargar cliente" de la página de inicio cambia en consecuencia; también puede enviarse en ejecución con un enlace de configuración (ver `docs/HELP.md`).
4. **Disparar el primer despliegue**: haga push a `main` y espere a que termine el job `Deploy to ServeStatic/Chat` (la rama `gh-pages` aparece solo entonces).
5. **Activar Pages**: en **Settings → Pages** de `ServeStatic/Chat` elija
   *Build and deployment → Source: Deploy from a branch*, rama `gh-pages`, directorio `/ (root)`.

> Las URLs de página de proyecto distinguen mayúsculas/minúsculas; `--base-href` usa `/Chat/`, `/Chat/admin/`; dominios propios o páginas de organización necesitan `/`, `/admin/`.

### Funciones del cliente

- **Escanear**: entrada en la página de inicio de sesión y en "Descubrir"; reconoce enlaces web, enlaces de configuración (`fairchat://config`) y texto plano.
- **Página de descarga**: <https://servestatic.github.io/Chat/download/>, cada APK por arquitectura lleva un código QR.
- **Generador de enlaces de configuración**: <https://servestatic.github.io/Chat/config/>, genera visualmente enlaces `fairchat://config`.

---

## 5. Límites conocidos y ampliaciones futuras

- **Persistencia**: PostgreSQL + EF Core; sin cursor de paginación de mensajes / persistencia de confirmación de lectura (el protocolo reserva `ReadReceipt`).
- **Escalado horizontal**: `PresenceTracker` en memoria de un solo nodo SignalR; multinodo necesita Redis Backplane + distribución externa de IDs.
- **Seguridad**: la clave JWT y CORS son configuración de demostración — en producción use claves fuertes, HTTPS, CORS estricto, validación de archivos y escaneo de virus.
- **Push**: los clientes nativos en producción deberían integrar FCM / APNs para push sin conexión (SignalR es solo canal en línea en tiempo real).
