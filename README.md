# Booking Artist (prototipo)

App móvil (iOS y Android) hecha con Flutter para reservar músicos, agrupaciones, DJs y payasos.
Para todo Puerto Rico (la primera prueba fue en Caguas). Usa datos de ejemplo: seis artistas ficticios y un perfil de prueba de Kimy-K Acústico (artista real, con su Instagram público; precios de ejemplo).

## Qué incluye
- **Crear cuenta**: al abrir la app se escoge "Quiero contratar" o "Soy artista".
  - Cliente: nombre, teléfono, correo, contraseña y si es **cliente privado**, **restaurante/negocio** o **agrupación/banda** (con nombre y dirección del local, que se llenan solos al reservar).
  - Artista: tipo (**Solista**, **Músico independiente**, **Agrupación**, **DJ** o **Payaso**), instrumentos que toca, nombre artístico, géneros y datos de contacto. Las agrupaciones pueden buscar músicos independientes por instrumento (bongosero, bajista, cuatrista…).
- **Mi página (artista)**: subir foto de perfil, portada y galería de fotos; frase corta, biografía, géneros, eventos que acepta y color de la página. El botón "Ver" muestra la página como la ven los clientes. Un artista aparece en Explorar cuando publica al menos un precio.
- **Explorar**: artistas cerca de ti, búsqueda por nombre o género, filtros por tipo de artista y de evento, orden por distancia, precio o valoración.
- **Perfil del artista**: biografía, géneros, precios fijados por el artista, videos y redes (enlaces públicos que el artista pega).
- **Reservar y pagar**: paquete, tipo de evento, fecha, hora, lugar y notas; el cliente lee y acepta las condiciones del artista (depósito y cancelación) y paga el depósito o el total con tarjeta (Stripe) o ATH Móvil. Con tarjeta el dinero queda retenido y se cobra solo si el artista acepta; si rechaza, se libera. ATH Móvil cobra al momento y se reembolsa si el artista rechaza o el cliente cancela. Tarifa de la plataforma: 10 %. Tarjeta de prueba: 4242 4242 4242 4242.
- **Mis reservas**: estado de cada solicitud (pendiente, confirmada, cancelada). Después de un evento confirmado, el cliente puede dejarle **estrellas (1 a 5) y una reseña** al artista; se ven en su página y en su panel.
- **Paquetes de restaurante o de actividades**: el artista marca cada paquete. Los de **actividades** (bodas, cumpleaños, eventos) piden depósito; los de **restaurante** son solo la reserva: no se paga nada por la app ni hay tarifa, y el pago se arregla directo con el artista.
- **Suscripción del artista**: $10 al mes para aparecer en la app, con el **primer mes gratis** desde que crea su cuenta (sin pedir tarjeta). Si se suscribe durante el mes gratis, Stripe no cobra hasta que termine. Si se acaba el mes gratis sin suscribirse, o cancela, su página deja de salir en Explorar y no se le puede reservar.
- **Solicitudes (artista)**: el artista edita sus precios, añade enlaces de YouTube/Instagram/TikTok y acepta o rechaza solicitudes, viendo si vienen de un cliente privado o de un restaurante.

- **Disponibilidad**: el artista define su horario semanal (qué días y de qué hora a qué hora), sus días libres y el tiempo que necesita entre eventos. Al reservar, el cliente solo puede escoger días y horas libres; las reservas pendientes o confirmadas bloquean ese horario.
- **Avisos**: cuando llega una solicitud de reserva, el artista recibe una notificación en su teléfono y un email. Cuando el artista acepta o rechaza, el cliente también recibe aviso. En el prototipo se ven en la pestaña Mensajes > Avisos.
- **Chat**: el cliente puede escribirle al artista desde su página o desde sus reservas, y el artista le responde desde sus solicitudes o desde Mensajes.
- **Cuentas de prueba**: en la bienvenida hay dos botones para entrar como "Restaurante El Patio" o como la artista "Sofía Rivera" (contraseña `demo123`). Así se puede reservar como cliente, cerrar sesión y ver el otro lado.

Los videos de YouTube, Instagram (reels y publicaciones) y TikTok se ven dentro de la app con el reproductor oficial al pegar su enlace (en teléfono; en la versión web se abren en otra pestaña).

Las cuentas, fotos y reservas viven en memoria; al cerrar la app se reinician. Para guardarlas de verdad hace falta un servidor (por ejemplo Firebase o Supabase), y para cobrar de verdad un procesador de pagos como Stripe.

## Cómo correrlo en tu computadora
1. Instala Flutter: https://docs.flutter.dev/get-started/install
2. En VS Code instala la extensión **Flutter** (instala también Dart).
3. Abre esta carpeta en VS Code y en una terminal ejecuta:
   ```
   flutter pub get
   flutter run -d chrome
   ```
   Para verlo en un teléfono Android conecta el teléfono (modo desarrollador) o abre un emulador de Android Studio y ejecuta `flutter run`.
   Para iPhone necesitas una Mac con Xcode.

## Cómo probarlo en un iPhone
1. **Lo más rápido (sin instalar nada):** abre el enlace de la demo en Safari en el iPhone. Es la versión web de la misma app.
2. **Como app instalada, si tienes una Mac:** instala Xcode, conecta el iPhone por cable y ejecuta `flutter run`. Con un Apple ID gratis la app dura 7 días en el teléfono.
3. **Como app instalada, desde Windows:** crea una cuenta de Apple Developer (99 dólares al año) y usa un servicio en la nube como Codemagic, que compila la app para iPhone y la sube a TestFlight. Luego la instalas con la app TestFlight, igual que una app de la App Store.

## Qué falta para la versión real
- Servidor con cuentas, datos y chat en tiempo real (por ejemplo Firebase: Authentication + Firestore).
- Notificaciones al teléfono: Firebase Cloud Messaging (en iPhone pasa por el servicio de Apple, APNs).
- Emails: un proveedor como SendGrid o Resend, llamado desde el servidor.
- Pagos: Stripe, con retención del pago hasta que el artista acepta.

## Estructura
- `lib/main.dart`: arranque y barra de navegación
- `lib/models.dart`: artista, paquete de precios, reserva
- `lib/data/mock_artists.dart`: artistas de ejemplo (aquí se cambian)
- `lib/app_state.dart`: estado de la app
- `lib/screens/`: pantallas

## Guardar datos en la nube (Firebase)

La app funciona en dos modos:

- **Modo demo** (si `lib/firebase_options.dart` tiene `cloudOptions = null`): todo vive en memoria y se borra al recargar. Aparecen las cuentas de prueba.
- **Modo nube**: con la configuración del proyecto de Firebase en `lib/firebase_options.dart`, las cuentas, páginas de artistas, reservas, chats y avisos se guardan en Firestore y se ven en vivo en todos los teléfonos.

Para activarlo en la Consola de Firebase:

1. Authentication → Correo electrónico/contraseña → Habilitar.
2. Firestore Database → Crear base de datos.
3. Firestore Database → Reglas: pega el contenido de `firestore.rules` y toca Publicar.
4. Copia el `firebaseConfig` de la app web en `lib/firebase_options.dart`.

Las fotos se guardan dentro de Firestore (hasta ~850 KB por artista). Con Firebase Storage se podrán guardar sin ese límite.

Para probar en la computadora sin tocar los datos reales, abre la app con `?emulador` y corre los emuladores de Firebase (`firebase emulators:start --only auth,firestore`).

## SMS y emails (Twilio + Resend)

`vercel/api/notify.js` es una función de Vercel. Cuando la app guarda un aviso, llama a `/api/notify`; la función comprueba quién la llama, busca el teléfono y el correo del destinatario en Firebase y envía el SMS (solo avisos de reservas) y el email (todos los avisos). Para publicarla, el zip de Vercel incluye `api/notify.js` y `package.json` junto a la app.

Variables de entorno en Vercel: `FIREBASE_SERVICE_ACCOUNT`, `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`, `TWILIO_FROM`, `RESEND_API_KEY`, `EMAIL_FROM` y `APP_URL` (opcional).

Para ver qué canales están activos, abre `https://booking-artist-khaki.vercel.app/api/notify` en el navegador (no muestra llaves). Mientras `EMAIL_FROM` use `@resend.dev`, Resend solo entrega al correo de tu propia cuenta; para escribirle a cualquiera hay que verificar un dominio. Pruebas sin internet: `node vercel/test/notify.test.js`.

## Cobros: tarjeta (Stripe) y ATH Móvil

`vercel/api/pay.js` es la función de Vercel que cobra. La app nunca ve llaves secretas ni decide el monto: crea la reserva sin pagar (`payment: porPagar`), llama a `/api/pay` y el servidor lee el precio del paquete en Firestore, calcula tarifa y depósito, y es el único que cambia el pago y el estado de la reserva (las reglas de Firestore lo impiden desde la app).

- Tarjeta: Stripe Checkout con captura manual. La app abre la página segura de Stripe; el dinero queda retenido y se cobra cuando el artista acepta. La retención de una tarjeta dura unos 7 días: si el artista tarda más, hay que reservar de nuevo.
- ATH Móvil: Botón de Pago de ATH Business (API de Evertec). El cliente escribe su teléfono, confirma en la app de ATH Móvil y el servidor completa el cobro. Si el artista rechaza o el cliente cancela, se reembolsa. Máximo $1,500 por pago. ATH Móvil no tiene ambiente de prueba: cada prueba mueve dinero real (mínimo $1).
- Si falta la llave de un método, ese método funciona en modo simulado (no cobra). Si el servidor no tiene `FIREBASE_SERVICE_ACCOUNT`, toda la app usa pago simulado.

Variables de entorno en Vercel: `STRIPE_SECRET_KEY` (`sk_test_...` para pruebas), `ATHM_PUBLIC_TOKEN`, `ATHM_PRIVATE_TOKEN`, `FEE_RATE` (opcional, 0.10) y las de arriba. En el teléfono la app llama a `https://booking-artist-khaki.vercel.app/api/...`; se cambia con `--dart-define=API_URL=https://...`.

Pruebas del servidor (sin internet ni llaves): `node vercel/test/pay.test.js`.

## Suscripción de artistas ($10 al mes)

`vercel/api/subscribe.js` (copiado en `api/subscribe.js`) maneja la suscripción con Stripe Billing. El estado vive en Firestore en `subscriptions/{uid}` (todos lo leen, solo el servidor lo escribe) y el cliente de Stripe en `billing/{uid}` (solo el servidor). Usa las mismas variables que los cobros (`FIREBASE_SERVICE_ACCOUNT`, `STRIPE_SECRET_KEY`); opcional `STRIPE_PRICE_ID` si prefieres crear el precio de $10/mes en Stripe. Sin `STRIPE_SECRET_KEY` la suscripción se activa en modo de prueba (no cobra).

Para que los cobros de cada mes (o una tarjeta rechazada) se reflejen solos, en Stripe → Desarrolladores → Webhooks añade `https://booking-artist-khaki.vercel.app/api/subscribe` con los eventos `customer.subscription.*` e `invoice.payment_failed`. El servidor no confía en el aviso: vuelve a leer la suscripción en Stripe. Pruebas sin internet: `node vercel/test/subscribe.test.js`.

## Publicación web

`web_build/` es la versión web ya compilada (`flutter build web --release --no-web-resources-cdn`).
Vercel publica esa carpeta (ver `vercel.json`) y las funciones de `api/`, que son copia de `vercel/api/`.
Para actualizarla: compilar, reemplazar `web_build/` con `build/web/` y hacer push a `main`.

Sitio: https://booking-artist-khaki.vercel.app (se publica solo al hacer push a `main`).
