import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lsb_legal_app/app/app_theme.dart';
import 'package:lsb_legal_app/core/di/injection.dart';
import 'package:lsb_legal_app/core/domain/entities/institution_profile.dart';
import 'package:lsb_legal_app/core/presentation/session/cards_flow_launch.dart';

/// Las tres entradas del modo personal.
///
/// El recorrido parte de lo que la persona quiere lograr, no de la
/// institución. Elegir institución es opcional y siempre existe «No sé / aún
/// no elegí»: exigirla para narrar un hecho o pedir ayuda sería poner un
/// trámite delante de la comunicación.
///
/// Cada necesidad arranca en un sitio distinto, no solo con otro título:
/// Denuncias parte de lo sucedido, Trámites de la gestión o el documento, y
/// Consultas de lo que necesita saber. Consultas produce además una
/// **pregunta**, no una declaración.
class NeedsScreen extends ConsumerWidget {
  final void Function(NeedId need) onSelected;

  const NeedsScreen({super.key, required this.onSelected});

  static const _iconos = {
    NeedId.complaints: Icons.report_outlined,
    NeedId.procedures: Icons.description_outlined,
    NeedId.inquiries: Icons.help_outline,
  };

  /// Qué acto comunicativo produce cada necesidad.
  ///
  /// Consultas pregunta. El propósito puede ser independiente y el acto ser
  /// una pregunta: son dimensiones distintas.
  static CommunicativeAct actFor(NeedId need) => switch (need) {
        NeedId.inquiries => CommunicativeAct.question,
        NeedId.complaints => CommunicativeAct.statement,
        NeedId.procedures => CommunicativeAct.statement,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogo = ref.watch(businessCatalogProvider).asData?.value;
    final necesidades = catalogo?.needs ?? const <NeedDefinition>[];

    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '¿Qué necesitas hacer?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.lightText,
                  ),
                ),
                const SizedBox(height: 22),
                if (necesidades.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else
                  for (final n in necesidades) ...[
                    _NeedCard(
                      key: Key('necesidad_${n.id.id}'),
                      icon: _iconos[n.id] ?? Icons.chat_bubble_outline,
                      label: n.label,
                      description: n.description,
                      startingPoint: n.startingPoint,
                      onTap: () => onSelected(n.id),
                    ),
                    const SizedBox(height: 14),
                  ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NeedCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final String startingPoint;
  final VoidCallback onTap;

  const _NeedCard({
    super.key,
    required this.icon,
    required this.label,
    required this.description,
    required this.startingPoint,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label. $description. Empieza por $startingPoint.',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          decoration: BoxDecoration(
            color: AppTheme.lightSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.lightBorder),
          ),
          child: Row(
            children: [
              // Icono y texto: el color por sí solo no distingue las tres.
              Icon(icon, size: 30, color: AppTheme.brandPrimary),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.lightText,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 13,
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
