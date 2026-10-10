import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  /// El avatar está signando el mensaje del oyente: la persona sorda todavía
  /// lo está leyendo, no es momento de llamarla a responder.
  bool _avatarSignando = false;

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

  /// Cuánto llama el botón de tarjetas: a responder cuando el avatar terminó
  /// de signar lo que dijo el oyente; a empezar cuando el chat está vacío.
  _LlamadoLsb _llamado(ConversationState state) {
    if (state.processing || _avatarSignando) return _LlamadoLsb.ninguno;
    if (state.conversation.pendingReply != null) return _LlamadoLsb.responder;
    if (state.conversation.isEmpty) return _LlamadoLsb.empezar;
    return _LlamadoLsb.ninguno;
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
        setState(() => _avatarSignando = true);
        // La hoja se cierra sola al terminar la seña: recién entonces se
        // llama a la persona sorda a responder.
        await AvatarPlaybackSheet.show(
          context,
          glosses: glosses,
          animationUrls: lastTurn.outputs.animationUrls,
          animationGlosses: lastTurn.outputs.animationGlosses,
        );
        if (mounted) setState(() => _avatarSignando = false);
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
              // Los avisos aparecen y se van deslizándose, sin que el resto
              // salte de golpe.
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
                  ],
                ),
              ),
              _InputArea(
                onHearingText: _handleHearingSend,
                onHearingSpeech: (text) =>
                    _handleHearingSend(text, source: MessageSource.speech),
                onDeafCards: _openCardsFlow,
                deafCardsMode: _deafCardsMode(state),
                llamado: _llamado(state),
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
  final _LlamadoLsb llamado;
  final FocusNode hearingFocus;

  const _InputArea({
    required this.onHearingText,
    required this.onHearingSpeech,
    required this.onDeafCards,
    required this.deafCardsMode,
    required this.llamado,
    required this.hearingFocus,
  });

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
          _BotonTarjetasLsb(
            onPressed: onDeafCards,
            responder: deafCardsMode == CardsFlowPurpose.conversationReply,
            llamado: llamado,
          ),
          const SizedBox(height: 10),
          TextInputWidget(
            onSubmit: onHearingText,
            onSpeechSubmit: onHearingSpeech,
            focusNode: hearingFocus,
            // Lo que el oyente dicta se envía en cuanto termina de hablar.
            sendSpeechAutomatically: true,
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
              'Empiecen a conversar',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.ink,
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),
            // Quién hace qué, en una línea cada uno.
            const _QuienHaceQue(
              icon: Icons.mic_none,
              color: AppTheme.brandLight,
              text: 'Oyente: habla o escribe',
            ),
            const SizedBox(height: 8),
            const _QuienHaceQue(
              icon: Icons.sign_language,
              color: AppTheme.lsbViolet,
              text: 'Persona sorda: responde en LSB',
            ),
          ],
        ),
      ),
    );
  }
}

class _QuienHaceQue extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _QuienHaceQue({
    required this.icon,
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            text,
            style: const TextStyle(
              color: AppTheme.inkSub,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

/// A qué invita el botón de tarjetas LSB en este momento.
enum _LlamadoLsb {
  /// Turno del oyente (o el avatar todavía signa): el botón espera, quieto.
  ninguno,

  /// El chat está vacío: la persona sorda también puede empezar.
  empezar,

  /// El avatar terminó de signar al oyente: le toca a la persona sorda.
  responder,
}

/// El botón que abre las tarjetas LSB. Lleva el violeta de las glosas y
/// llama la atención solo cuando le toca a la persona sorda: relleno y
/// latiendo para responder, con el borde latiendo para empezar. Al pasar a
/// «responder» vibra una vez: quien no oye el audio del oyente lo siente.
class _BotonTarjetasLsb extends StatefulWidget {
  final VoidCallback onPressed;
  final bool responder;
  final _LlamadoLsb llamado;

  const _BotonTarjetasLsb({
    required this.onPressed,
    required this.responder,
    required this.llamado,
  });

  @override
  State<_BotonTarjetasLsb> createState() => _BotonTarjetasLsbState();
}

class _BotonTarjetasLsbState extends State<_BotonTarjetasLsb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _latido = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _sincronizar());
  }

  @override
  void didUpdateWidget(covariant _BotonTarjetasLsb old) {
    super.didUpdateWidget(old);
    if (old.llamado != widget.llamado) {
      if (widget.llamado == _LlamadoLsb.responder) {
        HapticFeedback.mediumImpact();
      }
      _sincronizar();
    }
  }

  void _sincronizar() {
    if (!mounted) return;
    final quieto =
        widget.llamado == _LlamadoLsb.ninguno ||
        MediaQuery.of(context).disableAnimations;
    if (quieto) {
      _latido
        ..stop()
        ..value = 0;
    } else if (!_latido.isAnimating) {
      _latido.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _latido.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final responder = widget.llamado == _LlamadoLsb.responder;
    final empezar = widget.llamado == _LlamadoLsb.empezar;
    final texto = widget.responder ? 'Responder en LSB' : 'Empezar en LSB';
    final tinta = responder ? Colors.white : AppTheme.lsbViolet;

    return AnimatedBuilder(
      animation: _latido,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_latido.value);
        return Transform.scale(
          scale: responder ? 1 + 0.03 * t : 1,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            width: double.infinity,
            height: 48,
            decoration: BoxDecoration(
              color: responder
                  ? AppTheme.lsbViolet
                  : AppTheme.lsbViolet.withValues(
                      alpha: empezar ? 0.05 + 0.08 * t : 0,
                    ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppTheme.lsbViolet,
                width: empezar ? 1.5 + 0.8 * t : 1.5,
              ),
              boxShadow: [
                if (responder || empezar)
                  BoxShadow(
                    color: AppTheme.lsbViolet.withValues(
                      alpha: (responder ? 0.28 : 0.12) + 0.22 * t,
                    ),
                    blurRadius: 10 + 10 * t,
                    spreadRadius: responder ? 1 + 2 * t : 0,
                  ),
              ],
            ),
            child: child,
          ),
        );
      },
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          key: const Key('tarjetas_lsb'),
          borderRadius: BorderRadius.circular(24),
          onTap: widget.onPressed,
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Row(
                key: ValueKey('$texto$responder'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  // La mano se mueve mientras el botón llama.
                  AnimatedBuilder(
                    animation: _latido,
                    builder: (context, icon) => Transform.rotate(
                      angle: (responder || empezar)
                          ? 0.18 * (_latido.value - 0.5)
                          : 0,
                      child: icon,
                    ),
                    child: Icon(Icons.sign_language, size: 20, color: tinta),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    texto,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: tinta,
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
