import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lsb_legal_app/app/app_theme.dart';
import 'package:lsb_legal_app/core/domain/services/local_sentence_assembler.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/controllers/translation_controller.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/context_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/denuncia_robo_draft_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/result_visibility_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/semantic_zones_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/sentence_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/widgets/app_toast_manager.dart';
import 'package:lsb_legal_app/core/presentation/session/cards_flow_launch.dart';
import 'package:lsb_legal_app/core/presentation/session/active_need_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/screens/needs_screen.dart';
import 'package:lsb_legal_app/core/data/datasources/remote_translation_datasource.dart';
import 'package:lsb_legal_app/core/data/datasources/backend_capability.dart';

/// Panel Prominente de Previsualización en Tiempo Real ("Coherencia Visible").
///
/// Muestra la redacción formal en español generada instantáneamente por
/// [LocalSentenceAssembler] a medida que la persona usuaria selecciona señas
/// o configura entidades en el wizard.
/// Integra advertencias de coherencia y el botón principal de acción de 56dp.
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
    final selectedWords = ref.watch(sentenceProvider);
    final zonesState = ref.watch(semanticZonesProvider);
    final translationState = ref.watch(translationControllerProvider);
    final contextState = ref.watch(contextProvider);
    ref.watch(declarationDraftProvider);

    final draft = buildFullDeclarationDraft(ref);
    final hasContent = selectedWords.isNotEmpty ||
        !draft.location.isEmpty ||
        draft.persons.isNotEmpty ||
        draft.objects.isNotEmpty ||
        draft.facts.isNotEmpty;
    final previewText = const LocalSentenceAssembler().assembleStructured(draft);

    final isLastStep = !zonesState.hasNextQuestion;
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
            if (zonesState.canGoBack) ...[
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
                                  .read(semanticZonesProvider.notifier)
                                  .goToPreviousZone();
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
                              if (!isLastStep) {
                                final prevZone = zonesState.activeZoneId;
                                ref
                                    .read(semanticZonesProvider.notifier)
                                    .goToNextZone();
                                final newZone = ref
                                    .read(semanticZonesProvider)
                                    .activeZoneId;
                                if (prevZone == newZone) {
                                  // No hay más zonas a las que avanzar, ir a resultado final
                                  await _ejecutarTraduccionFinal(
                                      context, ref, contextState);
                                }
                              } else {
                                // Emitir y traducir declaración final
                                await _ejecutarTraduccionFinal(
                                    context, ref, contextState);
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

  Future<void> _ejecutarTraduccionFinal(
      BuildContext context, WidgetRef ref, dynamic contextState) async {
    final selectedWords = ref.read(sentenceProvider);
    final markedCards =
        ref.read(semanticZonesProvider.notifier).orderedGlossesMarked();
    final cardsForEngines =
        markedCards.isEmpty ? selectedWords : markedCards;

    // El destino lo decide el enrutador, con la necesidad y la intención
    // activas. Antes esta línea caía a 'denuncia_robo' cuando no había
    // contexto: un trámite acababa redactado como denuncia de robo.
    final launch = ref.read(cardsFlowLaunchProvider);

    // El acto comunicativo se decide por ESTA intervención, no por la
    // necesidad elegida hace cinco pantallas: dentro de Consultas también se
    // declara y se responde.
    final acto = NeedsScreen.actForIntervention(
      purpose: launch.purpose,
      need: ref.read(activeNeedProvider),
      glosses: cardsForEngines,
    );
    ref.read(declarationDraftProvider.notifier).setSpeechAct(acto.wireName);

    final ruta = routeToAssembler(
      currentContextId: contextState?.id ?? '',
      glosses: cardsForEngines,
      needId: ref.read(activeNeedProvider)?.id,
      intentId: launch.intentId,
    );
    final assemblerContext = ruta.contextId;

    // Se arma DESPUÉS de fijar el acto, para que el borrador que viaja lleve
    // el acto de esta intervención y no el de la anterior.
    final declaracion = buildFullDeclarationDraft(ref);

    // Compuerta de capacidad. Un backend anterior acepta la petición, responde
    // 200 y redacta habiendo perdido el segundo hecho: no devolver error no es
    // compatibilidad. Se avisa antes de enviar, y nunca se reduce en silencio
    // a un solo hecho.
    final perdidos = BackendCompatibility.wouldLose(
      declaracion,
      RemoteTranslationDataSourceImpl.lastKnownCapability,
    );
    if (perdidos.isNotEmpty && context.mounted) {
      AppToastManager.showInfo(
        context,
        'El servidor todavía no conserva dos acciones. Se enviará el mensaje '
        'y se redactará localmente para no perder «${perdidos.join(", ")}».',
      );
    }

    if (!ruta.isSupported && context.mounted) {
      // No se aproxima ni se calla: se dice qué falta y se sigue con lo que
      // sí se puede comunicar.
      AppToastManager.showInfo(
        context,
        ruta.missingVocabulary.isEmpty
            ? 'Este caso todavía no tiene un recorrido propio. Se redactará '
                'de forma general.'
            : 'Falta vocabulario para esto: '
                '${ruta.missingVocabulary.join(", ")}. Se redactará solo lo '
                'que sí se puede comunicar.',
      );
    }

    // Mostrar inmediatamente la pantalla de resultado con el borrador determinista
    ref.read(resultVisibleProvider.notifier).show();

    try {
      await ref.read(translationControllerProvider.notifier).translateCards(
            context: assemblerContext,
            cards: cardsForEngines,
            assemblerContext: assemblerContext,
            declaration: declaracion,
          );
    } catch (_) {}
  }
}
