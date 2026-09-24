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

  /// Acto comunicativo **de partida** de cada necesidad.
  ///
  /// Es una propuesta inicial, no una condena: elegir Consultas no convierte
  /// toda intervención en pregunta. Dentro de una consulta caben también
  /// respuestas y declaraciones —«sí, ya traje el papel»—, y el acto se
  /// recalcula por intervención en [actForIntervention].
  static CommunicativeAct initialActFor(NeedId need) => switch (need) {
        NeedId.inquiries => CommunicativeAct.question,
        NeedId.complaints => CommunicativeAct.statement,
        NeedId.procedures => CommunicativeAct.statement,
      };

  /// El acto de **esta** intervención concreta.
  ///
  /// Manda el turno: responder a alguien es responder, aunque la necesidad
  /// elegida fuera Consultas. Y dentro de una consulta se puede declarar algo
  /// si las glosas elegidas no preguntan nada.
  static CommunicativeAct actForIntervention({
    required CardsFlowPurpose purpose,
    NeedId? need,
    List<String> glosses = const [],
  }) {
    // Responder es responder, venga de donde venga el encargo.
    if (purpose == CardsFlowPurpose.conversationReply) {
      return CommunicativeAct.answer;
    }

    // Una interrogativa explícita hace pregunta cualquier intervención.
    const interrogativas = {
      'DONDE', 'QUIEN', 'QUE', 'CUANDO', 'COMO', 'CUAL', 'CUANTOS',
      'POR_QUE', 'PARA_QUE', 'PUEDO',
    };
    final norm = glosses.map((g) => g.toUpperCase()).toSet();
    if (norm.any(interrogativas.contains)) return CommunicativeAct.question;

    // Pedir algo es una solicitud, no una afirmación.
    const solicitudes = {'PEDIR', 'QUERER', 'NECESITAR', 'SOLICITAR'};
    if (norm.any(solicitudes.contains)) return CommunicativeAct.request;

    // Sin señales en las glosas, manda el punto de partida de la necesidad,
    // salvo en Consultas: ahí una intervención sin interrogativa es una
    // declaración dentro de la consulta, no una pregunta forzada.
    if (need == NeedId.inquiries && norm.isNotEmpty) {
      return CommunicativeAct.statement;
    }
    return need == null
        ? CommunicativeAct.statement
        : initialActFor(need);
  }

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
