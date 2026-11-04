import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'app_state.dart';
import 'firebase_options.dart';
import 'models.dart';

/// Guarda y sincroniza los datos de la app en Firebase (Auth + Firestore).
///
/// Colecciones:
/// - users/{uid}: datos de la cuenta.
/// - artists/{uid}: página pública del artista.
/// - busy/{bookingId}: horas ocupadas, sin datos del cliente, para que
///   cualquiera vea qué horas quedan libres.
/// - bookings/{id}: reservas; las leen solo el cliente y el artista.
/// - conversations/{artistId__clientUid}: chat con sus mensajes.
/// - notifications/{id}: avisos para cada persona.
class Cloud {
  Cloud._(this.state);

  final AppState state;
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  final _private = <StreamSubscription<Object?>>[];
  Timer? _saveTimer;

  String? get uid => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> _col(String name) =>
      _db.collection(name);

  /// Conecta con Firebase si hay configuración. Devuelve null en modo demo.
  static Future<Cloud?> start(AppState state) async {
    final options = cloudOptions;
    if (options == null) return null;
    await Firebase.initializeApp(options: options);
    // Para probar en la computadora sin tocar los datos reales: ?emulador
    if (Uri.base.queryParameters.containsKey('emulador')) {
      await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
      FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
    }
    final cloud = Cloud._(state);
    state.cloud = cloud;
    cloud._listenPublic();
    unawaited(cloud.loadPayConfig());
    // Si la persona ya había entrado antes, recupera su sesión.
    if (await cloud._auth.authStateChanges().first != null) {
      try {
        await cloud._loadAccount();
      } catch (_) {
        await cloud._auth.signOut();
      }
    }
    return cloud;
  }

  // ---------- Cuentas ----------

  Future<String?> register(Account a, String password) async {
    final email = a.email.trim().toLowerCase();
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final id = cred.user!.uid;
      a.email = email;
      final artist = a.artist;
      if (artist != null) {
        artist
          ..id = id
          ..email = email;
        await _col('artists').doc(id).set(artistToMap(artist));
      }
      await _col('users').doc(id).set(accountToMap(a));
      state.signIn(a);
      _listenPrivate();
      return null;
    } on FirebaseAuthException catch (e) {
      return authError(e.code);
    } catch (_) {
      return 'No se pudo crear la cuenta. Revisa tu conexión.';
    }
  }

  Future<String?> login(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
      await _loadAccount();
      return null;
    } on FirebaseAuthException catch (e) {
      return authError(e.code);
    } catch (_) {
      return 'No se pudo entrar. Revisa tu conexión.';
    }
  }

  Future<void> signOut() async {
    _cancelPrivate();
    await _auth.signOut();
  }

  /// Borra la cuenta para siempre: la página de artista, los datos de la
  /// cuenta y el acceso. Pide la contraseña otra vez (Firebase lo exige para
  /// borrar). Devuelve un mensaje de error, o null si salió bien.
  Future<String?> deleteAccount(String password) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) return 'No hay sesión abierta.';
    try {
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: email, password: password),
      );
      final id = user.uid;
      _cancelPrivate();
      if (state.isArtist) await _col('artists').doc(id).delete();
      await _col('users').doc(id).delete();
      await user.delete();
      return null;
    } on FirebaseAuthException catch (e) {
      return authError(e.code);
    } catch (_) {
      return 'No se pudo borrar la cuenta. Revisa tu conexión.';
    }
  }

  Future<void> _loadAccount() async {
    final id = uid!;
    final doc = await _col('users').doc(id).get();
    final data = doc.data();
    if (data == null) throw StateError('Cuenta sin datos');
    Artist? artist;
    if (data['role'] == UserRole.artista.name) {
      artist = state.artists.where((a) => a.id == id).firstOrNull;
      if (artist == null) {
        final a = await _col('artists').doc(id).get();
        artist = artistFromMap(id, a.data() ?? {});
      }
    }
    state.signIn(accountFromMap(data, artist));
    _listenPrivate();
  }

  // ---------- Escuchar cambios ----------

  void _listenPublic() {
    _col('artists').snapshots().listen((snap) {
      // Artistas que borraron su cuenta.
      for (final change in snap.docChanges) {
        if (change.type == DocumentChangeType.removed) {
          state.artists.removeWhere((a) => a.id == change.doc.id);
        }
      }
      for (final doc in snap.docs) {
        final existing = state.artists.where((a) => a.id == doc.id).firstOrNull;
        if (existing == null) {
          state.artists.add(artistFromMap(doc.id, doc.data()));
        } else if (doc.id != uid) {
          // Mi propia página no se pisa: la estoy editando aquí.
          applyArtistMap(existing, doc.data());
        }
      }
      state.cloudChanged();
    }, onError: _ignore);
    _col('busy').snapshots().listen((snap) {
      for (final a in state.artists) {
        a.busy.clear();
      }
      for (final doc in snap.docs) {
        final d = doc.data();
        final a = state.artists.where((x) => x.id == d['artistId']).firstOrNull;
        a?.busy.add((_date(d['start']), _date(d['end'])));
      }
      state.cloudChanged();
    }, onError: _ignore);
  }

  void _listenPrivate() {
    _cancelPrivate();
    final id = uid;
    final email = _auth.currentUser?.email?.toLowerCase();
    if (id == null) return;
    for (final field in ['artistId', 'clientUid']) {
      _private.add(
        _col('bookings').where(field, isEqualTo: id).snapshots().listen((s) {
          for (final doc in s.docs) {
            _mergeBooking(doc.id, doc.data());
          }
          state.cloudChanged();
        }),
      );
      _private.add(
        _col('conversations')
            .where(field, isEqualTo: id)
            .snapshots()
            .listen((s) {
              for (final doc in s.docs) {
                _mergeConversation(doc.data());
              }
              state.cloudChanged();
            }),
      );
    }
    if (email != null) {
      _private.add(
        _col(
          'notifications',
        ).where('recipientEmail', isEqualTo: email).snapshots().listen((s) {
          final list =
              s.docs.map((d) => _notificationFromMap(d.id, d.data())).toList()
                ..sort((a, b) => b.sentAt.compareTo(a.sentAt));
          state.notifications
            ..clear()
            ..addAll(list);
          state.cloudChanged();
        }),
      );
    }
  }

  void _cancelPrivate() {
    for (final s in _private) {
      s.cancel();
    }
    _private.clear();
  }

  void _mergeBooking(String id, Map<String, dynamic> d) {
    final existing = state.bookings.where((b) => b.id == id).firstOrNull;
    if (existing != null) {
      _applyPayment(existing, d);
      return;
    }
    final artist = state.artists
        .where((a) => a.id == d['artistId'])
        .firstOrNull;
    if (artist == null) return;
    final start = _date(d['start']);
    state.bookings.insert(
      0,
      Booking(
        id: id,
        artist: artist,
        package: d['package'] ?? '',
        eventType: EventType.values.byName(d['eventType']),
        date: DateTime(start.year, start.month, start.day),
        time: TimeOfDay(hour: start.hour, minute: start.minute),
        hours: (d['hours'] as num).toDouble(),
        venue: d['venue'] ?? '',
        clientName: d['clientName'] ?? '',
        clientType: ClientType.values.byName(d['clientType']),
        clientEmail: d['clientEmail'] ?? '',
        clientUid: d['clientUid'] ?? '',
        notes: d['notes'] ?? '',
        total: (d['total'] as num).toDouble(),
        amountCharged: (d['amountCharged'] as num).toDouble(),
        payDeposit: d['payDeposit'] ?? true,
        cardLast4: d['cardLast4'] ?? '',
        status: BookingStatus.values.byName(d['status']),
        payment: PaymentStatus.values.byName(d['payment']),
        paymentMethod: _method(d['paymentMethod']),
      ),
    );
  }

  /// Lo que el servidor de pagos cambia en una reserva.
  static void _applyPayment(Booking b, Map<String, dynamic> d) {
    b
      ..status = BookingStatus.values.byName(d['status'] ?? b.status.name)
      ..payment = PaymentStatus.values.byName(d['payment'] ?? b.payment.name)
      ..paymentMethod = _method(d['paymentMethod'] ?? b.paymentMethod.name)
      ..cardLast4 = d['cardLast4'] ?? b.cardLast4
      ..total = (d['total'] as num?)?.toDouble() ?? b.total
      ..amountCharged =
          (d['amountCharged'] as num?)?.toDouble() ?? b.amountCharged;
  }

  static PaymentMethod _method(Object? name) =>
      PaymentMethod.values.where((m) => m.name == name).firstOrNull ??
      PaymentMethod.tarjeta;

  void _mergeConversation(Map<String, dynamic> d) {
    final artist = state.artists
        .where((a) => a.id == d['artistId'])
        .firstOrNull;
    if (artist == null) return;
    var c = state.conversations
        .where((c) => c.artist == artist && c.clientUid == d['clientUid'])
        .firstOrNull;
    if (c == null) {
      c = Conversation(
        clientEmail: d['clientEmail'] ?? '',
        clientName: d['clientName'] ?? '',
        clientType: ClientType.values.byName(d['clientType']),
        artist: artist,
        clientUid: d['clientUid'] ?? '',
      );
      state.conversations.add(c);
    }
    c.messages
      ..clear()
      ..addAll([
        for (final m in (d['messages'] as List? ?? []).cast<Map>())
          ChatMessage(
            fromArtist: m['a'] == true,
            text: m['t'] ?? '',
            sentAt: _date(m['at']),
          ),
      ]);
    c.unreadByArtist = (d['unreadByArtist'] as num?)?.toInt() ?? 0;
    c.unreadByClient = (d['unreadByClient'] as num?)?.toInt() ?? 0;
  }

  AppNotification _notificationFromMap(String id, Map<String, dynamic> d) {
    final convId = d['conversationId'] as String?;
    return AppNotification(
      id: id,
      recipientEmail: d['recipientEmail'] ?? '',
      title: d['title'] ?? '',
      body: d['body'] ?? '',
      byEmail: d['byEmail'] == true,
      sentAt: _date(d['sentAt']),
      conversation: convId == null
          ? null
          : state.conversations.where((c) => c.id == convId).firstOrNull,
    )..read = d['read'] == true;
  }

  // ---------- Guardar ----------

  /// Guarda la página del artista. Espera un momento para no escribir con
  /// cada letra que se teclea.
  void saveArtist(Artist a) {
    if (a.id != uid) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 800), () {
      _col('artists').doc(a.id).set(artistToMap(a));
    });
  }

  Future<void> saveBooking(Booking b) async {
    final saved = _col('bookings').doc(b.id).set({
      'artistId': b.artist.id,
      'artistName': b.artist.name,
      'package': b.package,
      'eventType': b.eventType.name,
      'start': b.start.millisecondsSinceEpoch,
      'hours': b.hours,
      'venue': b.venue,
      'clientName': b.clientName,
      'clientType': b.clientType.name,
      'clientEmail': b.clientEmail.toLowerCase(),
      'clientUid': b.clientUid,
      'notes': b.notes,
      'total': b.total,
      'amountCharged': b.amountCharged,
      'payDeposit': b.payDeposit,
      'cardLast4': b.cardLast4,
      'status': b.status.name,
      'payment': b.payment.name,
      'paymentMethod': b.paymentMethod.name,
    });
    final busy = _col('busy').doc(b.id);
    if (b.blocksSchedule) {
      busy.set({
        'artistId': b.artist.id,
        'clientUid': b.clientUid,
        'start': b.start.millisecondsSinceEpoch,
        'end': b.end.millisecondsSinceEpoch,
      });
    } else {
      busy.delete();
    }
    await saved;
  }

  /// Añade un mensaje al chat sin pisar los que la otra persona envíe a la
  /// vez.
  void sendMessage(Conversation c, ChatMessage m) {
    _col('conversations').doc(c.id).set({
      'artistId': c.artist.id,
      'clientUid': c.clientUid,
      'clientEmail': c.clientEmail.toLowerCase(),
      'clientName': c.clientName,
      'clientType': c.clientType.name,
      'messages': FieldValue.arrayUnion([
        {'a': m.fromArtist, 't': m.text, 'at': m.sentAt.millisecondsSinceEpoch},
      ]),
      m.fromArtist ? 'unreadByClient' : 'unreadByArtist': FieldValue.increment(
        1,
      ),
    }, SetOptions(merge: true));
  }

  void markConversationRead(Conversation c, {required bool byArtist}) {
    _col('conversations')
        .doc(c.id)
        .update({byArtist ? 'unreadByArtist' : 'unreadByClient': 0});
  }

  void saveNotification(AppNotification n) {
    final doc = _col('notifications').doc();
    n.id = doc.id;
    doc
        .set({
          'recipientEmail': n.recipientEmail.toLowerCase(),
          'senderUid': uid,
          'title': n.title,
          'body': n.body,
          'byEmail': n.byEmail,
          // Las reservas también llegan por SMS; los mensajes del chat, solo
          // por email.
          'sms': n.byEmail,
          'sentAt': n.sentAt.millisecondsSinceEpoch,
          'read': n.read,
          'conversationId': n.conversation?.id,
        })
        .then((_) => _deliver(doc.id))
        .catchError(_ignore);
  }

  /// Pide al servidor (función de Vercel en /api/notify) que envíe el aviso
  /// por SMS y email.
  Future<void> _deliver(String id) async {
    final token = await _auth.currentUser?.getIdToken();
    if (token == null) return;
    await http.post(
      apiUri('/api/notify'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'id': id}),
    );
  }

  // ---------- Pagos (función de Vercel en /api/pay) ----------

  /// Qué formas de pago tiene activas el servidor. Null si no responde.
  PayConfig? payConfig;

  Future<void> loadPayConfig() async {
    try {
      final r = await http
          .get(apiUri('/api/pay'))
          .timeout(const Duration(seconds: 8));
      if (r.statusCode == 200) {
        payConfig = PayConfig.fromMap(jsonDecode(r.body));
        state.cloudChanged();
      }
    } catch (e) {
      debugPrint('Pagos: $e');
    }
  }

  /// Llama al servidor de pagos y aplica a la reserva lo que responda.
  /// Lanza [PayError] con un mensaje para mostrar si algo sale mal.
  Future<Map<String, dynamic>> pay(
    String action,
    Booking b, [
    Map<String, Object?> extra = const {},
  ]) async {
    final token = await _auth.currentUser?.getIdToken();
    if (token == null) throw const PayError('Entra a tu cuenta otra vez');
    final http.Response r;
    try {
      r = await http
          .post(
            apiUri('/api/pay'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'action': action, 'bookingId': b.id, ...extra}),
          )
          .timeout(const Duration(seconds: 30));
    } catch (_) {
      throw const PayError('No hay conexión con el servidor de pagos');
    }
    Map<String, dynamic> d;
    try {
      d = (jsonDecode(r.body) as Map).cast<String, dynamic>();
    } catch (_) {
      d = {};
    }
    if (r.statusCode != 200) {
      throw PayError(d['error'] ?? 'Error del servidor (${r.statusCode})');
    }
    _applyPayment(b, d);
    state.cloudChanged();
    return d;
  }

  void markRead(AppNotification n) {
    if (n.id != null) _col('notifications').doc(n.id).update({'read': true});
  }
}

/// Si la base de datos no responde, la app sigue funcionando con lo que tiene.
void _ignore(Object error) => debugPrint('Firestore: $error');

/// Dirección de las funciones del servidor. En la web es la misma página; en
/// el teléfono, la app publicada en Vercel (se cambia con
/// --dart-define=API_URL=https://...).
Uri apiUri(String path) {
  const url = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://booking-artist-khaki.vercel.app',
  );
  return kIsWeb && Uri.base.scheme.startsWith('http')
      ? Uri.base.resolve(path)
      : Uri.parse(url).resolve(path);
}

class PayError implements Exception {
  const PayError(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Formas de pago activas en el servidor.
class PayConfig {
  const PayConfig({
    required this.ready,
    required this.card,
    required this.cardTest,
    required this.ath,
    required this.athMax,
  });

  factory PayConfig.fromMap(Map<String, dynamic> d) => PayConfig(
    ready: d['ready'] == true,
    card: d['card'] == true,
    cardTest: d['cardTest'] == true,
    ath: d['ath'] == true,
    athMax: (d['athMax'] as num?)?.toDouble() ?? 1500,
  );

  /// El servidor puede cobrar (tiene la cuenta de servicio de Firebase).
  final bool ready;

  /// Stripe configurado; cardTest: con llave de prueba.
  final bool card;
  final bool cardTest;

  /// ATH Business configurado.
  final bool ath;
  final double athMax;
}

DateTime _date(Object? ms) =>
    DateTime.fromMillisecondsSinceEpoch((ms as num?)?.toInt() ?? 0);

String authError(String code) => switch (code) {
  'email-already-in-use' => 'Ya existe una cuenta con ese correo',
  'invalid-email' => 'El correo no es válido',
  'weak-password' => 'La contraseña es muy débil (mínimo 6 caracteres)',
  'user-not-found' ||
  'wrong-password' ||
  'invalid-credential' => 'Correo o contraseña incorrectos',
  'too-many-requests' => 'Demasiados intentos. Espera un momento.',
  'network-request-failed' => 'Sin conexión. Revisa tu internet.',
  _ => 'No se pudo completar ($code)',
};

// ---------- Conversión a datos de Firestore ----------

Map<String, dynamic> accountToMap(Account a) => {
  'role': a.role.name,
  'name': a.name,
  'email': a.email.toLowerCase(),
  'phone': a.phone,
  'clientType': a.clientType.name,
  'businessName': a.businessName,
  'address': a.address,
  'town': a.town,
};

Account accountFromMap(Map<String, dynamic> d, Artist? artist) => Account(
  role: UserRole.values.byName(d['role']),
  name: d['name'] ?? '',
  email: d['email'] ?? '',
  phone: d['phone'] ?? '',
  clientType: ClientType.values.byName(d['clientType'] ?? 'privado'),
  businessName: d['businessName'] ?? '',
  address: d['address'] ?? '',
  town: d['town'] ?? 'Caguas',
  artist: artist,
);

/// Las fotos se guardan dentro del documento (máximo ~1 MB por documento),
/// así que la galería se recorta si no cabe. Con Firebase Storage se podrán
/// guardar sin límite.
const _photoBudget = 850000;

Map<String, dynamic> artistToMap(Artist a) {
  var used = 0;
  String? fit(Uint8List? bytes) {
    if (bytes == null) return null;
    final s = base64Encode(bytes);
    if (used + s.length > _photoBudget) return null;
    used += s.length;
    return s;
  }

  return {
    'name': a.name,
    'category': a.category.name,
    'genres': a.genres,
    'bio': a.bio,
    'zone': a.zone,
    'color': a.color.toARGB32(),
    'tagline': a.tagline,
    'instruments': a.instruments,
    'depositPercent': a.depositPercent,
    'conditions': a.conditions,
    'email': a.email.toLowerCase(),
    'bufferMinutes': a.bufferMinutes,
    'eventTypes': [for (final e in a.eventTypes) e.name],
    'packages': [
      for (final p in a.packages)
        {
          'name': p.name,
          'price': p.price,
          'hours': p.hours,
          'description': p.description,
        },
    ],
    'links': [
      for (final l in a.links)
        {'kind': l.kind.name, 'title': l.title, 'url': l.url},
    ],
    'weeklyHours': {
      for (final e in a.weeklyHours.entries)
        '${e.key}': [e.value.start, e.value.end],
    },
    'daysOff': [for (final d in a.daysOff) d.millisecondsSinceEpoch],
    'photo': fit(a.photo),
    'cover': fit(a.cover),
    'gallery': [for (final g in a.gallery) ?fit(g)],
  };
}

Artist artistFromMap(String id, Map<String, dynamic> d) {
  final a = Artist(
    id: id,
    name: d['name'] ?? '',
    category: ArtistCategory.solista,
    genres: [],
    bio: '',
    zone: d['zone'] ?? 'Caguas',
    distanceKm: 0,
    rating: 0,
    reviews: 0,
    color: const Color(0xFF6A1B9A),
    packages: [],
    links: [],
    eventTypes: {},
  );
  applyArtistMap(a, d);
  return a;
}

/// Copia los datos guardados sobre un artista que ya existe, para que las
/// reservas y chats que apuntan a él sigan funcionando.
void applyArtistMap(Artist a, Map<String, dynamic> d) {
  List<String> strings(Object? v) => (v as List? ?? []).cast<String>();
  Uint8List? bytes(Object? v) => v is String ? base64Decode(v) : null;

  a
    ..name = d['name'] ?? a.name
    ..category = ArtistCategory.values.byName(d['category'] ?? 'solista')
    ..genres = strings(d['genres'])
    ..bio = d['bio'] ?? ''
    ..color = Color((d['color'] as num?)?.toInt() ?? 0xFF6A1B9A)
    ..tagline = d['tagline'] ?? ''
    ..instruments = strings(d['instruments'])
    ..depositPercent = (d['depositPercent'] as num?)?.toInt() ?? 30
    ..conditions = d['conditions'] ?? defaultConditions
    ..email = d['email'] ?? a.email
    ..bufferMinutes = (d['bufferMinutes'] as num?)?.toInt() ?? 60
    ..eventTypes = {
      for (final e in strings(d['eventTypes'])) EventType.values.byName(e),
    }
    ..photo = bytes(d['photo'])
    ..cover = bytes(d['cover']);
  a.packages
    ..clear()
    ..addAll([
      for (final p in (d['packages'] as List? ?? []).cast<Map>())
        PricePackage(
          name: p['name'] ?? '',
          price: (p['price'] as num).toDouble(),
          hours: (p['hours'] as num).toDouble(),
          description: p['description'] ?? '',
        ),
    ]);
  a.links
    ..clear()
    ..addAll([
      for (final l in (d['links'] as List? ?? []).cast<Map>())
        MediaLink(
          kind: LinkKind.values.byName(l['kind']),
          title: l['title'] ?? '',
          url: l['url'] ?? '',
        ),
    ]);
  final hours = d['weeklyHours'] as Map?;
  if (hours != null) {
    a.weeklyHours
      ..clear()
      ..addAll({
        for (final e in hours.entries)
          int.parse('${e.key}'): DayHours(
            ((e.value as List)[0] as num).toInt(),
            ((e.value as List)[1] as num).toInt(),
          ),
      });
  }
  a.daysOff
    ..clear()
    ..addAll([for (final ms in (d['daysOff'] as List? ?? [])) _date(ms)]);
  a.gallery
    ..clear()
    ..addAll([for (final g in (d['gallery'] as List? ?? [])) ?bytes(g)]);
}
