import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:lsb_legal_app/app/theme.dart';
import 'package:lsb_legal_app/core/di/core_providers.dart';
import 'package:lsb_legal_app/core/domain/entities/conversation.dart';
import 'package:lsb_legal_app/core/domain/entities/semantic_message.dart';
import 'package:lsb_legal_app/features/audio_to_lsb/presentation/widgets/text_input_widget.dart';
import '../providers/conversation_provider.dart';
import '../widgets/avatar_playback_sheet.dart';
import '../widgets/turn_bubble.dart';

/// Pantalla central de OpenSoul: la conversación bidireccional.
///
/// Un solo dispositivo compartido entre ambas personas:
///   - La persona oyente habla o escribe (abajo); su mensaje se muestra
///     como turno con acceso al avatar LSB.
///   - La persona sorda responde construyendo su mensaje con tarjetas
///     (botón "Responder con tarjetas"); su declaración vuelve aquí como
///     turno con texto y audio.
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
        // cae a TTS local
      }
    }
    await audio.speak(turn.outputs.text);
  }

  Future<void> _confirmNewConversation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nueva conversación'),
        content: const Text(
            'Se borrará el historial de esta conversación. ¿Continuar?'),
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
    // Carga el diccionario en cuanto se abre la conversación: la inferencia
    // de contexto se construye sobre él y debe estar lista para el primer
    // turno, no para el segundo.
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
                'Conversación',
                style:
                    TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.4),
              ),
            ],
          ),
          actions: [
            if (!state.conversation.isEmpty)
              IconButton(
                icon: const Icon(Icons.restart_alt),
                tooltip: 'Nueva conversación',
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
                              glosses: turn.message.glosses,
                              animationUrls: turn.outputs.animationUrls,
                            ),
                          );
                        },
                      ),
              ),
              if (state.processing)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: _StatusChip(
                    icon: Icons.sync,
                    text: 'Traduciendo a señas…',
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
              _InputArea(
                onHearingText: (text) => ref
                    .read(conversationProvider.notifier)
                    .sendHearingMessage(text),
                onHearingSpeech: (text) => ref
                    .read(conversationProvider.notifier)
                    .sendHearingMessage(text, source: MessageSource.speech),
                onDeafCards: () => context.push('/lsb-to-audio'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Zona de entrada compartida: la persona sorda entra por tarjetas; la
/// oyente por voz o texto. El teléfono se pasa entre ambas.
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
              'Una conversación, dos idiomas',
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
