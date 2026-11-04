import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_state.dart';
import '../cloud.dart' show apiUri;
import '../models.dart';
import '../theme.dart';

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
          Card(
            child: SwitchListTile(
              secondary: const Icon(Icons.auto_awesome),
              title: const Text('Estilo futurista'),
              subtitle: const Text('Apágalo para ver el diseño clásico.'),
              value: appStyle.value == AppStyle.futurista,
              onChanged: (v) =>
                  appStyle.value = v ? AppStyle.futurista : AppStyle.clasico,
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: const Text('Política de privacidad'),
              trailing: const Icon(Icons.open_in_new),
              onTap: () => launchUrl(apiUri('/privacidad.html')),
            ),
          ),
          if (!state.online) ...[
            const SizedBox(height: 16),
            const Text(
              'Modo demo: la cuenta se guarda solo mientras la app está abierta.',
            ),
          ],
          const SizedBox(height: 16),
          OutlinedButton.icon(
            icon: const Icon(Icons.logout),
            label: const Text('Cerrar sesión'),
            onPressed: state.signOut,
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            icon: const Icon(Icons.delete_forever),
            label: const Text('Eliminar mi cuenta'),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => _DeleteAccountDialog(state: state),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pide la contraseña y borra la cuenta para siempre.
class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog({required this.state});
  final AppState state;

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await widget.state.deleteAccount(_password.text);
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _busy = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isArtist = widget.state.isArtist;
    return AlertDialog(
      title: const Text('Eliminar mi cuenta'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isArtist
                ? 'Se borran tu cuenta y tu página de artista. '
                      'No se puede deshacer.'
                : 'Se borra tu cuenta. No se puede deshacer.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            obscureText: true,
            enabled: !_busy,
            decoration: InputDecoration(
              labelText: 'Escribe tu contraseña',
              errorText: _error,
            ),
            onSubmitted: (_) => _delete(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed: _busy ? null : _delete,
          child: Text(_busy ? 'Borrando…' : 'Eliminar'),
        ),
      ],
    );
  }
}
