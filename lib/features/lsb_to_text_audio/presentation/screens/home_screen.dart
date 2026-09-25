import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lsb_legal_app/app/app_theme.dart';
import 'package:lsb_legal_app/app/navigation_provider.dart';
import 'package:lsb_legal_app/core/di/injection.dart';
import 'package:lsb_legal_app/core/domain/entities/institution_profile.dart';
import 'package:lsb_legal_app/core/presentation/session/cards_flow_launch.dart';
import 'package:lsb_legal_app/core/presentation/session/usage_mode_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/denuncia_robo_draft_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/screens/needs_screen.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/sign_images_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/cards_flow_session.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/context_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/widgets/context_selection_widget.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/widgets/live_declaration_preview_panel.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/widgets/node_flow_canvas.dart';

/// Pantalla Principal de Creación de Declaraciones y Denuncias en LSB.
///
/// Integra armónicamente:
/// - AppBar accesible con selector de contexto y alternador de imágenes.
/// - Barra de progreso visual por hitos (GuidedWizardStepper).
/// - Lienzo interactivo (NodeFlowCanvas con Hero Question y Fichas de Entidad).
/// - Panel persistente de previsualización formal en vivo (LiveDeclarationPreviewPanel).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contextState = ref.watch(contextProvider);
    final launch = ref.watch(cardsFlowLaunchProvider);
    final necesidad = ref.watch(activeNeedProvider);

    // En modo personal y sin necesidad elegida, el recorrido empieza por lo
    // que la persona quiere lograr, no por el contexto semántico. El contexto
    // es vocabulario interno; la necesidad es lo que ella viene a hacer.
    final empiezaPorNecesidad = ref.watch(usageSessionProvider).isPersonal &&
        launch.purpose == CardsFlowPurpose.standaloneIntervention &&
        necesidad == null &&
        contextState == null;

    return Scaffold(
      backgroundColor: AppTheme.lightBg,
      appBar: _buildAppBar(context, ref, contextState),
      body: empiezaPorNecesidad
          ? NeedsScreen(onSelected: (need) => _elegirNecesidad(ref, need))
          : SafeArea(
              child: contextState == null
                  ? const ContextSelectionWidget()
                  : _buildUnifiedFlow(context, ref, contextState),
            ),
    );
  }

  /// Fija la necesidad y el acto comunicativo que le corresponde.
  ///
  /// Consultas produce una pregunta: el propósito sigue siendo independiente,
  /// pero el acto no es una declaración. Son dimensiones distintas y aquí se
  /// nota.
  void _elegirNecesidad(WidgetRef ref, NeedId need) {
    ref.read(activeNeedProvider.notifier).select(need);
    final act = NeedsScreen.initialActFor(need);
    ref.read(cardsFlowLaunchProvider.notifier).start(
          ref.read(cardsFlowLaunchProvider).withBusiness(
                need: need,
                intendedAct: act,
              ),
        );
    ref.read(declarationDraftProvider.notifier).setSpeechAct(act.wireName);
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    WidgetRef ref,
    dynamic contextState,
  ) {
    final sirveConversacion =
        ref.watch(cardsFlowLaunchProvider).purpose.servesConversation;

    return AppBar(
      backgroundColor: AppTheme.lightSurface,
      elevation: 0,
      leading: sirveConversacion
          ? IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              tooltip: 'Volver a la conversación',
              onPressed: () =>
                  ref.read(selectedTabProvider.notifier).select(AppTabId.conversation),
            )
          : null,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: AppTheme.lightBorder),
      ),
      title: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              'assets/logo.png',
              width: 30,
              height: 30,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'OpenSoul',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.3,
            ),
          ),
          if (contextState != null) ...[
            const SizedBox(width: 8),
            Flexible(
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => ref.read(cardsFlowSessionProvider).reset(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.brandPrimary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppTheme.brandPrimary.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        contextState.emoji as String,
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          contextState.name as String,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.keyboard_arrow_down,
                        size: 14,
                        color: Colors.white70,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
      actions: [
        Builder(builder: (_) {
          final conImagen = ref.watch(signImagesEnabledProvider);
          return IconButton(
            icon: Icon(
              conImagen ? Icons.image : Icons.image_not_supported_outlined,
              color: Colors.white,
              size: 22,
            ),
            tooltip: conImagen ? 'Ocultar imágenes' : 'Mostrar imágenes',
            onPressed: () =>
                ref.read(signImagesEnabledProvider.notifier).alternar(),
          );
        }),
      ],
    );
  }

  Widget _buildUnifiedFlow(
    BuildContext context,
    WidgetRef ref,
    dynamic contextState,
  ) {
    final launch = ref.watch(cardsFlowLaunchProvider);
    final pending = ref.watch(pendingReplyProvider);
    final wasInferred = pending?.suggestion?.contextId == contextState?.id;

    return Column(
      children: [
        if (pending != null)
          _ReplyingToStrip(
            text: pending.question,
            inferredContextName: wasInferred ? contextState.name as String : null,
          ),
        if (pending == null &&
            launch.purpose == CardsFlowPurpose.conversationInitiative)
          const _InitiativeStrip(),
        const Expanded(child: NodeFlowCanvas()),
        const LiveDeclarationPreviewPanel(),
      ],
    );
  }
}

/// Modo B: la persona sorda abre el turno.
class _InitiativeStrip extends StatelessWidget {
  const _InitiativeStrip();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Estás empezando el mensaje. Nadie te ha preguntado nada '
          'todavía: elige qué quieres decir o preguntar.',
      excludeSemantics: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        color: AppTheme.brandPrimary.withValues(alpha: 0.08),
        child: Row(
          children: [
            const Icon(Icons.campaign_outlined,
                size: 15, color: AppTheme.brandPrimary),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Empiezas tú: elige qué quieres decir o preguntar',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.lightText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReplyingToStrip extends StatelessWidget {
  final String text;
  final String? inferredContextName;

  const _ReplyingToStrip({required this.text, this.inferredContextName});

  @override
  Widget build(BuildContext context) {
    final inferred = inferredContextName;
    return Semantics(
      label: [
        'Respondiendo a: $text',
        if (inferred != null)
          'Contexto sugerido: $inferred. Usa Cambiar contexto si no corresponde.',
      ].join(' '),
      excludeSemantics: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        color: AppTheme.brandPrimary.withValues(alpha: 0.08),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.record_voice_over,
              size: 15,
              color: Colors.white70,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sin recortes: es la frase a la que se responde, y
                  // cortarla cambia lo que la persona cree estar contestando.
                  Text(
                    '«$text»',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                      color: Colors.white,
                    ),
                  ),
                  if (inferred != null)
                    Text(
                      'Sugerido: $inferred',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.lightTextSub.withValues(alpha: 0.9),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
