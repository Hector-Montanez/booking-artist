import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_state.dart';
import 'cloud.dart';
import 'models.dart';
import 'screens/account_screen.dart';
import 'screens/artist_calendar_screen.dart';
import 'screens/artist_panel_screen.dart';
import 'screens/edit_page_screen.dart';
import 'screens/explore_screen.dart';
import 'screens/inbox_screen.dart';
import 'screens/my_bookings_screen.dart';
import 'screens/welcome_screen.dart';
import 'theme.dart';
import 'widgets/town_field.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = AppState();
  // Con Firebase configurado, los datos se guardan en la nube.
  await Cloud.start(state);
  runApp(AppScope(state: state, child: const BookingArtistApp()));
}

class BookingArtistApp extends StatelessWidget {
  const BookingArtistApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: appStyle,
      builder: (context, style, _) => MaterialApp(
        title: 'Tarima',
        debugShowCheckedModeBanner: false,
        locale: const Locale('es'),
        supportedLocales: const [Locale('es'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: themeFor(style, Brightness.light),
        darkTheme: themeFor(style, Brightness.dark),
        // El cambio de estilo es inmediato: los tres temas usan letras
        // distintas y no se pueden mezclar en una animación.
        themeAnimationDuration: Duration.zero,
        home: const RootGate(),
      ),
    );
  }
}

/// Muestra la bienvenida si no hay sesión, o la app según el tipo de cuenta.
class RootGate extends StatelessWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context) {
    final account = AppScope.of(context).account;
    if (account == null) return const WelcomeScreen();
    return account.role == UserRole.artista
        ? const _Shell(key: ValueKey('artista'), artist: true)
        : const _Shell(key: ValueKey('cliente'), artist: false);
  }
}

class _Shell extends StatefulWidget {
  const _Shell({super.key, required this.artist});

  final bool artist;

  @override
  State<_Shell> createState() => _ShellState();
}

class _ShellState extends State<_Shell> {
  int _tab = 0;
  bool _askedTown = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Las cuentas creadas antes de pedir el pueblo lo escogen al entrar.
    final state = AppScope.of(context);
    if (!_askedTown && state.needsTown) {
      _askedTown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) askForTown(context, state, required: true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    // Lo que espera respuesta de esta persona: el artista, solicitudes sin
    // precio (de cualquiera de sus perfiles); el cliente, precios por
    // aceptar.
    final pending = widget.artist
        ? state.bookings
              .where(
                (b) =>
                    state.isMine(b.artist) &&
                    b.status == BookingStatus.pendiente &&
                    b.payment != PaymentStatus.porPagar,
              )
              .length
        : state.myClientBookings
              .where((b) => b.status == BookingStatus.cotizada)
              .length;
    final inboxCount = state.unreadMessages + state.unreadNotifications;
    final inbox = NavigationDestination(
      icon: Badge(
        isLabelVisible: inboxCount > 0,
        label: Text('$inboxCount'),
        child: const Icon(Icons.chat_bubble_outline),
      ),
      label: 'Mensajes',
    );
    final badge = Badge(
      isLabelVisible: pending > 0,
      label: Text('$pending'),
      child: const Icon(Icons.event_note),
    );

    final pages = widget.artist
        ? [
            const ArtistPanelScreen(),
            const ArtistCalendarScreen(),
            const ExploreScreen(forArtist: true),
            const InboxScreen(),
            // Al cambiar de perfil, el editor empieza de nuevo con sus datos.
            EditPageScreen(key: ValueKey(state.myArtistProfile.id)),
          ]
        : const [
            ExploreScreen(),
            MyBookingsScreen(),
            ArtistCalendarScreen(forClient: true),
            InboxScreen(),
            AccountScreen(),
          ];
    final destinations = widget.artist
        ? [
            // Mi cuenta se abre con el botón de la persona arriba a la
            // derecha del panel y de Mi página.
            NavigationDestination(icon: badge, label: 'Solicitudes'),
            const NavigationDestination(
              icon: Icon(Icons.calendar_month),
              label: 'Calendario',
            ),
            const NavigationDestination(
              icon: Icon(Icons.search),
              label: 'Explorar',
            ),
            inbox,
            NavigationDestination(
              icon: const Icon(Icons.brush),
              label: state.myProfiles.length > 1 ? 'Mis perfiles' : 'Mi página',
            ),
          ]
        : [
            const NavigationDestination(
              icon: Icon(Icons.search),
              label: 'Explorar',
            ),
            NavigationDestination(icon: badge, label: 'Reservas'),
            const NavigationDestination(
              icon: Icon(Icons.calendar_month),
              label: 'Calendario',
            ),
            inbox,
            const NavigationDestination(
              icon: Icon(Icons.person),
              label: 'Mi cuenta',
            ),
          ];

    return Scaffold(
      body: isFuturista(context)
          ? NeonBackdrop(
              child: IndexedStack(index: _tab, children: pages),
            )
          : IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: destinations,
      ),
    );
  }
}
