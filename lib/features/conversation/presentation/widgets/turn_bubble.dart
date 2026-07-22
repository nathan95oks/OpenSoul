import 'package:flutter/material.dart';

import 'package:lsb_legal_app/app/theme.dart';
import 'package:lsb_legal_app/core/domain/entities/conversation.dart';
import 'package:lsb_legal_app/core/domain/entities/semantic_message.dart';

/// Burbuja de un turno de la conversación.
///
/// - Persona sorda (izquierda): texto de la declaración + acción de audio,
///   para que la persona oyente escuche el mensaje.
/// - Persona oyente (derecha): texto reconocido + acción de avatar, para
///   que la persona sorda vea el mensaje en LSB.
class TurnBubble extends StatelessWidget {
  final ConversationTurn turn;
  final VoidCallback onPlayAudio;
  final VoidCallback onShowAvatar;

  const TurnBubble({
    super.key,
    required this.turn,
    required this.onPlayAudio,
    required this.onShowAvatar,
  });

  bool get _isDeaf => turn.message.speaker == SpeakerRole.deaf;

  @override
  Widget build(BuildContext context) {
    final align = _isDeaf ? Alignment.centerLeft : Alignment.centerRight;
    final bg = _isDeaf ? AppTheme.darkElevated : AppTheme.brandPrimary;
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(18),
      topRight: const Radius.circular(18),
      bottomLeft: Radius.circular(_isDeaf ? 4 : 18),
      bottomRight: Radius.circular(_isDeaf ? 18 : 4),
    );

    return Align(
      alignment: align,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 5),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: radius,
            border: Border.all(
              color: _isDeaf ? AppTheme.darkBorder : AppTheme.brandDeep,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isDeaf ? Icons.sign_language : Icons.record_voice_over,
                    size: 13,
                    color: _isDeaf ? AppTheme.brandLight : Colors.white70,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    _isDeaf ? 'Persona sorda · LSB' : 'Persona oyente',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: _isDeaf ? AppTheme.brandLight : Colors.white70,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                turn.outputs.text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  height: 1.35,
                ),
              ),
              if (turn.message.glosses.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  turn.message.glosses
                      .map((g) => g.replaceAll('_', ' '))
                      .join(' • '),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _isDeaf ? AppTheme.darkTextSub : Colors.white60,
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: _isDeaf
                    ? _ActionChip(
                        icon: Icons.volume_up_rounded,
                        label: 'Escuchar',
                        onTap: onPlayAudio,
                      )
                    : (turn.outputs.hasAvatar
                        ? _ActionChip(
                            icon: Icons.threed_rotation,
                            label: 'Ver en avatar',
                            onTap: onShowAvatar,
                          )
                        : const SizedBox.shrink()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: Colors.white),
              const SizedBox(width: 5),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
