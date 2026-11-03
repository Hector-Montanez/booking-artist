import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_state.dart';
import 'cloud.dart';
import 'models.dart';
import 'screens/account_screen.dart';
import 'screens/artist_panel_screen.dart';
import 'screens/edit_page_screen.dart';
import 'screens/explore_screen.dart';
import 'screens/inbox_screen.dart';
import 'screens/my_bookings_screen.dart';
import 'screens/welcome_screen.dart';

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
    return MaterialApp(
      title: 'Booking Artist',
      debugShowCheckedModeBanner: false,
      locale: const Locale('es'),
      supportedLocales: const [Locale('es'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF6A1B9A),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xFF6A1B9A),
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const RootGate(),
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

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final pending = widget.artist
        ? state.bookings
              .where(
                (b) =>
                    b.artist == state.myArtistProfile &&
                    b.status == BookingStatus.pendiente,
              )
              .length
        : state.myClientBookings
              .where((b) => b.status == BookingStatus.pendiente)
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
        ? const [
            ArtistPanelScreen(),
            InboxScreen(),
            EditPageScreen(),
            AccountScreen(),
          ]
        : const [
            ExploreScreen(),
            MyBookingsScreen(),
            InboxScreen(),
            AccountScreen(),
          ];
    final destinations = widget.artist
        ? [
            NavigationDestination(icon: badge, label: 'Solicitudes'),
            inbox,
            const NavigationDestination(
              icon: Icon(Icons.brush),
              label: 'Mi página',
            ),
            const NavigationDestination(
              icon: Icon(Icons.person),
              label: 'Mi cuenta',
            ),
          ]
        : [
            const NavigationDestination(
              icon: Icon(Icons.search),
              label: 'Explorar',
            ),
            NavigationDestination(icon: badge, label: 'Reservas'),
            inbox,
            const NavigationDestination(
              icon: Icon(Icons.person),
              label: 'Mi cuenta',
            ),
          ];

    return Scaffold(
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: destinations,
      ),
    );
  }
}
