import 'package:flutter/material.dart';

import '../app_state.dart';
import '../widgets/stage_slideshow.dart';
import 'signup_screens.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: StageSlideshow(child: _WelcomeContent()),
    );
  }
}

class _WelcomeContent extends StatelessWidget {
  const _WelcomeContent();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 48),
              Icon(
                Icons.queue_music,
                size: 72,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Booking Artist',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: const [Shadow(blurRadius: 12)],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Contrata músicos, agrupaciones, DJs y payasos en Caguas, '
                'con los precios que fija cada artista.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: Colors.white,
                  shadows: const [Shadow(blurRadius: 8)],
                ),
              ),
              const SizedBox(height: 120),
              _RoleCard(
                icon: Icons.storefront,
                title: 'Quiero contratar',
                subtitle: 'Para restaurantes, bodas, cumpleaños y actividades.',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ClientSignupScreen()),
                ),
              ),
              const SizedBox(height: 12),
              _RoleCard(
                icon: Icons.mic_external_on,
                title: 'Soy artista',
                subtitle: 'Crea tu página, sube tus fotos y fija tus precios.',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ArtistSignupScreen()),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const LoginScreen())),
                child: const Text('Ya tengo cuenta: iniciar sesión'),
              ),
              // Las cuentas de prueba solo existen en modo demo.
              if (!AppScope.of(context).online) ...[
                const SizedBox(height: 24),
                Text(
                  'Cuentas de prueba',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.storefront),
                      label: const Text('Restaurante El Patio'),
                      onPressed: () => _demo(context, AppState.demoClientEmail),
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.mic_external_on),
                      label: const Text('Artista Sofía Rivera'),
                      onPressed: () => _demo(context, AppState.demoArtistEmail),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

void _demo(BuildContext context, String email) {
  final state = AppScope.of(context);
  state.signIn(state.findAccount(email, AppState.demoPassword)!);
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: const Color(0xCC1A1424),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: scheme.primaryContainer,
                child: Icon(icon, color: scheme.onPrimaryContainer),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleLarge),
                    Text(subtitle),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
