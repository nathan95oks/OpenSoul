import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lsb_legal_app/app/app_theme.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/controllers/translation_controller.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/guided_emission.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/guided_flow_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/widgets/app_toast_manager.dart';

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
  @override
  Widget build(BuildContext context) {
    final session = ref.watch(guidedFlowProvider).session;
    final translationState = ref.watch(translationControllerProvider);
    final rules = ref.watch(guidedFlowRulesProvider);

    final canGoBack =
        session != null && rules.previousQuestion(session) != null;
    final isLastStep = session == null || rules.nextQuestion(session) == null;
    // Se puede avanzar sin responder una pregunta opcional (queda «sin
    // responder», que no es «no»); emitir exige tener algo que decir.
    final hasContent = session != null && (session.hasAnswers || !isLastStep);
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
        child: Row(
          children: [
            Expanded(
              child: _NavIconButton(
                key: const Key('anterior_pregunta'),
                icon: Icons.arrow_back_rounded,
                label: 'Anterior',
                enabled: canGoBack && !isLoading,
                onTap: () => ref.read(guidedFlowProvider.notifier).goPrevious(),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _NavIconButton(
                key: const Key('terminar_aqui'),
                icon: Icons.volume_up_rounded,
                label: 'Traducir ahora',
                enabled: canFinishEarly && !isLoading,
                onTap: () => _ejecutarTraduccionFinal(context, ref),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _NavIconButton(
                key: const Key('siguiente_pregunta'),
                icon: isLastStep ? Icons.gavel : Icons.arrow_forward_rounded,
                label: isLastStep ? 'Emitir declaración' : 'Siguiente',
                enabled: !isLoading && hasContent,
                loading: isLoading,
                onTap: () async {
                  final actual = session;
                  final pendiente = actual?.currentQuestionId;
                  if (actual != null &&
                      pendiente != null &&
                      rules.isRequiredAndMissing(actual, pendiente)) {
                    // Sin esta respuesta la anterior no se puede redactar
                    // («Alguien escapó» exige «¿quién?»).
                    AppToastManager.showInfo(
                      context,
                      'Esta pregunta es necesaria. Si no lo sabes, '
                      'elige «No sé».',
                    );
                    return;
                  }
                  if (!isLastStep) {
                    ref.read(guidedFlowProvider.notifier).goNext();
                  } else {
                    await _ejecutarTraduccionFinal(context, ref);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Emite la declaración: la misma intervención que se ve en la vista
  /// previa viaja al backend, y el resultado solo acepta del servidor una
  /// redacción idéntica.
  Future<void> _ejecutarTraduccionFinal(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final outcome = await ref.read(guidedEmissionProvider).emit();
    if (!context.mounted) return;
    switch (outcome.status) {
      case GuidedEmissionStatus.missingRequired:
        AppToastManager.showInfo(
          context,
          'Falta responder: «${outcome.missingQuestion}».',
        );
      case GuidedEmissionStatus.staleConversation:
        AppToastManager.showInfo(
          context,
          'El mensaje al que respondías ya no está en el chat. '
          'Tu respuesta quedó aquí para copiarla o rehacerla.',
        );
      case GuidedEmissionStatus.nothing:
      case GuidedEmissionStatus.shownResult:
      case GuidedEmissionStatus.returnedToConversation:
        break;
    }
  }
}

/// Botón de navegación como icono puro, sin etiqueta visible.
///
/// Las tres acciones (anterior, traducir, siguiente) van al mismo nivel y
/// con el mismo tamaño que tenían los botones de texto que reemplazan, para
/// que la pregunta y las glosas ganen el espacio que antes ocupaba el texto.
class _NavIconButton extends StatelessWidget {
  static const _orange = AppTheme.brandPrimary;

  final IconData icon;
  final String label;
  final bool enabled;
  final bool loading;
  final VoidCallback onTap;

  const _NavIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final active = enabled && !loading;
    return SizedBox(
      height: 56,
      child: Semantics(
        button: true,
        enabled: active,
        label: label,
        excludeSemantics: true,
        child: Material(
          color: enabled ? _orange : AppTheme.lightBorder,
          elevation: enabled ? 2 : 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppTheme.lightBorder, width: 1.5),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: active ? onTap : null,
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Icon(
                      icon,
                      size: 22,
                      color: enabled ? Colors.white : AppTheme.lightTextSub,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
