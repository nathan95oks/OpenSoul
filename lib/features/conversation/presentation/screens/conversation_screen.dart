import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lsb_legal_app/core/domain/entities/speech_act.dart';

import 'package:lsb_legal_app/app/app_theme.dart';
import 'package:lsb_legal_app/core/di/injection.dart';
import 'package:lsb_legal_app/core/domain/entities/conversation.dart';
import 'package:lsb_legal_app/core/domain/entities/semantic_message.dart';
import 'package:lsb_legal_app/core/presentation/session/cards_flow_launch.dart';
import 'package:lsb_legal_app/core/presentation/session/usage_mode_provider.dart';
import 'package:lsb_legal_app/features/counter/domain/counter_session.dart';
import 'package:lsb_legal_app/features/audio_to_lsb/presentation/widgets/text_input_widget.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/sentence_provider.dart';
import 'package:lsb_legal_app/features/conversation/presentation/providers/conversation_provider.dart';
import 'package:lsb_legal_app/features/conversation/presentation/providers/conversation_handoff.dart';
import 'package:lsb_legal_app/features/conversation/presentation/widgets/avatar_playback_sheet.dart';
import 'package:lsb_legal_app/features/conversation/presentation/widgets/turn_bubble.dart';
import 'package:lsb_legal_app/features/conversation/presentation/widgets/quick_reply_bar.dart';
import 'package:lsb_legal_app/core/domain/entities/translation_result.dart';

class ConversationScreen extends ConsumerStatefulWidget {
  const ConversationScreen({super.key});

  @override
  ConsumerState<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends ConsumerState<ConversationScreen> {
  final ScrollController _scroll = ScrollController();
  final FocusNode _hearingFocus = FocusNode();

  /// Turnos recién llegados que todavía no hicieron su animación de entrada.
  /// Solo se anima lo que llega mientras se mira el chat: un chat restaurado
  /// aparece tal cual, sin que cada burbuja entre de nuevo.
  final Set<String> _porAnimar = {};

  @override
  void dispose() {
    _scroll.dispose();
    _hearingFocus.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _playDeafTurn(ConversationTurn turn) async {
    final audio = ref.read(audioOutputProvider);
    if (turn.outputs.hasRemoteAudio) {
      try {
        await audio.playUrl(turn.outputs.audioUrl!);
        return;
      } catch (_) {}
    }
    await audio.speak(turn.outputs.text);
  }

  /// Abre el módulo de tarjetas en modo respuesta (C) o iniciativa (B).
  ///
  /// El modo lo decide si hay un turno del oyente esperando respuesta, y se
  /// congela en el lanzamiento junto con el id y el texto exacto de ese turno.
  /// Antes esto era un único camino que miraba el estado vivo del chat, y
  /// abrir para empezar uno mismo se anunciaba —y se comportaba— como
  /// responder a lo último que quedara de la charla anterior.
  Future<void> _openCardsFlow() async {
    final handoff = ref.read(conversationHandoffProvider);
    final launch = handoff.nextDeafLaunch();

    if (!await _confirmDiscardDraft(launch)) return;
    if (!mounted) return;

    handoff.openCards(launch);
  }

  /// Un borrador a medias no se pierde en silencio al cambiar de encargo.
  ///
  /// Solo se pregunta cuando el encargo cambia de verdad: volver a la misma
  /// respuesta que se estaba armando no toca nada.
  Future<bool> _confirmDiscardDraft(CardsFlowLaunch next) async {
    final current = ref.read(cardsFlowLaunchProvider);
    final hasDraft = ref.read(sentenceProvider).isNotEmpty;
    if (!hasDraft || current.sameErrand(next)) return true;

    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tienes un mensaje a medias'),
        content: const Text(
          'Si continúas se descartará lo que estabas armando. ¿Continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Seguir con lo que tenía'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Descartar y continuar'),
          ),
        ],
      ),
    );
    return discard == true;
  }

  /// Qué se le ofrece a la persona sorda: empezar ella (B) o responder (C).
  CardsFlowPurpose _deafCardsMode(ConversationState state) =>
      state.conversation.pendingReply == null
      ? CardsFlowPurpose.conversationInitiative
      : CardsFlowPurpose.conversationReply;

  ConversationTurn? _instruccionPendiente(ConversationState state) {
    final pendiente = state.conversation.pendingReply;
    if (pendiente == null) return null;
    return pendiente.message.speechAct == SpeechAct.instruction
        ? pendiente
        : null;
  }

  Future<void> _enviarRespuestaRapida(List<String> glosses, String text) async {
    ref
        .read(conversationProvider.notifier)
        .addDeafDeclaration(
          result: TranslationResult(baseSentence: text, generatedText: text),
          glosses: glosses,
        );
    await ref.read(audioOutputProvider).speak(text);
  }

  Future<void> _handleHearingSend(
    String text, {
    MessageSource source = MessageSource.text,
  }) async {
    FocusManager.instance.primaryFocus?.unfocus();
    SystemChannels.textInput.invokeMethod('TextInput.hide');
    await ref
        .read(conversationProvider.notifier)
        .sendHearingMessage(text, source: source);
    if (!mounted) return;
    final lastTurn = ref.read(conversationProvider).conversation.lastTurn;
    if (lastTurn != null && lastTurn.message.speaker != SpeakerRole.deaf) {
      final glosses = lastTurn.outputs.animationGlosses.isNotEmpty
          ? lastTurn.outputs.animationGlosses
          : lastTurn.message.glosses;
      if (glosses.isNotEmpty || lastTurn.outputs.animationUrls.isNotEmpty) {
        AvatarPlaybackSheet.show(
          context,
          glosses: glosses,
          animationUrls: lastTurn.outputs.animationUrls,
          animationGlosses: lastTurn.outputs.animationGlosses,
        );
      }
    }
  }

  /// Cierra la atención del ciudadano actual.
  ///
  /// Se confirma porque no es reversible: se borra todo lo que dijo. Lo que
  /// no se toca es el perfil de la institución, que es del dispositivo.
  Future<void> _confirmEndAttention() async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Finalizar atención'),
        content: const Text(
          'Se borrarán los mensajes, borradores y resultados de esta '
          'atención. La configuración de la institución se conserva. '
          '¿Continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Finalizar'),
          ),
        ],
      ),
    );
    if (confirmado == true) {
      await ref.read(counterSessionProvider).endAttention();
    }
  }

  Future<void> _confirmNewConversation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nuevo chat'),
        content: const Text(
          'Se borrará el historial de este chat. ¿Continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Empezar de nuevo'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      ref.read(conversationProvider.notifier).startNew();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(conversationProvider);
    ref.watch(lexiconEntriesProvider);
    ref.listen(conversationProvider, (prev, next) {
      final antes = prev?.conversation.turns.length ?? 0;
      final ahora = next.conversation.turns.length;
      if (ahora == antes + 1 && prev?.conversation.id == next.conversation.id) {
        _porAnimar.add(next.conversation.turns.last.message.id);
      }
      if (antes < ahora) {
        _scrollToEnd();
      }
    });

    return Theme(
      data: AppTheme.darkTheme,
      child: Scaffold(
        backgroundColor: AppTheme.conversationPageBg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: AppTheme.ink,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          centerTitle: true,
          // Sin el logo: dentro de la app ya se sabe que es OpenSoul.
          title: const Text(
            'Chat',
            style: TextStyle(
              color: AppTheme.ink,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
          actions: [
            // En ventanilla el dispositivo pasa de una persona a la
            // siguiente: cerrar la atención es la acción principal, y borra
            // lo del ciudadano conservando la configuración institucional.
            if (ref.watch(usageSessionProvider).isCounter)
              TextButton.icon(
                key: const Key('finalizar_atencion'),
                icon: const Icon(Icons.logout, size: 18),
                label: const Text('Finalizar atención'),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.brandLight,
                ),
                onPressed: _confirmEndAttention,
              )
            else if (!state.conversation.isEmpty)
              IconButton(
                icon: const Icon(Icons.restart_alt),
                tooltip: 'Nuevo chat',
                onPressed: _confirmNewConversation,
              ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: AppTheme.framedSurface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: AppTheme.brandLight.withValues(alpha: 0.24),
                      width: 1.25,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.brandPrimary.withValues(alpha: 0.08),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: state.conversation.isEmpty
                        ? const _EmptyConversation(key: ValueKey('vacio'))
                        : ListView.builder(
                            key: const ValueKey('hilo'),
                            controller: _scroll,
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                            itemCount: state.conversation.turns.length,
                            itemBuilder: (context, i) {
                              final turn = state.conversation.turns[i];
                              return _EntradaMensaje(
                                key: ValueKey(turn.message.id),
                                animar: _porAnimar.remove(turn.message.id),
                                desdeLaIzquierda:
                                    turn.message.speaker == SpeakerRole.deaf,
                                child: TurnBubble(
                                  turn: turn,
                                  onPlayAudio: () => _playDeafTurn(turn),
                                  onShowAvatar: () {
                                    FocusManager.instance.primaryFocus
                                        ?.unfocus();
                                    SystemChannels.textInput.invokeMethod(
                                      'TextInput.hide',
                                    );
                                    AvatarPlaybackSheet.show(
                                      context,
                                      glosses:
                                          turn
                                              .outputs
                                              .animationGlosses
                                              .isNotEmpty
                                          ? turn.outputs.animationGlosses
                                          : turn.message.glosses,
                                      animationUrls: turn.outputs.animationUrls,
                                      animationGlosses:
                                          turn.outputs.animationGlosses,
                                      autoDismissOnFinish: false,
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                ),
              ),
              // Los avisos y las respuestas rápidas aparecen y se van
              // deslizándose, sin que el resto salte de golpe.
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                alignment: Alignment.bottomCenter,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (state.error != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _StatusChip(
                          icon: Icons.error_outline,
                          text: state.error!,
                          color: AppTheme.errorLight,
                        ),
                      ),
                    if (_instruccionPendiente(state) != null)
                      QuickReplyBar(onReply: _enviarRespuestaRapida),
                  ],
                ),
              ),
              _InputArea(
                onHearingText: _handleHearingSend,
                onHearingSpeech: (text) =>
                    _handleHearingSend(text, source: MessageSource.speech),
                onDeafCards: _openCardsFlow,
                deafCardsMode: _deafCardsMode(state),
                hearingFocus: _hearingFocus,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InputArea extends StatelessWidget {
  final void Function(String) onHearingText;
  final void Function(String) onHearingSpeech;
  final VoidCallback onDeafCards;
  final CardsFlowPurpose deafCardsMode;
  final FocusNode hearingFocus;

  const _InputArea({
    required this.onHearingText,
    required this.onHearingSpeech,
    required this.onDeafCards,
    required this.deafCardsMode,
    required this.hearingFocus,
  });

  /// El botón dice lo que va a pasar. «Responder» cuando hay algo a lo que
  /// responder; «Iniciar» cuando la persona sorda abre el turno ella misma.
  String get _deafCardsLabel =>
      deafCardsMode == CardsFlowPurpose.conversationReply
      ? 'Responder con tarjetas LSB'
      : 'Iniciar con tarjetas LSB';

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      decoration: BoxDecoration(
        color: AppTheme.framedSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppTheme.lsbViolet.withValues(alpha: 0.24),
          width: 1.25,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.lsbViolet.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            height: 46,
            // Abre las tarjetas LSB: lleva el violeta de las glosas.
            child: OutlinedButton.icon(
              key: const Key('tarjetas_lsb'),
              onPressed: onDeafCards,
              icon: const Icon(
                Icons.sign_language,
                size: 18,
                color: AppTheme.lsbViolet,
              ),
              label: Text(
                _deafCardsLabel,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.lsbViolet,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.lsbViolet,
                side: const BorderSide(color: AppTheme.lsbViolet, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(23),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextInputWidget(
            onSubmit: onHearingText,
            onSpeechSubmit: onHearingSpeech,
            focusNode: hearingFocus,
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _StatusChip({
    required this.icon,
    required this.text,
    this.color = AppTheme.brandLight,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          // El icono y el borde llevan el color; el texto, la tinta, que se
          // lee sobre blanco.
          Flexible(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyConversation extends StatelessWidget {
  const _EmptyConversation({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.forum_outlined,
              size: 56,
              color: AppTheme.brandLight,
            ),
            const SizedBox(height: 18),
            const Text(
              'Un chat, dos idiomas',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.ink,
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Habla o escribe y el mensaje se interpreta en el avatar LSB.\n\n'
              'Responde con tarjetas para convertir el mensaje en texto y '
              'voz.\n\nPásense el teléfono '
              'para conversar.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.inkSub,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Entrada de una burbuja nueva: aparece desde su lado (izquierda la persona
/// sorda, derecha la oyente) con un fundido corto. Si luego cambia de tamaño
/// —la traducción llega y la burbuja crece— lo hace suavemente.
class _EntradaMensaje extends StatefulWidget {
  final bool animar;
  final bool desdeLaIzquierda;
  final Widget child;

  const _EntradaMensaje({
    super.key,
    required this.animar,
    required this.desdeLaIzquierda,
    required this.child,
  });

  @override
  State<_EntradaMensaje> createState() => _EntradaMensajeState();
}

class _EntradaMensajeState extends State<_EntradaMensaje>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
    value: widget.animar ? 0 : 1,
  );
  late final Animation<double> _curva = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );

  @override
  void initState() {
    super.initState();
    if (widget.animar) _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _curva,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: Offset(widget.desdeLaIzquierda ? -0.06 : 0.06, 0.12),
          end: Offset.zero,
        ).animate(_curva),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: widget.child,
        ),
      ),
    );
  }
}
