import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lsb_legal_app/app/app_theme.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/controllers/translation_controller.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/guided_flow_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/result_visibility_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/widgets/app_toast_manager.dart';
import 'package:lsb_legal_app/core/presentation/session/cards_flow_launch.dart';
import 'package:lsb_legal_app/core/presentation/session/active_need_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/screens/needs_screen.dart';

/// Panel de vista previa en tiempo real.
///
/// Muestra la redacción del banco guiado a medida que la persona responde:
/// es exactamente la frase que tendrá el resultado y la que redacta la
/// Lambda con el mismo banco. Debajo, la navegación entre preguntas.
class LiveDeclarationPreviewPanel extends ConsumerStatefulWidget {
  const LiveDeclarationPreviewPanel({super.key});

  @override
  ConsumerState<LiveDeclarationPreviewPanel> createState() =>
      _LiveDeclarationPreviewPanelState();
}

class _LiveDeclarationPreviewPanelState
    extends ConsumerState<LiveDeclarationPreviewPanel> {
  static const _orange = AppTheme.brandPrimary;

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(guidedFlowProvider).session;
    final translationState = ref.watch(translationControllerProvider);
    final rules = ref.watch(guidedFlowRulesProvider);
    final previewText = ref.watch(guidedPreviewProvider);

    final canGoBack =
        session != null && rules.previousQuestion(session) != null;
    final isLastStep = session == null || rules.nextQuestion(session) == null;
    // Se puede avanzar sin responder una pregunta opcional (queda «sin
    // responder», que no es «no»); emitir exige tener algo que decir.
    final hasContent =
        session != null && (session.hasAnswers || !isLastStep);
    // Suficiencia: si ya hay algo que decir y nada obligatorio pendiente, se
    // puede terminar sin recorrer las preguntas opcionales que quedan.
    final canFinishEarly =
        session != null && !isLastStep && rules.canFinish(session);
    final isLoading = translationState.isLoading;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.lightSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, -4),
          ),
        ],
        border: Border.all(color: AppTheme.lightBorder.withValues(alpha: 0.8)),
      ),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (canFinishEarly)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  key: const Key('terminar_aqui'),
                  onPressed: isLoading
                      ? null
                      : () => _ejecutarTraduccionFinal(context, ref),
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text('Ya dije lo necesario: terminar aquí'),
                  style: TextButton.styleFrom(foregroundColor: _orange),
                ),
              ),
            if (previewText.isNotEmpty) ...[
              Semantics(
                label: 'Vista previa de la frase: $previewText',
                child: Text(
                  previewText,
                  key: const ValueKey('live-declaration-preview'),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.lightText,
                    fontSize: 14,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Row(children: [
            if (canGoBack) ...[
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: Material(
                    color: _orange,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(
                        color: AppTheme.lightBorder,
                        width: 1.5,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: isLoading
                          ? null
                          : () {
                              ref
                                  .read(guidedFlowProvider.notifier)
                                  .goPrevious();
                            },
                      child: const Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.arrow_back_rounded,
                              size: 19,
                              color: Colors.white,
                            ),
                            SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'ANTERIOR',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.0,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: SizedBox(
                height: 56,
                child: Semantics(
                  button: true,
                  enabled: !isLoading && hasContent,
                  label: isLoading
                      ? 'Traduciendo'
                      : (isLastStep ? 'Emitir declaración' : 'Continuar'),
                  excludeSemantics: true,
                  child: Material(
                    color: hasContent ? _orange : AppTheme.lightBorder,
                    elevation: hasContent ? 2 : 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(
                        color: AppTheme.lightBorder,
                        width: 1.5,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: isLoading || !hasContent
                          ? null
                          : () async {
                              final actual = session;
                              final pendiente = actual.currentQuestionId;
                              if (pendiente != null &&
                                  rules.isRequiredAndMissing(
                                      actual, pendiente)) {
                                // Sin esta respuesta la anterior no se puede
                                // redactar («Alguien escapó» exige «¿quién?»).
                                AppToastManager.showInfo(
                                  context,
                                  'Esta pregunta es necesaria. Si no lo sabes, '
                                  'elige «No sé».',
                                );
                                return;
                              }
                              if (!isLastStep) {
                                ref
                                    .read(guidedFlowProvider.notifier)
                                    .goNext();
                              } else {
                                await _ejecutarTraduccionFinal(context, ref);
                              }
                            },
                      child: Center(
                        child: isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Flexible(
                                    child: Text(
                                      isLastStep
                                          ? 'EMITIR DECLARACIÓN'
                                          : 'CONTINUAR',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.0,
                                        color: hasContent
                                            ? Colors.white
                                            : AppTheme.lightTextSub,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    isLastStep
                                        ? Icons.gavel
                                        : Icons.arrow_forward_rounded,
                                    size: 19,
                                    color: hasContent
                                        ? Colors.white
                                        : AppTheme.lightTextSub,
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            ]),
          ],
        ),
      ),
    );
  }

  /// Emite la declaración: la misma intervención que se ve en la vista
  /// previa viaja al backend, y el resultado solo acepta del servidor una
  /// redacción idéntica.
  Future<void> _ejecutarTraduccionFinal(
      BuildContext context, WidgetRef ref) async {
    final flow = ref.read(guidedFlowProvider.notifier);
    final session = ref.read(guidedFlowProvider).session;
    final rules = ref.read(guidedFlowRulesProvider);
    if (session == null) return;

    final faltan = rules.missingRequired(session);
    if (faltan.isNotEmpty) {
      final primera = faltan.first;
      flow.goTo(primera);
      AppToastManager.showInfo(
        context,
        'Falta responder: «${rules.formulationOf(session, primera)}».',
      );
      return;
    }

    final intervention = flow.intervention;
    if (intervention == null || intervention.isEmpty) return;
    final text = ref.read(guidedComposerProvider).compose(intervention);
    final glosses = rules.glossesOf(intervention);

    // El acto comunicativo se decide por ESTA intervención, no por la
    // necesidad elegida hace cinco pantallas.
    final launch = ref.read(cardsFlowLaunchProvider);
    final acto = NeedsScreen.actForIntervention(
      purpose: launch.purpose,
      need: ref.read(activeNeedProvider),
      glosses: glosses,
    );

    ref.read(resultVisibleProvider.notifier).show();

    try {
      await ref.read(translationControllerProvider.notifier).translateGuided(
            intervention: intervention,
            localText: text,
            glosses: glosses,
            speechAct: acto.wireName,
          );
    } catch (_) {}
  }
}
