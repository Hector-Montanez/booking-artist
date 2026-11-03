import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'cloud.dart';
import 'data/mock_artists.dart';
import 'models.dart';

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
    accounts.addAll([
      Account(
        role: UserRole.cliente,
        name: 'Ana Ortiz',
        email: demoClientEmail,
        phone: '787 555 0101',
        clientType: ClientType.restaurante,
        businessName: 'Restaurante El Patio',
        address: 'Calle Ruiz Belvis 10',
        password: demoPassword,
      ),
      Account(
        role: UserRole.artista,
        name: 'Sofía Rivera',
        email: demoArtistEmail,
        phone: '787 555 0202',
        artist: sofia,
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
      package: sofia.packages.first.name,
      eventType: type,
      date: day,
      time: TimeOfDay(hour: hour, minute: 0),
      venue: 'Caguas',
      clientName: client,
      clientType: clientType,
      notes: '',
      total: 194,
      amountCharged: 58,
      payDeposit: true,
      cardLast4: '1881',
      status: BookingStatus.confirmada,
      payment: PaymentStatus.cobrado,
      hours: sofia.packages.first.hours,
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
              ? c.artist == myArtistProfile
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

  /// Página del artista que tiene la sesión abierta.
  Artist get myArtistProfile =>
      account?.artist ?? artists.firstWhere((a) => a.id == 'a1');

  void signIn(Account a) {
    account = a;
    if (!accounts.contains(a)) accounts.add(a);
    if (a.artist != null && a.artist!.email.isEmpty) a.artist!.email = a.email;
    final artist = a.artist;
    if (artist != null) {
      final i = artists.indexWhere((x) => x.id == artist.id);
      if (i < 0) {
        artists.add(artist);
      } else {
        artists[i] = artist;
      }
    }
    notifyListeners();
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

  /// Reserva con pago simulado (modo demo o servidor de pagos sin configurar):
  /// se guarda y se avisa al artista enseguida.
  void addBooking(Booking b) {
    if (online) b.payment = PaymentStatus.simulado;
    bookings.insert(0, b);
    cloud?.saveBooking(b);
    notifyArtist(b);
  }

  /// Reserva con cobro real: se guarda sin pagar y el servidor la marca como
  /// pagada. Al artista se le avisa después, con [notifyArtist].
  Future<void> createUnpaidBooking(Booking b) async {
    b.payment = PaymentStatus.porPagar;
    bookings.insert(0, b);
    notifyListeners();
    await cloud!.saveBooking(b);
  }

  /// Le avisa al artista que tiene una solicitud nueva.
  void notifyArtist(Booking b) {
    final when = DateFormat.yMMMEd('es').format(b.date);
    notify(
      AppNotification(
        recipientEmail: b.artist.email,
        title: 'Nueva solicitud de reserva',
        body:
            '${b.clientName} quiere reservarte el $when en ${b.venue} '
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

  /// Pide al servidor aceptar, rechazar o cancelar. Devuelve el error o null.
  Future<String?> _decide(String action, Booking b) async {
    try {
      await cloud!.pay(action, b);
      return null;
    } on PayError catch (e) {
      return e.message;
    }
  }

  /// El artista acepta: se cobra lo retenido. Devuelve un error o null.
  Future<String?> acceptBooking(Booking b) async {
    if (online && b.payment != PaymentStatus.simulado) {
      final error = await _decide('accept', b);
      if (error != null) return error;
    } else {
      b.status = BookingStatus.confirmada;
      if (!online) b.payment = PaymentStatus.cobrado;
      cloud?.saveBooking(b);
    }
    _notifyClient(
      b,
      '${b.artist.name} aceptó tu reserva',
      'Tu reserva quedó confirmada. Se cobró el pago retenido.',
    );
    return null;
  }

  /// El artista rechaza: se libera la retención (tarjeta) o se reembolsa
  /// (ATH Móvil). Devuelve un error o null.
  Future<String?> rejectBooking(Booking b) async {
    if (online && b.payment != PaymentStatus.simulado) {
      final error = await _decide('reject', b);
      if (error != null) return error;
    } else {
      b.status = BookingStatus.rechazada;
      if (!online) b.payment = PaymentStatus.liberado;
      cloud?.saveBooking(b);
    }
    _notifyClient(
      b,
      '${b.artist.name} no puede tomar tu reserva',
      b.payment == PaymentStatus.reembolsado
          ? 'Te devolvimos el pago por ATH Móvil. Puedes buscar otro artista '
                'para esa fecha.'
          : 'No se cobró nada. Puedes buscar otro artista para esa fecha.',
    );
    return null;
  }

  /// El cliente cancela antes de que el artista responda.
  Future<String?> cancelBooking(Booking b) async {
    if (online && b.payment != PaymentStatus.simulado) {
      final error = await _decide('cancel', b);
      if (error != null) return error;
    } else {
      b.status = BookingStatus.cancelada;
      if (!online) b.payment = PaymentStatus.liberado;
      cloud?.saveBooking(b);
    }
    notifyListeners();
    return null;
  }

  void savePackage(Artist a, PricePackage p, {PricePackage? replacing}) {
    if (replacing != null) {
      a.packages[a.packages.indexOf(replacing)] = p;
    } else {
      a.packages.add(p);
    }
    cloud?.saveArtist(a);
    notifyListeners();
  }

  void removePackage(Artist a, PricePackage p) {
    a.packages.remove(p);
    cloud?.saveArtist(a);
    notifyListeners();
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
