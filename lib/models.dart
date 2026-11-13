import 'dart:typed_data';

import 'package:flutter/material.dart';

enum ArtistCategory { solista, musicoIndependiente, agrupacion, dj, payaso }

extension ArtistCategoryInfo on ArtistCategory {
  String get label => switch (this) {
    ArtistCategory.solista => 'Solista',
    ArtistCategory.musicoIndependiente => 'Músico independiente',
    ArtistCategory.agrupacion => 'Agrupación',
    ArtistCategory.dj => 'DJ',
    ArtistCategory.payaso => 'Payaso',
  };

  String get description => switch (this) {
    ArtistCategory.solista => 'Toca y canta solo',
    ArtistCategory.musicoIndependiente =>
      'Toca un instrumento con otros músicos o agrupaciones',
    ArtistCategory.agrupacion => 'Banda, orquesta, trío o conjunto',
    ArtistCategory.dj => 'Música con equipo de DJ',
    ArtistCategory.payaso => 'Show, juegos y animación para fiestas',
  };

  IconData get icon => switch (this) {
    ArtistCategory.solista => Icons.mic_external_on,
    ArtistCategory.musicoIndependiente => Icons.piano,
    ArtistCategory.agrupacion => Icons.groups,
    ArtistCategory.dj => Icons.headphones,
    ArtistCategory.payaso => Icons.sentiment_very_satisfied,
  };

  /// Categorías en las que el artista indica qué instrumentos toca.
  bool get hasInstruments =>
      this == ArtistCategory.solista ||
      this == ArtistCategory.musicoIndependiente;
}

const instrumentOptions = [
  'Cantante',
  'Guitarrista',
  'Cuatrista',
  'Requintista',
  'Bajista',
  'Baterista',
  'Percusionista',
  'Bongosero',
  'Conguero',
  'Timbalero',
  'Güirero',
  'Pianista',
  'Tecladista',
  'Trompetista',
  'Trombonista',
  'Saxofonista',
  'Violinista',
  'Coro',
];

enum EventType { restaurante, actividad, boda, cumpleanos, conAgrupacion }

extension EventTypeInfo on EventType {
  String get label => switch (this) {
    EventType.restaurante => 'Restaurante',
    EventType.actividad => 'Actividad',
    EventType.boda => 'Boda',
    EventType.cumpleanos => 'Cumpleaños',
    EventType.conAgrupacion => 'Tocar con agrupación',
  };

  IconData get icon => switch (this) {
    EventType.restaurante => Icons.restaurant,
    EventType.actividad => Icons.celebration,
    EventType.boda => Icons.favorite,
    EventType.cumpleanos => Icons.cake,
    EventType.conAgrupacion => Icons.queue_music,
  };
}

/// Para qué es un paquete. Los de actividades piden depósito; los de
/// restaurante son solo la reserva, sin pagar nada por la app.
enum PackageKind { actividad, restaurante }

extension PackageKindInfo on PackageKind {
  String get label => switch (this) {
    PackageKind.actividad => 'Actividad o evento',
    PackageKind.restaurante => 'Restaurante',
  };

  String get description => switch (this) {
    PackageKind.actividad =>
      'Bodas, cumpleaños, actividades. El cliente deja un depósito.',
    PackageKind.restaurante =>
      'Sin depósito: el cliente solo reserva la fecha.',
  };

  IconData get icon => switch (this) {
    PackageKind.actividad => Icons.celebration,
    PackageKind.restaurante => Icons.restaurant,
  };
}

/// Paquete con precio fijado por el propio artista.
class PricePackage {
  PricePackage({
    required this.name,
    required this.price,
    required this.hours,
    this.description = '',
    this.kind = PackageKind.actividad,
  });

  String name;
  double price;
  double hours;
  String description;
  PackageKind kind;

  /// Solo los paquetes de actividades piden depósito al reservar.
  bool get takesDeposit => kind == PackageKind.actividad;
}

/// Reseña que deja un cliente después de un evento confirmado. Una por
/// reserva (su id es el de la reserva).
class Review {
  Review({
    required this.id,
    required this.artistId,
    required this.clientUid,
    required this.clientName,
    required this.rating,
    required this.text,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final String artistId;
  final String clientUid;
  final String clientName;

  /// Estrellas, de 1 a 5.
  int rating;
  String text;
  DateTime createdAt;
}

/// Precio de la suscripción del artista y días de prueba gratis. El servidor
/// (/api/subscribe) usa los mismos valores.
const subscriptionPrice = 10.0;
const trialDays = 30;

/// Fecha desde la que cuentan los días gratis de los artistas que ya tenían
/// cuenta antes de que existiera la suscripción.
final subscriptionLaunch = DateTime(2026, 11, 7);

/// Suscripción mensual del artista. Sin ella (o sin la prueba gratis) su
/// página no aparece en la app. Solo el servidor la cambia.
class Subscription {
  Subscription({
    required this.status,
    required this.trialEnd,
    this.paidUntil,
    this.cancelAtPeriodEnd = false,
    this.simulated = false,
  });

  /// Estado en Stripe: sinTarjeta (prueba sin suscribirse), trialing, active,
  /// past_due, canceled…
  String status;
  DateTime trialEnd;

  /// Hasta cuándo está pagada (fin del periodo actual).
  DateTime? paidUntil;
  bool cancelAtPeriodEnd;

  /// Activada sin cobrar (servidor sin llave de Stripe, o modo demo).
  bool simulated;

  /// Ya puso su tarjeta (está suscrito, aunque siga en la prueba).
  bool get subscribed =>
      status == 'trialing' || status == 'active' || status == 'past_due';

  bool get inTrial => DateTime.now().isBefore(trialEnd);

  /// Hasta cuándo aparece en la app.
  DateTime get visibleUntil {
    final paid = subscribed ? paidUntil : null;
    // Si un cobro falla, Stripe reintenta unos días: se deja ese margen.
    final grace = status == 'past_due'
        ? paid?.add(const Duration(days: 7))
        : paid;
    return grace != null && grace.isAfter(trialEnd) ? grace : trialEnd;
  }

  bool get visible => DateTime.now().isBefore(visibleUntil);

  int get trialDaysLeft {
    final h = trialEnd.difference(DateTime.now()).inHours;
    return h <= 0 ? 0 : (h / 24).ceil();
  }
}

enum LinkKind { youtube, instagram, tiktok, spotify, facebook, web }

extension LinkKindInfo on LinkKind {
  String get label => switch (this) {
    LinkKind.youtube => 'YouTube',
    LinkKind.instagram => 'Instagram',
    LinkKind.tiktok => 'TikTok',
    LinkKind.spotify => 'Spotify',
    LinkKind.facebook => 'Facebook',
    LinkKind.web => 'Web',
  };

  IconData get icon => switch (this) {
    LinkKind.youtube => Icons.smart_display,
    LinkKind.instagram => Icons.camera_alt,
    LinkKind.tiktok => Icons.music_video,
    LinkKind.spotify => Icons.graphic_eq,
    LinkKind.facebook => Icons.facebook,
    LinkKind.web => Icons.language,
  };

  Color get color => switch (this) {
    LinkKind.youtube => const Color(0xFFE53935),
    LinkKind.instagram => const Color(0xFFC13584),
    LinkKind.tiktok => const Color(0xFF222222),
    LinkKind.spotify => const Color(0xFF1DB954),
    LinkKind.facebook => const Color(0xFF1877F2),
    LinkKind.web => const Color(0xFF546E7A),
  };
}

/// Enlace público que el artista pega en su perfil (video, red social…).
class MediaLink {
  const MediaLink({required this.kind, required this.title, required this.url});

  final LinkKind kind;
  final String title;
  final String url;
}

class Artist {
  Artist({
    required this.id,
    required this.name,
    required this.category,
    required this.genres,
    required this.bio,
    required this.zone,
    required this.distanceKm,
    required double rating,
    required int reviews,
    required this.color,
    required this.packages,
    required this.links,
    required this.eventTypes,
    this.verified = false,
    this.photoUrl,
    this.demoNote,
    this.tagline = '',
    List<String>? instruments,
    this.depositPercent = 30,
    this.conditions = defaultConditions,
    this.email = '',
    Map<int, DayHours>? weeklyHours,
    this.bufferMinutes = 60,
    this.createdAt,
    this.subscription,
  }) : baseRating = rating,
       baseReviews = reviews,
       instruments = instruments ?? [],
       weeklyHours = weeklyHours ?? defaultWeeklyHours();

  /// En la nube es el id de la cuenta del artista.
  String id;
  String name;
  ArtistCategory category;
  List<String> genres;
  String bio;
  final String zone;
  final double distanceKm;

  /// Valoración de ejemplo (artistas de la demo). Se combina con las reseñas
  /// reales de [reviewList].
  final double baseRating;
  final int baseReviews;

  /// Reseñas que dejaron los clientes en la app.
  final List<Review> reviewList = [];

  int get reviews => baseReviews + reviewList.length;

  /// Promedio de estrellas, con un decimal.
  double get rating {
    if (reviews == 0) return 0;
    final sum =
        baseRating * baseReviews +
        reviewList.fold<int>(0, (s, r) => s + r.rating);
    return (sum / reviews * 10).round() / 10;
  }

  /// Cuándo creó su cuenta (los días gratis cuentan desde ahí).
  DateTime? createdAt;

  /// Suscripción guardada por el servidor. Si falta, se calcula la prueba
  /// gratis desde [createdAt].
  Subscription? subscription;

  /// Fin de la prueba gratis si el servidor todavía no la registró.
  DateTime get trialEnd {
    final start = createdAt ?? subscriptionLaunch;
    return (start.isAfter(subscriptionLaunch) ? start : subscriptionLaunch).add(
      const Duration(days: trialDays),
    );
  }

  Subscription get effectiveSubscription =>
      subscription ?? Subscription(status: 'sinTarjeta', trialEnd: trialEnd);

  /// Aparece en Explorar: tiene al menos un precio y está suscrito o en su
  /// mes gratis.
  bool get listed => packages.isNotEmpty && effectiveSubscription.visible;

  /// Pide depósito en al menos uno de sus paquetes.
  bool get takesDeposits => packages.any((p) => p.takesDeposit);
  Color color;
  final List<PricePackage> packages;
  final List<MediaLink> links;
  Set<EventType> eventTypes;
  final bool verified;

  /// Foto pública del artista (enlace). Si falta, se muestran sus iniciales.
  final String? photoUrl;

  /// Aviso visible en el perfil, p. ej. para artistas reales sin cuenta propia.
  final String? demoNote;

  /// Frase corta que el artista muestra bajo su nombre.
  String tagline;

  /// Instrumentos que toca (solistas y músicos independientes).
  List<String> instruments;

  /// Porcentaje del total que el cliente paga como depósito al reservar.
  int depositPercent;

  /// Condiciones que el cliente acepta antes de pagar.
  String conditions;

  /// Correo donde el artista recibe avisos de nuevas solicitudes.
  String email;

  /// Horario semanal: día (1 = lunes … 7 = domingo) → horas disponibles.
  /// Un día que no aparece es un día en que no trabaja.
  final Map<int, DayHours> weeklyHours;

  /// Fechas sueltas en que no está disponible (vacaciones, compromisos).
  final Set<DateTime> daysOff = {};

  /// Tiempo libre que se deja antes y después de cada evento (traslado y
  /// montaje).
  int bufferMinutes;

  /// Horas ocupadas por reservas que esta app no tiene cargadas (las de
  /// otros clientes, cuando los datos vienen de la nube).
  final List<(DateTime, DateTime)> busy = [];

  /// Fotos que el artista sube desde su teléfono.
  Uint8List? photo;
  Uint8List? cover;
  final List<Uint8List> gallery = [];

  double get minPrice => packages.isEmpty
      ? 0
      : packages.map((p) => p.price).reduce((a, b) => a < b ? a : b);

  String get initials => name
      .split(' ')
      .where((w) => w.isNotEmpty)
      .take(2)
      .map((w) => w[0])
      .join();
}

/// Horas de un día de trabajo, en minutos desde la medianoche.
/// [end] puede ser 1440 (las 12:00 de la medianoche).
class DayHours {
  const DayHours(this.start, this.end);

  final int start;
  final int end;
}

const weekdayNames = {
  1: 'Lunes',
  2: 'Martes',
  3: 'Miércoles',
  4: 'Jueves',
  5: 'Viernes',
  6: 'Sábado',
  7: 'Domingo',
};

/// Horario de ejemplo: martes a jueves en la noche, fines de semana todo el día.
Map<int, DayHours> defaultWeeklyHours() => {
  2: const DayHours(17 * 60, 23 * 60),
  3: const DayHours(17 * 60, 23 * 60),
  4: const DayHours(17 * 60, 23 * 60),
  5: const DayHours(17 * 60, 24 * 60),
  6: const DayHours(11 * 60, 24 * 60),
  7: const DayHours(11 * 60, 22 * 60),
};

const defaultConditions =
    'Cancelación gratis hasta 7 días antes del evento. '
    'Después de eso el depósito no se devuelve. '
    'El cliente provee electricidad y un espacio techado para tocar.';

enum BookingStatus { pendiente, confirmada, rechazada, cancelada }

extension BookingStatusInfo on BookingStatus {
  String get label => switch (this) {
    BookingStatus.pendiente => 'Esperando respuesta',
    BookingStatus.confirmada => 'Confirmada',
    BookingStatus.rechazada => 'Rechazada',
    BookingStatus.cancelada => 'Cancelada',
  };

  Color get color => switch (this) {
    BookingStatus.pendiente => const Color(0xFFF9A825),
    BookingStatus.confirmada => const Color(0xFF2E7D32),
    BookingStatus.rechazada => const Color(0xFFC62828),
    BookingStatus.cancelada => const Color(0xFF9E9E9E),
  };
}

/// Estado del pago.
///
/// Con tarjeta el monto se retiene al reservar y solo se cobra si el artista
/// acepta. ATH Móvil no retiene: cobra al momento (pagado) y se reembolsa si
/// el artista no acepta.
enum PaymentStatus {
  /// La reserva se creó, pero el cliente todavía no terminó de pagar.
  porPagar,
  retenido,

  /// Cobrado por ATH Móvil; falta que el artista acepte.
  pagado,
  cobrado,
  liberado,
  reembolsado,

  /// Pago de prueba hecho sin servidor de pagos: no se cobró nada.
  simulado,

  /// Paquete de restaurante: solo se reserva, no se paga nada por la app.
  sinPago,
}

extension PaymentStatusInfo on PaymentStatus {
  String get label => switch (this) {
    PaymentStatus.porPagar => 'Pago sin completar',
    PaymentStatus.retenido => 'Pago retenido, se cobra si el artista acepta',
    PaymentStatus.pagado => 'Pagado; se devuelve si el artista no acepta',
    PaymentStatus.cobrado => 'Pagado',
    PaymentStatus.liberado => 'No se cobró nada',
    PaymentStatus.reembolsado => 'Reembolsado',
    PaymentStatus.simulado => 'Pago de prueba (no se cobró)',
    PaymentStatus.sinPago => 'Sin depósito: solo reserva',
  };
}

/// Formas de pago.
enum PaymentMethod { tarjeta, ath, prueba, ninguno }

extension PaymentMethodInfo on PaymentMethod {
  String get label => switch (this) {
    PaymentMethod.tarjeta => 'Tarjeta',
    PaymentMethod.ath => 'ATH Móvil',
    PaymentMethod.prueba => 'Pago de prueba',
    PaymentMethod.ninguno => 'Sin pago por la app',
  };
}

class Booking {
  Booking({
    required this.id,
    required this.artist,
    required this.package,
    required this.eventType,
    required this.date,
    required this.time,
    required this.venue,
    required this.clientName,
    required this.notes,
    required this.total,
    this.clientType = ClientType.privado,
    this.clientEmail = '',
    this.status = BookingStatus.pendiente,
    required this.amountCharged,
    required this.payDeposit,
    required this.cardLast4,
    this.payment = PaymentStatus.retenido,
    this.paymentMethod = PaymentMethod.tarjeta,
    this.hours = 2,
    this.clientUid = '',
    this.noDeposit = false,
  });

  final String id;
  final Artist artist;
  final String package;
  final EventType eventType;
  final DateTime date;
  final TimeOfDay time;
  final String venue;
  final String clientName;
  final String notes;

  /// El servidor de pagos puede corregir el total y lo cobrado.
  double total;
  final ClientType clientType;
  final String clientEmail;

  /// Cuenta del cliente en la nube (vacío en modo demo).
  final String clientUid;
  BookingStatus status;

  /// Lo que se cobra al reservar: el depósito o el total.
  double amountCharged;
  final bool payDeposit;

  /// Paquete de restaurante: se reservó sin depósito y sin pagar por la app;
  /// el pago se arregla directo con el artista.
  final bool noDeposit;

  /// Últimos 4 dígitos de la tarjeta, o del teléfono de ATH Móvil.
  String cardLast4;
  PaymentStatus payment;
  PaymentMethod paymentMethod;

  /// Cómo pagó, para mostrarlo: "Tarjeta •••• 4242".
  String get paidWith => switch (paymentMethod) {
    PaymentMethod.tarjeta =>
      cardLast4.isEmpty ? 'Tarjeta' : 'Tarjeta •••• $cardLast4',
    PaymentMethod.ath =>
      cardLast4.isEmpty ? 'ATH Móvil' : 'ATH Móvil (tel. •••• $cardLast4)',
    PaymentMethod.prueba => 'Pago de prueba',
    PaymentMethod.ninguno => 'Sin depósito',
  };

  /// Duración del paquete reservado.
  final double hours;

  DateTime get start =>
      DateTime(date.year, date.month, date.day, time.hour, time.minute);
  DateTime get end => start.add(Duration(minutes: (hours * 60).round()));

  /// Una reserva pendiente o confirmada ocupa ese horario del artista.
  bool get blocksSchedule =>
      status == BookingStatus.pendiente || status == BookingStatus.confirmada;

  double get balance => total - amountCharged;

  /// El evento ya pasó y el artista lo había confirmado: se puede reseñar.
  bool get reviewable =>
      status == BookingStatus.confirmada && end.isBefore(DateTime.now());
}

enum ClientType { privado, restaurante, agrupacion }

extension ClientTypeInfo on ClientType {
  String get label => switch (this) {
    ClientType.privado => 'Cliente privado',
    ClientType.restaurante => 'Restaurante o negocio',
    ClientType.agrupacion => 'Agrupación o banda',
  };

  IconData get icon => switch (this) {
    ClientType.privado => Icons.person,
    ClientType.restaurante => Icons.storefront,
    ClientType.agrupacion => Icons.groups,
  };

  /// Tipos de cliente que escriben el nombre de su negocio o agrupación.
  bool get hasBusinessName => this != ClientType.privado;
}

enum UserRole { cliente, artista }

/// Cuenta de quien usa la app. En el prototipo vive en memoria; en la versión
/// real se guardará en un servidor con inicio de sesión.
class Account {
  Account({
    required this.role,
    required this.name,
    required this.email,
    required this.phone,
    this.clientType = ClientType.privado,
    this.businessName = '',
    this.address = '',
    this.town = 'Caguas',
    this.artist,
    this.password = '',
  });

  final UserRole role;
  String name;
  String email;
  String phone;
  ClientType clientType;
  String businessName;
  String address;
  String town;

  /// Página pública del artista, si la cuenta es de artista.
  final Artist? artist;

  /// Solo para el prototipo. En la versión real la contraseña la maneja el
  /// servicio de inicio de sesión y nunca se guarda en la app.
  final String password;

  /// Nombre que ve el artista en una solicitud.
  String get displayName =>
      clientType.hasBusinessName && businessName.isNotEmpty
      ? businessName
      : name;
}

/// Aviso enviado a una persona. En la versión real sale como notificación al
/// teléfono (Firebase Cloud Messaging) y, si [byEmail], también por correo.
class AppNotification {
  AppNotification({
    required this.recipientEmail,
    required this.title,
    required this.body,
    this.byEmail = false,
    this.conversation,
    this.id,
    DateTime? sentAt,
  }) : sentAt = sentAt ?? DateTime.now();

  /// Id del aviso en la nube.
  String? id;
  final String recipientEmail;
  final String title;
  final String body;
  final bool byEmail;
  final DateTime sentAt;

  /// Chat que se abre al tocar el aviso, si es de un mensaje.
  final Conversation? conversation;
  bool read = false;
}

class ChatMessage {
  ChatMessage({required this.fromArtist, required this.text, DateTime? sentAt})
    : sentAt = sentAt ?? DateTime.now();

  final bool fromArtist;
  final String text;
  final DateTime sentAt;
}

/// Conversación entre un cliente y un artista.
class Conversation {
  Conversation({
    required this.clientEmail,
    required this.clientName,
    required this.clientType,
    required this.artist,
    this.clientUid = '',
  });

  final String clientEmail;

  /// Cuenta del cliente en la nube (vacío en modo demo).
  String clientUid;
  final String clientName;
  final ClientType clientType;
  final Artist artist;
  final List<ChatMessage> messages = [];
  int unreadByClient = 0;
  int unreadByArtist = 0;

  String get id => '${artist.id}__$clientUid';

  DateTime? get lastAt => messages.isEmpty ? null : messages.last.sentAt;
}
