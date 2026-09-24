import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lsb_legal_app/app/app_theme.dart';
import 'package:lsb_legal_app/core/domain/entities/declaration_draft.dart';
import 'package:lsb_legal_app/core/domain/services/local_sentence_assembler.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/controllers/translation_controller.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/context_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/denuncia_robo_draft_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/result_visibility_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/semantic_zones_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/sentence_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/widgets/app_toast_manager.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/widgets/card_grid.dart'
    show expandedAnswersProvider;
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
  static const _assembler = LocalSentenceAssembler();
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    final selectedWords = ref.watch(sentenceProvider);
    final zonesState = ref.watch(semanticZonesProvider);
    final translationState = ref.watch(translationControllerProvider);
    final contextState = ref.watch(contextProvider);
    // Este `watch` no se usa por su valor (se vuelve a leer dentro de
    // buildFullDeclarationDraft), sino para que el panel se reconstruya
    // cuando cambien persona/objeto/lugar/hecho editados directamente.
    ref.watch(declarationDraftProvider);

    // 1. Generación determinista formal en tiempo real. Usa el borrador
    // FUSIONADO (entidades + respuestas simples de zona), igual que al
    // emitir: leer solo `declarationDraftProvider` aquí dejaba fuera el
    // hecho elegido en la zona "hecho" (ROBAR/DAÑAR/ENGAÑAR no llaman a
    // ningún setter del draft, solo PERDER/ESCAPAR lo hacen vía su modal de
    // desambiguación), y sin `fact.action` el compositor nunca entraba a la
    // rama que redacta el hecho ni la que arma la frase con los rasgos de
    // la persona ya descritos — ambos parecían "saltarse" en la vista previa
    // aunque si llegaban completos a la declaración final.
    final draft = buildFullDeclarationDraft(ref);
    final liveText = _assembler.assembleStructured(draft);
    final hasContent = selectedWords.isNotEmpty ||
        !draft.location.isEmpty ||
        draft.persons.isNotEmpty ||
        draft.objects.isNotEmpty ||
        draft.facts.isNotEmpty;

    final isLastStep = !zonesState.hasNextQuestion;
    final isLoading = translationState.isLoading;

    // 2. Alertas de coherencia semántica en vivo
    final warning = _detectarIncoherencia(draft);

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
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Barra de cabecera desplegable
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _orange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.auto_stories,
                      size: 16,
                      color: _orange,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'DECLARACIÓN EN CONSTRUCCIÓN (EN VIVO)',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: _orange,
                      ),
                    ),
                  ),
                  if (hasContent)
                    IconButton(
                      icon: const Icon(Icons.copy, size: 16, color: AppTheme.lightTextSub),
                      tooltip: 'Copiar texto formal',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: liveText));
                        AppToastManager.showSuccess(context, 'Texto formal copiado al portapapeles');
                      },
                    ),
                  Icon(
                    _isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                    color: AppTheme.lightTextSub,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          if (_isExpanded) ...[
            const SizedBox(height: 8),

            // Alerta visual de datos pendientes
            if (warning != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7), // Ámbar claro
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFF59E0B)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFB45309)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        warning,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF92400E),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Texto Formal en Español de Bolivia
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.lightBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.lightBorder),
              ),
              child: Text(
                hasContent ? liveText : 'Selecciona las señas o configura las entidades para construir tu declaración formal.',
                style: TextStyle(
                  fontSize: 14.5,
                  height: 1.4,
                  fontWeight: hasContent ? FontWeight.w600 : FontWeight.w400,
                  color: hasContent ? AppTheme.lightText : AppTheme.lightTextSub,
                  fontStyle: hasContent ? FontStyle.normal : FontStyle.italic,
                ),
              ),
            ),

            const SizedBox(height: 14),
          ],

          // Acciones de escape rápido estratégicas (No lo sé / Omitir)
          if (!isLastStep && zonesState.activeZone != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: isLoading
                      ? null
                      : () => _marcarNoSaber(context, ref, zonesState.activeZoneId),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppTheme.lightBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.lightBorder),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.help_outline_rounded, size: 14, color: AppTheme.lightTextSub),
                        SizedBox(width: 4),
                        Text(
                          'No sé con certeza',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.lightTextSub,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: isLoading ? null : () => _omitirPaso(context, ref),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppTheme.lightBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.lightBorder),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.skip_next_rounded, size: 14, color: AppTheme.lightTextSub),
                        SizedBox(width: 4),
                        Text(
                          'Omitir paso',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.lightTextSub,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],

          // Fila de Botones de Acción (56dp de altura mínima)
          Row(
            children: [
              if (zonesState.canGoBack) ...[
                SizedBox(
                  height: 56,
                  child: OutlinedButton.icon(
                    onPressed: isLoading
                        ? null
                        : () {
                            ref
                                .read(semanticZonesProvider.notifier)
                                .goToPreviousZone();
                          },
                    icon: const Icon(Icons.arrow_back_rounded, size: 20),
                    label: const Text(
                      'ANTERIOR',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _orange,
                      side: BorderSide(
                        color: _orange.withValues(alpha: 0.5),
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
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
                    borderRadius: BorderRadius.circular(16),
                    elevation: hasContent ? 2 : 0,
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
            ],
          ),
        ],
      ),
    );
  }

  void _marcarNoSaber(BuildContext context, WidgetRef ref, String? zoneId) {
    final notifier = ref.read(declarationDraftProvider.notifier);
    final zonesNotifier = ref.read(semanticZonesProvider.notifier);

    switch (zoneId) {
      case 'hecho':
        notifier.setLossDisambiguation(
            lossType: 'unknown', note: 'No sabe con certeza');
        break;
      case 'conocimiento':
        // No conocer a quien lo hizo afecta al hecho que se esta relatando,
        // no a todos: se marca el primero, que es el que encabeza el relato.
        final hecho = ref.read(declarationDraftProvider).primaryFact;
        if (hecho != null) {
          notifier.setFactActor(
            factId: hecho.id,
            actorRole: ActorRole.unknown,
          );
        }
        break;
      case 'testigos':
        notifier.setWitnesses(
            const WitnessInfo(existence: ConfirmationState.uncertain));
        break;
      default:
        break;
    }
    zonesNotifier.toggleAnswer('NO_SABER');
    AppToastManager.showInfo(
        context, 'Registrado: "No sé con certeza / Desconozco"');
    zonesNotifier.goToNextZone();
  }

  void _omitirPaso(BuildContext context, WidgetRef ref) {
    ref.read(expandedAnswersProvider.notifier).collapse();
    ref.read(semanticZonesProvider.notifier).goToNextZone();
    AppToastManager.showInfo(context, 'Paso omitido');
  }

  String? _detectarIncoherencia(DeclarationDraft draft) {
    if (draft.location.relation != null && draft.location.pending) {
      return '⚠️ Especifica cerca o respecto a qué lugar ocurrió el hecho.';
    }
    for (final obj in draft.objects) {
      if (obj.concept == 'PAPEL' && (obj.docType == null || obj.docType!.isEmpty)) {
        return '⚠️ Toca la ficha de documento para especificar si es C.I., denuncia o recibo.';
      }
    }
    return null;
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
