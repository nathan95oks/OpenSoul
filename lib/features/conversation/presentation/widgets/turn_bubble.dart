import 'package:flutter/material.dart';

import 'package:lsb_legal_app/app/app_theme.dart';
import 'package:lsb_legal_app/core/domain/entities/conversation.dart';
import 'package:lsb_legal_app/core/domain/entities/semantic_message.dart';
import 'package:lsb_legal_app/features/conversation/presentation/widgets/gloss_line.dart';

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
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(18),
      topRight: const Radius.circular(18),
      bottomLeft: Radius.circular(_isDeaf ? 4 : 18),
      bottomRight: Radius.circular(_isDeaf ? 18 : 4),
    );

    // Sin etiqueta de quién habla: lo dicen el color y el lado. Lo que llega
    // por Audio/Texto→LSB va en azul muy oscuro, a la derecha; lo que sale de
    // las tarjetas (LSB→Texto/Audio), con el violeta de las glosas, a la
    // izquierda. Quién habla sigue en el modelo y en la lectura de pantalla.
    return Semantics(
      container: true,
      label: _isDeaf
          ? 'Mensaje de la persona sorda'
          : 'Mensaje de la persona oyente',
      child: Align(
        alignment: align,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.82,
          ),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 5),
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
            decoration: BoxDecoration(
              color: _isDeaf ? null : AppTheme.brandPrimary,
              gradient: _isDeaf
                  ? const LinearGradient(
                      colors: [AppTheme.lsbViolet, AppTheme.lsbVioletDeep],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              borderRadius: radius,
              border: Border.all(
                color: _isDeaf ? AppTheme.lsbVioletLight : AppTheme.brandLight,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: (_isDeaf ? AppTheme.lsbViolet : AppTheme.brandPrimary)
                      .withValues(alpha: 0.18),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
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
                  GlossLine(
                    glosses: turn.message.glosses,
                    pendingColor: AppTheme.pendingSignOnDark,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _isDeaf
                          ? Colors.white.withValues(alpha: 0.9)
                          : Colors.white60,
                    ),
                  ),
                ],
                if (turn.message.disambiguations.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      for (final d in turn.message.disambiguations)
                        Tooltip(
                          message: d.reason,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${d.original} → ${d.meaning}',
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                    ],
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
                            : (turn.pending
                                  ? const _PendingSigns()
                                  : const SizedBox.shrink())),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PendingSigns extends StatelessWidget {
  const _PendingSigns();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Traduciendo a señas',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 11,
            height: 11,
            child: CircularProgressIndicator(
              strokeWidth: 1.8,
              color: Colors.white70,
            ),
          ),
          const SizedBox(width: 7),
          Text(
            'Traduciendo a señas…',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.75),
            ),
          ),
        ],
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
