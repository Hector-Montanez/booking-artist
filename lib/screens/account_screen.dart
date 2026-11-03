import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final a = state.account!;
    final isArtist = a.role == UserRole.artista;

    return Scaffold(
      appBar: AppBar(title: const Text('Mi cuenta')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    isArtist ? Icons.mic_external_on : a.clientType.icon,
                  ),
                  title: Text(isArtist ? a.artist!.name : a.displayName),
                  subtitle: Text(isArtist ? 'Artista' : a.clientType.label),
                ),
                if (!isArtist && a.clientType == ClientType.restaurante)
                  ListTile(
                    leading: const Icon(Icons.person),
                    title: Text(a.name),
                    subtitle: const Text('Persona de contacto'),
                  ),
                if (a.address.isNotEmpty)
                  ListTile(
                    leading: const Icon(Icons.place),
                    title: Text('${a.address}, ${a.town}'),
                  ),
                ListTile(
                  leading: const Icon(Icons.phone),
                  title: Text(a.phone),
                ),
                ListTile(
                  leading: const Icon(Icons.email),
                  title: Text(a.email),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Prototipo: la cuenta se guarda solo mientras la app está abierta.',
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            icon: const Icon(Icons.logout),
            label: const Text('Cerrar sesión'),
            onPressed: state.signOut,
          ),
        ],
      ),
    );
  }
}
