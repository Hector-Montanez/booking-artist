import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'cloud.dart';
import 'data/mock_artists.dart';
import 'models.dart';
import 'places.dart' show matchMunicipio;
import 'theme.dart';

/// Estado en memoria del prototipo. Más adelante esto vendrá de un backend.
class AppState extends ChangeNotifier {
  AppState() {
    for (final a in artists) {
      if (a.email.isEmpty) a.email = '${a.id}@ejemplo.com';
    }
    // Cuentas de prueba para ver la app desde los dos lados.
    final sofia = artists.firstWhere((a) => a.id == 'a1')
      ..email = demoArtistEmail;
    _seedBookings(sofia);
    // Un evento que ya pasó, para probar las reseñas como Restaurante El Patio.
    final past = DateTime.now().subtract(const Duration(days: 5));
    bookings.add(
      Booking(
        id: 'seed-pasada',
        artist: sofia,
        eventType: EventType.restaurante,
        date: DateTime(past.year, past.month, past.day),
        time: const TimeOfDay(hour: 19, minute: 0),
        venue: 'Restaurante El Patio, Calle Ruiz Belvis 10',
        clientName: 'Restaurante El Patio',
        clientType: ClientType.restaurante,
        clientEmail: demoClientEmail,
        notes: '',
        total: 180,
        quotePrice: 180,
        amountCharged: 0,
        payDeposit: false,
        noDeposit: true,
        cardLast4: '',
        status: BookingStatus.confirmada,
        payment: PaymentStatus.sinPago,
        paymentMethod: PaymentMethod.ninguno,
        hours: 2,
      ),
    );
    // Una cotización que el trío de Sofía ya respondió, para probar
    // "Aceptar precio" como Restaurante El Patio.
    final trio = artists.firstWhere((a) => a.id == 'a1__2');
    final soon = DateTime.now().add(const Duration(days: 20));
    bookings.add(
      Booking(
        id: 'seed-cotizada',
        artist: trio,
        eventType: EventType.actividad,
        date: DateTime(soon.year, soon.month, soon.day),
        time: const TimeOfDay(hour: 19, minute: 0),
        venue: 'Restaurante El Patio, Calle Ruiz Belvis 10',
        clientName: 'Restaurante El Patio',
        clientType: ClientType.restaurante,
        clientEmail: demoClientEmail,
        notes: 'Aniversario del restaurante, unas 80 personas.',
        total: 350,
        quotePrice: 350,
        quoteNote: 'Incluye sonido para el patio y 3 sets de 45 minutos.',
        amountCharged: 0,
        payDeposit: false,
        noDeposit: true,
        cardLast4: '',
        status: BookingStatus.cotizada,
        payment: PaymentStatus.sinPago,
        paymentMethod: PaymentMethod.ninguno,
        hours: 3,
      ),
    );
    accounts.addAll([
      Account(
        role: UserRole.cliente,
        name: 'Ana Ortiz',
        email: demoClientEmail,
        phone: '787 555 0101',
        clientType: ClientType.restaurante,
        businessName: 'Restaurante El Patio',
        address: 'Calle Ruiz Belvis 10',
        town: 'Caguas',
        password: demoPassword,
      ),
      Account(
        role: UserRole.artista,
        name: 'Sofía Rivera',
        email: demoArtistEmail,
        phone: '787 555 0202',
        profiles: [sofia, trio],
        password: demoPassword,
      ),
    ]);
  }

  /// Eventos que Sofía ya tiene, para que se vean horas ocupadas al reservar.
  void _seedBookings(Artist sofia) {
    final today = DateTime.now();
    // Próximo día de la semana pedido (sin contar hoy).
    DateTime next(int weekday) {
      final days = (weekday - today.weekday + 7) % 7;
      return DateTime(
        today.year,
        today.month,
        today.day + (days == 0 ? 7 : days),
      );
    }

    Booking seed(
      DateTime day,
      int hour,
      String client,
      EventType type, [
      ClientType clientType = ClientType.privado,
    ]) => Booking(
      id: 'seed-${day.day}-$hour',
      artist: sofia,
      eventType: type,
      date: day,
      time: TimeOfDay(hour: hour, minute: 0),
      venue: 'Caguas',
      clientName: client,
      clientType: clientType,
      notes: '',
      total: 200,
      quotePrice: 200,
      amountCharged: 0,
      payDeposit: false,
      noDeposit: true,
      cardLast4: '',
      status: BookingStatus.confirmada,
      payment: PaymentStatus.sinPago,
      paymentMethod: PaymentMethod.ninguno,
      hours: 2,
    );
    bookings.addAll([
      seed(next(DateTime.saturday), 19, 'Boda Rodríguez-Colón', EventType.boda),
      seed(
        next(DateTime.friday),
        20,
        'Café Borinquen',
        EventType.restaurante,
        ClientType.restaurante,
      ),
    ]);
  }

  static const demoClientEmail = 'elpatio@ejemplo.com';
  static const demoArtistEmail = 'sofia@ejemplo.com';
  static const demoPassword = 'demo123';

  final List<Artist> artists = buildMockArtists();
  final List<Booking> bookings = [];
  final List<Account> accounts = [];
  final List<AppNotification> notifications = [];
  final List<Conversation> conversations = [];

  Account? account;

  /// Conexión con Firebase. Es null en modo demo (todo en memoria).
  Cloud? cloud;

  bool get online => cloud != null;

  /// Los cobros los hace el servidor (Stripe / ATH Móvil). Si es false, el
  /// pago es simulado.
  bool get serverPayments => cloud?.payConfig?.ready == true;

  /// Id de la cuenta en la nube (vacío en modo demo).
  String get uid => cloud?.uid ?? '';

  /// Llegaron datos nuevos de la nube.
  void cloudChanged() => notifyListeners();

  /// Crea la cuenta. Devuelve un mensaje de error, o null si salió bien.
  Future<String?> register(Account a, String password) async {
    if (cloud != null) return cloud!.register(a, password);
    if (emailTaken(a.email)) return 'Ya existe una cuenta con ese correo';
    a.artist?.createdAt = DateTime.now();
    signIn(a);
    return null;
  }

  /// Inicia sesión. Devuelve un mensaje de error, o null si salió bien.
  Future<String?> login(String email, String password) async {
    if (cloud != null) return cloud!.login(email, password);
    final a = findAccount(email, password);
    if (a == null) return 'Correo o contraseña incorrectos';
    signIn(a);
    return null;
  }

  bool get isArtist => account?.role == UserRole.artista;

  /// Reservas hechas por el cliente con la sesión abierta.
  List<Booking> get myClientBookings => account == null
      ? []
      : bookings
            .where(
              (b) =>
                  b.clientEmail.toLowerCase() == account!.email.toLowerCase(),
            )
            .toList();

  /// Inicio de sesión del prototipo: compara con las cuentas en memoria.
  Account? findAccount(String email, String password) {
    final e = email.trim().toLowerCase();
    for (final a in accounts) {
      if (a.email.toLowerCase() == e && a.password == password) return a;
    }
    return null;
  }

  bool emailTaken(String email) =>
      accounts.any((a) => a.email.toLowerCase() == email.trim().toLowerCase());

  // ---------- Avisos ----------

  /// Registra un aviso. En la versión real aquí se llama al servidor, que lo
  /// envía al teléfono (push) y por correo.
  void notify(AppNotification n) {
    notifications.insert(0, n);
    cloud?.saveNotification(n);
    notifyListeners();
  }

  List<AppNotification> get myNotifications => account == null
      ? []
      : notifications
            .where(
              (n) =>
                  n.recipientEmail.toLowerCase() ==
                  account!.email.toLowerCase(),
            )
            .toList();

  int get unreadNotifications => myNotifications.where((n) => !n.read).length;

  void markNotificationsRead() {
    if (unreadNotifications == 0) return;
    for (final n in myNotifications.where((n) => !n.read)) {
      n.read = true;
      cloud?.markRead(n);
    }
    notifyListeners();
  }

  // ---------- Chat ----------

  List<Conversation> get myConversations {
    final a = account;
    if (a == null) return [];
    final list = conversations
        .where(
          (c) => isArtist
              ? isMine(c.artist)
              : c.clientEmail.toLowerCase() == a.email.toLowerCase(),
        )
        .toList();
    list.sort(
      (x, y) => (y.lastAt ?? DateTime(0)).compareTo(x.lastAt ?? DateTime(0)),
    );
    return list;
  }

  int get unreadMessages => myConversations.fold(
    0,
    (sum, c) => sum + (isArtist ? c.unreadByArtist : c.unreadByClient),
  );

  /// Busca o crea la conversación entre un cliente y un artista.
  Conversation conversationWith({
    required Artist artist,
    required String clientEmail,
    required String clientName,
    required ClientType clientType,
  }) {
    for (final c in conversations) {
      if (c.artist == artist &&
          c.clientEmail.toLowerCase() == clientEmail.toLowerCase()) {
        return c;
      }
    }
    final c = Conversation(
      clientEmail: clientEmail,
      clientName: clientName,
      clientType: clientType,
      artist: artist,
      clientUid: uid,
    );
    conversations.add(c);
    return c;
  }

  void sendMessage(Conversation c, String text) {
    final fromArtist = isArtist;
    final message = ChatMessage(fromArtist: fromArtist, text: text);
    c.messages.add(message);
    cloud?.sendMessage(c, message);
    if (fromArtist) {
      c.unreadByClient++;
    } else {
      c.unreadByArtist++;
    }
    notify(
      AppNotification(
        recipientEmail: fromArtist ? c.clientEmail : c.artist.email,
        title: 'Mensaje de ${fromArtist ? c.artist.name : c.clientName}',
        body: text,
        conversation: c,
      ),
    );
  }

  void markConversationRead(Conversation c) {
    final had = isArtist ? c.unreadByArtist : c.unreadByClient;
    if (had == 0) return;
    if (isArtist) {
      c.unreadByArtist = 0;
    } else {
      c.unreadByClient = 0;
    }
    cloud?.markConversationRead(c, byArtist: isArtist);
    notifyListeners();
  }

  /// Perfil (página) del artista que está editando ahora. Una cuenta de
  /// artista puede tener varios.
  Artist get myArtistProfile {
    final mine = myProfiles;
    if (mine.isEmpty) return artists.firstWhere((a) => a.id == 'a1');
    return mine.contains(_activeProfile) ? _activeProfile! : mine.first;
  }

  Artist? _activeProfile;

  /// Todas las páginas de la cuenta de artista con la sesión abierta.
  List<Artist> get myProfiles => account?.profiles ?? const [];

  /// La página es de la cuenta con la sesión abierta.
  bool isMine(Artist a) => myProfiles.contains(a);

  /// Cambia el perfil que se edita en Mi página.
  void switchProfile(Artist a) {
    if (!isMine(a)) return;
    _activeProfile = a;
    notifyListeners();
  }

  /// Crea otro perfil para la misma cuenta (p. ej. su agrupación). Copia el
  /// pueblo, el horario, las condiciones y el WhatsApp del perfil actual; lo
  /// demás se llena en Mi página. Lo cubre la misma membresía.
  Artist createProfile({
    required String name,
    required ArtistCategory category,
    List<String> instruments = const [],
  }) {
    final base = myArtistProfile;
    final owner = base.ownerUid;
    var n = myProfiles.length + 1;
    String id() => '${owner}__$n';
    while (artists.any((a) => a.id == id())) {
      n++;
    }
    final a = Artist(
      id: id(),
      ownerUid: owner,
      name: name,
      category: category,
      instruments: category.hasInstruments ? [...instruments] : [],
      genres: [],
      bio: '',
      zone: base.zone,
      distanceKm: 0,
      rating: 0,
      reviews: 0,
      color: base.color,
      links: [],
      eventTypes: {...base.eventTypes},
      conditions: base.conditions,
      email: base.email,
      whatsapp: base.whatsapp,
      bufferMinutes: base.bufferMinutes,
      weeklyHours: {...base.weeklyHours},
      // La membresía es de la cuenta: el perfil nuevo no trae otro mes
      // gratis.
      subscription: base.subscription,
    )..createdAt = cloud == null ? base.createdAt : null;
    a.daysOff.addAll(base.daysOff);
    account!.profiles.add(a);
    artists.add(a);
    _activeProfile = a;
    cloud?.saveArtist(a, now: true);
    notifyListeners();
    return a;
  }

  /// Borra un perfil que no es el principal. Sus reservas pasadas se quedan.
  Future<String?> deleteProfile(Artist a) async {
    if (!isMine(a) || a == account?.artist) {
      return 'El perfil principal no se puede borrar.';
    }
    try {
      await cloud?.deleteProfile(a);
    } catch (_) {
      return 'No se pudo borrar el perfil. Revisa tu conexión.';
    }
    account!.profiles.remove(a);
    artists.remove(a);
    if (_activeProfile == a) _activeProfile = null;
    notifyListeners();
    return null;
  }

  void signIn(Account a) {
    account = a;
    _activeProfile = null;
    // Cada cuenta ve la app con el estilo que escogió.
    final style = AppStyle.fromName(a.theme);
    if (style != null) appStyle.value = style;
    if (!accounts.contains(a)) accounts.add(a);
    for (final artist in a.profiles) {
      if (artist.email.isEmpty) artist.email = a.email;
      final i = artists.indexWhere((x) => x.id == artist.id);
      if (i < 0) {
        artists.add(artist);
      } else {
        artists[i] = artist;
      }
    }
    notifyListeners();
  }

  /// Borra la cuenta y sus datos (lo exige Apple para publicar en el App
  /// Store). Devuelve un mensaje de error, o null si salió bien.
  Future<String?> deleteAccount(String password) async {
    final a = account;
    if (a == null) return null;
    if (cloud != null) {
      final error = await cloud!.deleteAccount(password);
      if (error != null) return error;
    } else {
      if (findAccount(a.email, password) == null) {
        return 'Contraseña incorrecta';
      }
      accounts.remove(a);
    }
    artists.removeWhere(a.profiles.contains);
    signOut();
    return null;
  }

  /// Pueblo de quien tiene la sesión abierta ('' si no lo ha escogido). El
  /// del artista es el de su página.
  String get myTown {
    final a = account;
    if (a == null) return '';
    return a.artist?.zone ?? a.town;
  }

  /// La cuenta es de antes de pedir el pueblo y todavía no lo escogió.
  bool get needsTown => account != null && matchMunicipio(myTown) == null;

  /// Guarda el pueblo en la cuenta (y en sus páginas si es artista).
  void setTown(String town) {
    final a = account;
    if (a == null) return;
    a.town = town;
    for (final artist in a.profiles) {
      artist.zone = town;
      cloud?.saveArtist(artist);
    }
    cloud?.saveTown(town);
    notifyListeners();
  }

  /// Cambia el estilo visual y lo guarda en la cuenta.
  void setStyle(AppStyle style) {
    appStyle.value = style;
    final a = account;
    if (a == null) return;
    a.theme = style.name;
    cloud?.saveTheme(style.name);
  }

  void signOut() {
    cloud?.signOut();
    if (cloud != null) {
      bookings.clear();
      conversations.clear();
      notifications.clear();
    }
    account = null;
    notifyListeners();
  }

  /// Avisa a las pantallas de que el artista cambió su página.
  void artistUpdated() {
    if (isArtist) cloud?.saveArtist(myArtistProfile);
    notifyListeners();
  }

  /// Solicitud guardada sin servidor de pagos (modo demo, o servidor sin
  /// configurar): se guarda y se avisa al artista enseguida. En la nube se
  /// marca como simulada para que las dos partes la puedan cambiar.
  void addBooking(Booking b) {
    if (online) {
      b.payment = PaymentStatus.simulado;
    } else if (b.noDeposit) {
      b.payment = PaymentStatus.sinPago;
    }
    bookings.insert(0, b);
    cloud?.saveBooking(b);
    notifyArtist(b);
  }

  /// Reserva con cobro real: se guarda sin pagar y el servidor la marca como
  /// pagada. Se usará si algún día se encienden los pagos por la app.
  Future<void> createUnpaidBooking(Booking b) async {
    b.payment = PaymentStatus.porPagar;
    bookings.insert(0, b);
    notifyListeners();
    await cloud!.saveBooking(b);
  }

  /// Solicitud sin pago con el servidor activo: se guarda y el servidor la
  /// pasa al artista sin cobrar nada.
  Future<String?> bookWithoutDeposit(Booking b) async {
    try {
      await createUnpaidBooking(b);
      await cloud!.pay('start', b, {'method': PaymentMethod.ninguno.name});
      return null;
    } on PayError catch (e) {
      unawaited(cancelBooking(b));
      return e.message;
    } catch (_) {
      return 'No se pudo guardar la solicitud. Intenta otra vez.';
    }
  }

  /// El cliente pide cotización: el artista recibe la solicitud (fecha,
  /// evento, lugar y detalles) y responde con su precio. Por la app no se
  /// paga nada. Devuelve un error o null.
  Future<String?> requestQuote(Booking b) async {
    b
      ..noDeposit = true
      ..paymentMethod = PaymentMethod.ninguno;
    if (serverPayments) {
      final error = await bookWithoutDeposit(b);
      if (error != null) return error;
      notifyArtist(b);
    } else {
      addBooking(b);
    }
    return null;
  }

  /// Le avisa al artista que tiene una solicitud nueva.
  void notifyArtist(Booking b) {
    final when = DateFormat.yMMMEd('es').format(b.date);
    notify(
      AppNotification(
        recipientEmail: b.artist.email,
        title: b.isQuote
            ? 'Nueva solicitud de cotización'
            : 'Nueva solicitud de reserva',
        body: b.isQuote
            ? '${b.clientName} quiere saber tu precio para '
                  '${b.eventType.label.toLowerCase()} el $when en ${b.venue} '
                  '(${b.artist.name}). Envíale tu precio en la app.'
            : '${b.clientName} quiere reservarte el $when en ${b.venue} '
                  '(${b.package}). Acéptala o recházala en la app.',
        byEmail: true,
      ),
    );
  }

  void _notifyClient(Booking b, String title, String body) {
    if (b.clientEmail.isEmpty) return;
    notify(
      AppNotification(
        recipientEmail: b.clientEmail,
        title: title,
        body: body,
        byEmail: true,
      ),
    );
  }

  /// Le pide al servidor un cambio de estado (aceptar, rechazar, cancelar,
  /// enviar precio…). Devuelve el error o null.
  Future<String?> _decide(
    String action,
    Booking b, [
    Map<String, Object?> extra = const {},
  ]) async {
    try {
      await cloud!.pay(action, b, extra);
      return null;
    } on PayError catch (e) {
      return e.message;
    }
  }

  /// Los cambios van por el servidor salvo en modo demo o en solicitudes
  /// simuladas.
  bool _viaServer(Booking b) => online && b.payment != PaymentStatus.simulado;

  static String _price(double v) =>
      '\$${v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2)}';

  /// El artista responde la solicitud con su precio. El cliente lo acepta
  /// para reservar la fecha. Devuelve un error o null.
  Future<String?> sendQuote(Booking b, double price, String note) async {
    if (!b.open) return 'Esta solicitud ya no está abierta.';
    if (_viaServer(b)) {
      final error = await _decide('quote', b, {'price': price, 'note': note});
      if (error != null) return error;
    } else {
      b
        ..status = BookingStatus.cotizada
        ..quotePrice = price
        ..quoteNote = note
        ..total = price;
      cloud?.saveBooking(b);
    }
    final when = DateFormat.yMMMEd('es').format(b.date);
    _notifyClient(
      b,
      '${b.artist.name} te envió su precio',
      '${_price(price)} para el $when. '
          '${note.isEmpty ? '' : '$note '}'
          'Acéptalo en la app para reservar la fecha.',
    );
    notifyListeners();
    return null;
  }

  /// Otra reserva confirmada de la misma persona (cualquiera de sus
  /// perfiles) ya ocupa esa hora.
  bool hasConflict(Booking b) {
    final owner = b.artist.ownerUid;
    final buffer = Duration(minutes: b.artist.bufferMinutes);
    bool overlaps(DateTime s, DateTime e) =>
        b.start.isBefore(e.add(buffer)) && b.end.isAfter(s.subtract(buffer));
    return bookings.any(
          (x) =>
              x != b &&
              x.artist.ownerUid == owner &&
              x.blocksSchedule &&
              overlaps(x.start, x.end),
        ) ||
        artists
            .where((a) => a.ownerUid == owner)
            .expand((a) => a.busy)
            .any((r) => overlaps(r.$1, r.$2));
  }

  /// El cliente acepta el precio: la fecha queda reservada. Devuelve un
  /// error o null.
  Future<String?> acceptQuote(Booking b) async {
    if (b.status != BookingStatus.cotizada) {
      return 'Esta cotización ya no está abierta.';
    }
    if (!_viaServer(b)) {
      if (hasConflict(b)) {
        return '${b.artist.name} ya tiene otra reserva a esa hora. '
            'Escríbele para buscar otra fecha.';
      }
      b
        ..status = BookingStatus.confirmada
        ..total = b.quotePrice ?? b.total;
      cloud?.saveBooking(b);
    } else {
      final error = await _decide('acceptQuote', b);
      if (error != null) return error;
    }
    final when = DateFormat.yMMMEd('es').format(b.date);
    notify(
      AppNotification(
        recipientEmail: b.artist.email,
        title: '${b.clientName} aceptó tu precio',
        body:
            'Quedó reservado el $when en ${b.venue} (${b.artist.name}). '
            'El pago se arregla directo con el cliente.',
        byEmail: true,
      ),
    );
    return null;
  }

  /// El artista confirma la fecha directamente (p. ej. ya acordaron el
  /// precio por WhatsApp). [price] es el precio acordado, si lo pone.
  Future<String?> acceptBooking(Booking b, {double? price}) async {
    if (_viaServer(b)) {
      final error = await _decide('accept', b, {'price': ?price});
      if (error != null) return error;
    } else {
      b.status = BookingStatus.confirmada;
      if (price != null) {
        b
          ..quotePrice = price
          ..total = price;
      }
      if (!online && !b.noDeposit) b.payment = PaymentStatus.cobrado;
      cloud?.saveBooking(b);
    }
    _notifyClient(
      b,
      '${b.artist.name} confirmó tu reserva',
      b.noDeposit
          ? 'Tu fecha quedó reservada. El pago se arregla directo con el '
                'artista.'
          : 'Tu reserva quedó confirmada. Se cobró el pago retenido.',
    );
    notifyListeners();
    return null;
  }

  /// El artista no puede: se libera lo retenido si lo hubiera. Devuelve un
  /// error o null.
  Future<String?> rejectBooking(Booking b) async {
    if (_viaServer(b)) {
      final error = await _decide('reject', b);
      if (error != null) return error;
    } else {
      b.status = BookingStatus.rechazada;
      if (!online && !b.noDeposit) b.payment = PaymentStatus.liberado;
      cloud?.saveBooking(b);
    }
    _notifyClient(
      b,
      '${b.artist.name} no está disponible',
      b.payment == PaymentStatus.reembolsado
          ? 'Te devolvimos el pago por ATH Móvil. Puedes buscar otro artista '
                'para esa fecha.'
          : 'Puedes buscar otro artista para esa fecha.',
    );
    notifyListeners();
    return null;
  }

  /// El cliente cancela su solicitud o dice que no al precio.
  Future<String?> cancelBooking(Booking b) async {
    final quoted = b.status == BookingStatus.cotizada;
    if (_viaServer(b)) {
      final error = await _decide('cancel', b);
      if (error != null) return error;
    } else {
      b.status = BookingStatus.cancelada;
      if (!online && !b.noDeposit) b.payment = PaymentStatus.liberado;
      cloud?.saveBooking(b);
    }
    if (quoted) {
      notify(
        AppNotification(
          recipientEmail: b.artist.email,
          title: '${b.clientName} no aceptó tu precio',
          body:
              'La solicitud para el '
              '${DateFormat.yMMMEd('es').format(b.date)} se cerró.',
        ),
      );
    }
    notifyListeners();
    return null;
  }

  // ---------- Reseñas ----------

  /// Reseña que el cliente dejó para esta reserva, si ya la dejó.
  Review? reviewFor(Booking b) =>
      b.artist.reviewList.where((r) => r.id == b.id).firstOrNull;

  /// El cliente con la sesión abierta puede reseñar esta reserva.
  bool canReview(Booking b) =>
      !isArtist &&
      b.reviewable &&
      b.clientEmail.toLowerCase() == account?.email.toLowerCase();

  /// Guarda o cambia la reseña de una reserva. Devuelve un error o null.
  Future<String?> saveReview(Booking b, int rating, String text) async {
    if (!canReview(b)) return 'Solo puedes reseñar eventos que ya pasaron.';
    final existing = reviewFor(b);
    final review =
        existing ??
        Review(
          id: b.id,
          artistId: b.artist.id,
          clientUid: uid,
          clientName: b.clientName,
          rating: rating,
          text: text,
        );
    final before = (review.rating, review.text);
    review
      ..rating = rating
      ..text = text;
    if (existing == null) b.artist.reviewList.insert(0, review);
    notifyListeners();
    try {
      await cloud?.saveReview(review);
    } catch (_) {
      if (existing == null) {
        b.artist.reviewList.remove(review);
      } else {
        review
          ..rating = before.$1
          ..text = before.$2;
      }
      notifyListeners();
      return 'No se pudo guardar la reseña. Revisa tu conexión.';
    }
    notify(
      AppNotification(
        recipientEmail: b.artist.email,
        title:
            '${b.clientName} te dejó $rating '
            '${rating == 1 ? 'estrella' : 'estrellas'}',
        body: text.isEmpty ? 'Mira tus reseñas en la app.' : text,
      ),
    );
    return null;
  }

  // ---------- Suscripción del artista ----------

  /// Abre el cobro de la suscripción. Devuelve la dirección de Stripe para
  /// poner la tarjeta, o null si se activó sin cobrar (demo o servidor sin
  /// Stripe). Lanza [PayError] si el servidor falla.
  Future<Uri?> startSubscription() async {
    final me = myArtistProfile;
    if (cloud == null) {
      // Modo demo: se activa sin cobrar.
      final s = me.effectiveSubscription;
      final sub = Subscription(
        status: s.inTrial ? 'trialing' : 'active',
        trialEnd: s.trialEnd,
        paidUntil: (s.inTrial ? s.trialEnd : DateTime.now()).add(
          const Duration(days: 30),
        ),
        simulated: true,
      );
      // Una membresía cubre todos los perfiles de la cuenta.
      for (final p in myProfiles.isEmpty ? [me] : myProfiles) {
        p.subscription = sub;
      }
      notifyListeners();
      return null;
    }
    final d = await cloud!.subscription('checkout');
    final url = d['url'] as String?;
    return url == null ? null : Uri.parse(url);
  }

  /// Cancela al final del mes pagado ([resume] la deja seguir).
  Future<String?> setSubscriptionCanceled(bool cancel) async {
    final me = myArtistProfile;
    if (cloud == null) {
      me.subscription?.cancelAtPeriodEnd = cancel;
      notifyListeners();
      return null;
    }
    try {
      await cloud!.subscription(cancel ? 'cancel' : 'resume');
      return null;
    } on PayError catch (e) {
      return e.message;
    }
  }

  void addLink(Artist a, MediaLink link) {
    a.links.add(link);
    cloud?.saveArtist(a);
    notifyListeners();
  }

  void removeLink(Artist a, MediaLink link) {
    a.links.remove(link);
    cloud?.saveArtist(a);
    notifyListeners();
  }
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
    : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
