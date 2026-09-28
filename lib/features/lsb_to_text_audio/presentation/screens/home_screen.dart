import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lsb_legal_app/core/presentation/widgets/motion.dart';
import 'package:lsb_legal_app/app/app_theme.dart';
import 'package:lsb_legal_app/app/navigation_provider.dart';
import 'package:lsb_legal_app/core/di/injection.dart';
import 'package:lsb_legal_app/core/presentation/session/cards_flow_launch.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/cards_flow_session.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/context_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/widgets/context_selection_widget.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/widgets/live_declaration_preview_panel.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/widgets/node_flow_canvas.dart';

/// Pantalla Principal de Creación de Declaraciones y Denuncias en LSB.
///
/// Integra armónicamente:
/// - AppBar accesible con selector de contexto.
/// - Barra de progreso visual por hitos (GuidedWizardStepper).
/// - Lienzo interactivo (NodeFlowCanvas con Hero Question y Fichas de Entidad).
/// - Panel persistente de previsualización formal en vivo (LiveDeclarationPreviewPanel).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contextState = ref.watch(contextProvider);

    // «Selecciona el contexto» ya pregunta qué necesitas hacer (su propio
    // subtítulo lo dice): un paso previo idéntico solo repetía la pregunta.
    return Scaffold(
      backgroundColor: AppTheme.lightBg,
      appBar: _buildAppBar(context, ref, contextState),
      body: SafeArea(
        // Entrar a una sección, o volver, aparece como una burbuja en vez de
        // cambiar de golpe.
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 320),
          transitionBuilder: bubbleSwitcherTransition,
          child: KeyedSubtree(
            key: ValueKey(contextState?.id ?? 'seleccion'),
            child: contextState == null
                ? const ContextSelectionWidget()
                : _buildUnifiedFlow(context, ref, contextState),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    WidgetRef ref,
    dynamic contextState,
  ) {
    final sirveConversacion = ref
        .watch(cardsFlowLaunchProvider)
        .purpose
        .servesConversation;
    final enSeleccionGlosas = contextState != null;
    // Dentro de una familia (Denuncias, Trámites) se vuelve con su «Volver»:
    // la flecha de arriba solo está en la primera pantalla.
    final enFamilia =
        !enSeleccionGlosas && ref.watch(openFamilyProvider) != null;

    final Widget? leadingWidget = enSeleccionGlosas
        ? IconButton(
            key: const Key('volver_a_contextos'),
            icon: const Icon(Icons.arrow_back, color: AppTheme.ink),
            tooltip: 'Volver a los contextos',
            onPressed: () => ref.read(cardsFlowSessionProvider).reset(),
          )
        : (sirveConversacion && !enFamilia
              ? IconButton(
                  icon: const Icon(Icons.arrow_back, color: AppTheme.ink),
                  tooltip: 'Volver a la conversación',
                  onPressed: () => ref
                      .read(selectedTabProvider.notifier)
                      .select(AppTabId.conversation),
                )
              : null);

    final Widget titleWidget = enSeleccionGlosas
        ? Text(
            contextState.name as String,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.lightText,
            ),
          )
        : const Text(
            'Expresión en LSB',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppTheme.ink,
              letterSpacing: -0.3,
            ),
          );

    // Con las glosas la barra se funde con la página: título centrado, sin
    // línea divisoria, para que la pregunta y las tarjetas sean lo que se ve.
    return AppBar(
      backgroundColor: enSeleccionGlosas
          ? AppTheme.lightBg
          : AppTheme.lightSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      foregroundColor: AppTheme.ink,
      centerTitle: true,
      leading: leadingWidget,
      bottom: enSeleccionGlosas
          ? null
          : PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(height: 1, color: AppTheme.lightBorder),
            ),
      title: titleWidget,
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
            inferredContextName: wasInferred
                ? contextState.name as String
                : null,
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
      label:
          'Estás empezando el mensaje. Nadie te ha preguntado nada '
          'todavía: elige qué quieres decir o preguntar.',
      excludeSemantics: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        color: AppTheme.brandPrimary.withValues(alpha: 0.08),
        child: Row(
          children: [
            const Icon(
              Icons.campaign_outlined,
              size: 15,
              color: AppTheme.brandPrimary,
            ),
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
              color: AppTheme.brandLight,
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
                      color: AppTheme.ink,
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
