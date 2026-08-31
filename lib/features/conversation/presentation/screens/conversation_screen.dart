import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lsb_legal_app/core/domain/entities/speech_act.dart';

import 'package:lsb_legal_app/app/app_theme.dart';
import 'package:lsb_legal_app/app/navigation_provider.dart';
import 'package:lsb_legal_app/core/di/injection.dart';
import 'package:lsb_legal_app/core/domain/entities/conversation.dart';
import 'package:lsb_legal_app/core/domain/entities/semantic_message.dart';
import 'package:lsb_legal_app/features/audio_to_lsb/presentation/widgets/text_input_widget.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/context_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/semantic_zones_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/sentence_provider.dart';
import 'package:lsb_legal_app/features/conversation/presentation/providers/conversation_provider.dart';
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

  @override
  void dispose() {
    _scroll.dispose();
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
      } catch (_) {
      }
    }
    await audio.speak(turn.outputs.text);
  }

  void _openCardsFlow() {
    final conversation = ref.read(conversationProvider).conversation;
    // Abrir sin frase a medias es empezar de cero, haya pregunta pendiente o
    // no. Antes se exigia una pregunta previa, asi que cuando la persona sorda
    // abria la conversacion ella misma el contexto anterior no se limpiaba y
    // entraba al flujo con las zonas de otra charla.
    final startingFresh = ref.read(sentenceProvider).isEmpty;

    if (startingFresh) {
      final proposedId = conversation.suggestedReplyContextId;
      final proposed = proposedId == null ? null : contextById(proposedId);
      final notifier = ref.read(contextProvider.notifier);
      if (proposed != null) {
        notifier.setContext(proposed);
      } else {
        notifier.clearContext();
      }
      ref.read(semanticZonesProvider.notifier).reset();
    }
    ref.read(selectedTabProvider.notifier).select(AppTab.cards);
  }

  ConversationTurn? _instruccionPendiente(ConversationState state) {
    final pendiente = state.conversation.pendingReply;
    if (pendiente == null) return null;
    return pendiente.message.speechAct == SpeechAct.instruction
        ? pendiente
        : null;
  }

  Future<void> _enviarRespuestaRapida(
      List<String> glosses, String text) async {
    ref.read(conversationProvider.notifier).addDeafDeclaration(
          result: TranslationResult(baseSentence: text, generatedText: text),
          glosses: glosses,
        );
    await ref.read(audioOutputProvider).speak(text);
  }

  Future<void> _confirmNewConversation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nuevo chat'),
        content: const Text(
            'Se borrará el historial de este chat. ¿Continuar?'),
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
      if ((prev?.conversation.turns.length ?? 0) <
          next.conversation.turns.length) {
        _scrollToEnd();
      }
    });

    return Theme(
      data: AppTheme.darkTheme,
      child: Scaffold(
        backgroundColor: AppTheme.darkBg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          title: Row(
            mainAxisSize: MainAxisSize.min,
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
              const SizedBox(width: 10),
              const Text(
                'Chat',
                style:
                    TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.4),
              ),
            ],
          ),
          actions: [
            if (!state.conversation.isEmpty)
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
                child: state.conversation.isEmpty
                    ? const _EmptyConversation()
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        itemCount: state.conversation.turns.length,
                        itemBuilder: (context, i) {
                          final turn = state.conversation.turns[i];
                          return TurnBubble(
                            turn: turn,
                            onPlayAudio: () => _playDeafTurn(turn),
                            onShowAvatar: () => AvatarPlaybackSheet.show(
                              context,
                              glosses: turn.outputs.animationGlosses.isNotEmpty
                                  ? turn.outputs.animationGlosses
                                  : turn.message.glosses,
                              animationUrls: turn.outputs.animationUrls,
                            ),
                          );
                        },
                      ),
              ),
              if (state.error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _StatusChip(
                    icon: Icons.error_outline,
                    text: state.error!,
                    color: AppTheme.errorDark,
                  ),
                ),
              if (_instruccionPendiente(state) != null)
                QuickReplyBar(onReply: _enviarRespuestaRapida),
              _InputArea(
                onHearingText: (text) => ref
                    .read(conversationProvider.notifier)
                    .sendHearingMessage(text),
                onHearingSpeech: (text) => ref
                    .read(conversationProvider.notifier)
                    .sendHearingMessage(text, source: MessageSource.speech),
                onDeafCards: _openCardsFlow,
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

  const _InputArea({
    required this.onHearingText,
    required this.onHearingSpeech,
    required this.onDeafCards,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton.icon(
              onPressed: onDeafCards,
              icon: const Icon(Icons.sign_language, size: 18),
              label: const Text(
                'Responder con tarjetas LSB',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.brandLight,
                side: const BorderSide(color: AppTheme.darkBorder),
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
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyConversation extends StatelessWidget {
  const _EmptyConversation();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.forum_outlined,
                size: 56, color: AppTheme.brandLight),
            const SizedBox(height: 18),
            const Text(
              'Un chat, dos idiomas',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'La persona oyente habla o escribe y su mensaje se interpreta '
              'en el avatar LSB.\n\nLa persona sorda responde con tarjetas y '
              'su mensaje se convierte en texto y voz.\n\nPásense el teléfono '
              'para conversar.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.darkTextSub,
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
