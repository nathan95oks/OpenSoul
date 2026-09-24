import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lsb_legal_app/app/app_theme.dart';
import 'package:lsb_legal_app/core/domain/entities/session_snapshot.dart';
import 'package:lsb_legal_app/core/presentation/session/usage_mode_provider.dart';
import 'package:lsb_legal_app/features/counter/domain/counter_session.dart';

/// Lo primero que se ve al entrar: cómo se va a usar la aplicación.
///
/// Dos opciones grandes, con texto e icono. No se decide por el tamaño de la
/// pantalla ni por quién sea el dueño del teléfono: los dos modos funcionan en
/// teléfono y en tablet, y la elección es de la persona.
///
/// No se muestra ninguna conversación antes de decidir qué sesión corresponde.
class ModeSelectionScreen extends ConsumerWidget {
  const ModeSelectionScreen({super.key});

  Future<void> _elegir(WidgetRef ref, UsageMode mode) async {
    await ref.read(usageSessionProvider.notifier).choose(mode);
    if (mode == UsageMode.counter) {
      await ref.read(counterSessionProvider).startAttention();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppTheme.lightBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              // Se limita el ancho para que en tablet las tarjetas no se
              // estiren hasta perder la forma de botón.
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Image.asset('assets/logo.png', width: 64, height: 64),
                  const SizedBox(height: 20),
                  const Text(
                    '¿Cómo vas a usar OpenSoul?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.lightText,
                    ),
                  ),
                  const SizedBox(height: 28),
                  _ModeCard(
                    key: const Key('modo_personal'),
                    icon: Icons.person_outline,
                    title: 'Uso personal',
                    subtitle: 'Quiero comunicarme desde mi dispositivo',
                    onTap: () => _elegir(ref, UsageMode.personal),
                  ),
                  const SizedBox(height: 16),
                  _ModeCard(
                    key: const Key('modo_ventanilla'),
                    icon: Icons.support_agent_outlined,
                    title: 'Atención en ventanilla',
                    subtitle: 'Usaremos este dispositivo durante una atención',
                    onTap: () => _elegir(ref, UsageMode.counter),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Puedes cambiar de modo cuando quieras.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.lightTextSub,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ModeCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title. $subtitle',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
          decoration: BoxDecoration(
            color: AppTheme.lightSurface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.lightBorder),
          ),
          child: Row(
            children: [
              // Icono y texto: el color por sí solo no distingue las opciones.
              Icon(icon, size: 34, color: AppTheme.brandPrimary),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.lightText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13.5,
                        height: 1.3,
                        color: AppTheme.lightTextSub,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppTheme.lightTextSub),
            ],
          ),
        ),
      ),
    );
  }
}
