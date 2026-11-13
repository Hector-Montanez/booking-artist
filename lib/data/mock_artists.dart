import 'package:flutter/material.dart';

import '../models.dart';

// Datos de ejemplo: artistas ficticios en Caguas, Puerto Rico. Los enlaces de video abren búsquedas
// públicas de YouTube del género, porque estos artistas no existen.
// En la versión real cada artista pegará los enlaces de sus propios perfiles.
// Fotos inventadas para los perfiles de ejemplo: fotos libres de Unsplash
// (Unsplash License, uso comercial gratis). Las personas en las fotos no son
// los artistas; cuando un artista real se registre subirá las suyas.
String _photo(String id) =>
    'https://images.unsplash.com/$id?auto=format&fit=crop&w=900&q=70';

String _yt(String q) =>
    'https://www.youtube.com/results?search_query=${Uri.encodeQueryComponent(q)}';

/// Artistas de ejemplo. Tienen la suscripción activa (simulada) para que
/// aparezcan en la app.
List<Artist> buildMockArtists() {
  final list = _mockArtists();
  final paid = Subscription(
    status: 'active',
    trialEnd: subscriptionLaunch,
    paidUntil: DateTime(2099),
    simulated: true,
  );
  for (final a in list) {
    a.subscription = paid;
  }
  // Sofía (cuenta de prueba del artista) está en su mes gratis.
  final sofia = list.firstWhere((a) => a.id == 'a1')
    ..subscription = null
    ..createdAt = DateTime.now();
  sofia.reviewList.addAll([
    Review(
      id: 'rev-ejemplo-1',
      artistId: 'a1',
      clientUid: '',
      clientName: 'Café Borinquen',
      rating: 5,
      text: 'Llegó temprano, sonó espectacular y a los clientes les encantó.',
      createdAt: DateTime.now().subtract(const Duration(days: 12)),
    ),
    Review(
      id: 'rev-ejemplo-2',
      artistId: 'a1',
      clientUid: '',
      clientName: 'Boda Rodríguez-Colón',
      rating: 4,
      text: 'Muy bonita la ceremonia. El sonido tardó un poco en montarse.',
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
    ),
  ]);
  return list;
}

List<Artist> _mockArtists() => [
  // Artista real: perfil de prueba armado con su Instagram público.
  // Mostrarlo fuera de una demo privada requiere su permiso.
  Artist(
    id: 'r1',
    name: 'Kimy-K Acústico',
    category: ArtistCategory.solista,
    genres: ['Acústico'],
    bio: 'Música acústica en vivo. Toca sus publicaciones para verlas.',
    zone: 'Caguas',
    distanceKm: 2.0,
    rating: 5.0,
    reviews: 0,
    color: const Color(0xFF3949AB),
    demoNote:
        'Perfil de prueba sin afiliación con el artista. '
        'Precios, distancia y valoración son de ejemplo.',
    eventTypes: {EventType.restaurante, EventType.cumpleanos, EventType.boda},
    packages: [
      PricePackage(
        name: 'Set acústico (ejemplo)',
        price: 200,
        hours: 2,
        kind: PackageKind.restaurante,
      ),
    ],
    links: [
      MediaLink(
        kind: LinkKind.instagram,
        title: '@kimykacoustic',
        url: 'https://www.instagram.com/kimykacoustic/',
      ),
      MediaLink(
        kind: LinkKind.instagram,
        title: 'Publicación en Instagram',
        url: 'https://www.instagram.com/p/Den1ynXjeqm/',
      ),
      MediaLink(
        kind: LinkKind.instagram,
        title: 'Publicación en Instagram 2',
        url: 'https://www.instagram.com/p/DYsAUyNgD-y/',
      ),
    ],
  ),
  Artist(
    id: 'a1',
    // Foto de ejemplo: Nick Karvounis / Unsplash.
    photoUrl: _photo('photo-1474959783111-a0f551bdad25'),
    name: 'Sofía Rivera',
    category: ArtistCategory.solista,
    instruments: ['Cantante', 'Guitarrista'],
    genres: ['Bolero', 'Baladas', 'Jazz'],
    bio:
        'Cantante y guitarrista con 10 años de experiencia en restaurantes y '
        'bodas. Repertorio romántico en español e inglés.',
    zone: 'Caguas Pueblo',
    distanceKm: 1.8,
    rating: 4.9,
    reviews: 87,
    color: const Color(0xFF8E24AA),
    verified: true,
    eventTypes: {EventType.restaurante, EventType.boda, EventType.cumpleanos},
    packages: [
      PricePackage(
        name: 'Cena acústica',
        price: 180,
        hours: 2,
        description: 'Voz y guitarra.',
        kind: PackageKind.restaurante,
      ),
      PricePackage(
        name: 'Ceremonia de boda',
        price: 350,
        hours: 1.5,
        description: 'Entrada, ceremonia y salida. Incluye sonido.',
      ),
    ],
    links: [
      MediaLink(
        kind: LinkKind.youtube,
        title: 'Bolero en vivo',
        url: _yt('bolero en vivo guitarra'),
      ),
      MediaLink(
        kind: LinkKind.instagram,
        title: '@sofiarivera.music',
        url: 'https://www.instagram.com/',
      ),
    ],
  ),
  Artist(
    id: 'a2',
    // Foto de ejemplo: Fábio Alves / Unsplash.
    photoUrl: _photo('photo-1557787824-93666b9f6093'),
    name: 'DJ Nova',
    category: ArtistCategory.dj,
    genres: ['Reggaetón', 'House', 'Pop'],
    bio:
        'DJ para bodas y fiestas privadas. Equipo de sonido e iluminación '
        'propio. Mezclas a la medida de tu público.',
    zone: 'Bairoa',
    distanceKm: 3.4,
    rating: 4.8,
    reviews: 142,
    color: const Color(0xFF1E88E5),
    verified: true,
    eventTypes: {EventType.boda, EventType.cumpleanos, EventType.actividad},
    packages: [
      PricePackage(
        name: 'Fiesta 4 horas',
        price: 400,
        hours: 4,
        description: 'Sonido para 100 personas.',
      ),
      PricePackage(
        name: 'Boda completa',
        price: 750,
        hours: 6,
        description: 'Ceremonia, cóctel y fiesta. Luces incluidas.',
      ),
    ],
    links: [
      MediaLink(
        kind: LinkKind.youtube,
        title: 'Set de boda',
        url: _yt('dj set boda reggaeton'),
      ),
      MediaLink(
        kind: LinkKind.tiktok,
        title: '@djnova',
        url: 'https://www.tiktok.com/',
      ),
      MediaLink(
        kind: LinkKind.spotify,
        title: 'Playlists',
        url: 'https://open.spotify.com/',
      ),
    ],
  ),
  Artist(
    id: 'a3',
    // Foto de ejemplo: Diego Costa / Unsplash.
    photoUrl: _photo('photo-1786027298157-0ff8a8d7f2df'),
    name: 'Los Del Barrio',
    category: ArtistCategory.agrupacion,
    genres: ['Salsa', 'Plena', 'Bomba'],
    bio:
        'Orquesta de 7 músicos. Salsa, plena y bomba para bodas, '
        'aniversarios y eventos corporativos.',
    zone: 'Río Cañas',
    distanceKm: 5.2,
    rating: 4.7,
    reviews: 64,
    color: const Color(0xFFE65100),
    eventTypes: {EventType.boda, EventType.actividad, EventType.cumpleanos},
    packages: [
      PricePackage(
        name: 'Show 2 sets',
        price: 1200,
        hours: 2,
        description: '2 sets de 45 minutos.',
      ),
      PricePackage(
        name: 'Evento completo',
        price: 1900,
        hours: 4,
        description: '4 sets, sonido incluido.',
      ),
    ],
    links: [
      MediaLink(
        kind: LinkKind.youtube,
        title: 'Salsa en vivo',
        url: _yt('orquesta salsa plena en vivo puerto rico'),
      ),
      MediaLink(
        kind: LinkKind.facebook,
        title: 'Página oficial',
        url: 'https://www.facebook.com/',
      ),
    ],
  ),
  Artist(
    id: 'a4',
    // Foto de ejemplo: Alex Zamora / Unsplash.
    photoUrl: _photo('photo-1541804627596-3b5b9ef58c93'),
    name: 'Mateo Cruz Trío',
    category: ArtistCategory.agrupacion,
    genres: ['Jazz', 'Bossa nova', 'Lounge'],
    bio: 'Trío de piano, contrabajo y batería. Ideal para cenas, cócteles y galerías.',
    zone: 'Turabo Gardens',
    distanceKm: 2.6,
    rating: 4.9,
    reviews: 39,
    color: const Color(0xFF00897B),
    verified: true,
    eventTypes: {EventType.restaurante, EventType.actividad, EventType.boda},
    packages: [
      PricePackage(
        name: 'Cena en restaurante',
        price: 380,
        hours: 2,
        kind: PackageKind.restaurante,
      ),
      PricePackage(name: 'Cóctel', price: 450, hours: 2),
      PricePackage(name: 'Cena + cóctel', price: 700, hours: 3.5),
    ],
    links: [
      MediaLink(
        kind: LinkKind.youtube,
        title: 'Jazz lounge',
        url: _yt('jazz trio lounge live'),
      ),
      MediaLink(
        kind: LinkKind.web,
        title: 'Sitio web',
        url: 'https://example.com/',
      ),
    ],
  ),
  Artist(
    id: 'a5',
    // Foto de ejemplo: Richie Lugo / Unsplash.
    photoUrl: _photo('photo-1483744463508-8680c28a0bbf'),
    name: 'Valeria Luna',
    category: ArtistCategory.solista,
    instruments: ['Cantante', 'Tecladista'],
    genres: ['Pop', 'Acústico', 'Infantil'],
    bio: 'Cantante para cumpleaños y fiestas familiares. Repertorio pop y canciones infantiles.',
    zone: 'Villa del Rey',
    distanceKm: 7.9,
    rating: 4.6,
    reviews: 22,
    color: const Color(0xFFD81B60),
    eventTypes: {EventType.cumpleanos, EventType.restaurante},
    packages: [
      PricePackage(name: 'Cumpleaños infantil', price: 150, hours: 1),
      PricePackage(
        name: 'Show acústico',
        price: 220,
        hours: 2,
        kind: PackageKind.restaurante,
      ),
    ],
    links: [
      MediaLink(
        kind: LinkKind.youtube,
        title: 'Pop acústico',
        url: _yt('pop acustico en vivo cover'),
      ),
      MediaLink(
        kind: LinkKind.instagram,
        title: '@valerialuna',
        url: 'https://www.instagram.com/',
      ),
    ],
  ),
  Artist(
    id: 'a6',
    // Foto de ejemplo: Krys Amon / Unsplash.
    photoUrl: _photo('photo-1544785349-c4a5301826fd'),
    name: 'DJ Ritmo Latino',
    category: ArtistCategory.dj,
    genres: ['Salsa', 'Reggaetón', 'Clásicos'],
    bio: 'Música latina y clásicos boricuas para bodas, quinceañeros y cumpleaños.',
    zone: 'San Antonio',
    distanceKm: 11.3,
    rating: 4.5,
    reviews: 51,
    color: const Color(0xFF6D4C41),
    eventTypes: {EventType.cumpleanos, EventType.boda, EventType.actividad},
    packages: [
      PricePackage(name: 'Fiesta 3 horas', price: 280, hours: 3),
      PricePackage(name: 'Fiesta 5 horas', price: 420, hours: 5),
    ],
    links: [
      MediaLink(
        kind: LinkKind.youtube,
        title: 'Mix latino',
        url: _yt('mix salsa clasicos puerto rico dj'),
      ),
    ],
  ),
  Artist(
    id: 'i1',
    // Foto de ejemplo: Wanyoike Mbugua / Unsplash.
    photoUrl: _photo('photo-1522168709594-942fcde3d332'),
    name: 'Ángel "Bongó" Pérez',
    category: ArtistCategory.musicoIndependiente,
    instruments: ['Bongosero', 'Conguero', 'Percusionista'],
    genres: ['Salsa', 'Bolero', 'Plena'],
    bio:
        'Percusionista con 15 años tocando en orquestas de salsa. '
        'Disponible para sustituciones, grabaciones y tríos.',
    zone: 'Bairoa',
    distanceKm: 3.1,
    rating: 4.9,
    reviews: 28,
    color: const Color(0xFFBF360C),
    eventTypes: {
      EventType.conAgrupacion,
      EventType.restaurante,
      EventType.boda,
    },
    depositPercent: 20,
    packages: [
      PricePackage(name: 'Toque con agrupación', price: 120, hours: 3),
      PricePackage(name: 'Ensayo', price: 40, hours: 2),
    ],
    links: [
      MediaLink(
        kind: LinkKind.youtube,
        title: 'Solo de bongó',
        url: _yt('solo de bongo salsa en vivo'),
      ),
    ],
  ),
  Artist(
    id: 'i2',
    // Foto de ejemplo: DM David / Unsplash.
    photoUrl: _photo('photo-1698158360685-db3f94818c4a'),
    name: 'Carla Méndez',
    category: ArtistCategory.musicoIndependiente,
    instruments: ['Bajista'],
    genres: ['Salsa', 'Pop', 'Jazz'],
    bio: 'Bajista eléctrica y acústica. Lee partitura y cifrado.',
    zone: 'Turabo Gardens',
    distanceKm: 2.9,
    rating: 4.8,
    reviews: 17,
    color: const Color(0xFF00695C),
    eventTypes: {EventType.conAgrupacion, EventType.boda},
    depositPercent: 20,
    packages: [
      PricePackage(name: 'Toque con agrupación', price: 110, hours: 3),
      PricePackage(name: 'Sesión de grabación', price: 90, hours: 2),
    ],
    links: [
      MediaLink(
        kind: LinkKind.youtube,
        title: 'Línea de bajo salsa',
        url: _yt('bajo salsa tumbao en vivo'),
      ),
    ],
  ),
  Artist(
    id: 'i3',
    // Foto de ejemplo: Jacek Dylag / Unsplash.
    photoUrl: _photo('photo-1525201548942-d8732f6617a0'),
    name: 'José Luis Ortiz',
    category: ArtistCategory.musicoIndependiente,
    instruments: ['Cuatrista', 'Guitarrista'],
    genres: ['Música jíbara', 'Trova', 'Aguinaldos'],
    bio:
        'Cuatrista para parrandas, trovadores y agrupaciones típicas. '
        'Repertorio navideño completo.',
    zone: 'Río Cañas',
    distanceKm: 4.7,
    rating: 5.0,
    reviews: 9,
    color: const Color(0xFF5D4037),
    eventTypes: {
      EventType.conAgrupacion,
      EventType.actividad,
      EventType.cumpleanos,
    },
    packages: [
      PricePackage(name: 'Parranda', price: 150, hours: 3),
      PricePackage(name: 'Toque con agrupación', price: 130, hours: 3),
    ],
    links: [
      MediaLink(
        kind: LinkKind.youtube,
        title: 'Cuatro puertorriqueño',
        url: _yt('cuatro puertorriqueño en vivo'),
      ),
    ],
  ),
  Artist(
    id: 'p1',
    // Foto de ejemplo: Peter Scholten / Unsplash.
    photoUrl: _photo('photo-1599163872948-9b8979218452'),
    name: 'Payasita Chispita',
    category: ArtistCategory.payaso,
    genres: ['Show infantil', 'Globoflexia', 'Pintacaras', 'Juegos'],
    bio:
        'Show de payasos para cumpleaños y actividades familiares: juegos, '
        'concursos, figuras de globos y pintacaras. Lleva su propio sonido.',
    zone: 'Villa del Rey',
    distanceKm: 3.6,
    rating: 4.9,
    reviews: 54,
    color: const Color(0xFFE91E63),
    eventTypes: {EventType.cumpleanos, EventType.actividad},
    depositPercent: 25,
    packages: [
      PricePackage(
        name: 'Show de 1 hora',
        price: 150,
        hours: 1,
        description: 'Juegos, concursos y globos.',
      ),
      PricePackage(
        name: 'Fiesta completa',
        price: 260,
        hours: 2,
        description: 'Show, pintacaras y piñata animada.',
      ),
    ],
    links: [
      MediaLink(
        kind: LinkKind.youtube,
        title: 'Show de payasos',
        url: _yt('show de payasos cumpleaños infantil'),
      ),
    ],
  ),
];
