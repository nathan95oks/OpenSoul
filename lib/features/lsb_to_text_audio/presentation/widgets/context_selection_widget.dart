import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lsb_legal_app/app/theme.dart';
import '../providers/context_provider.dart';
import 'package:lsb_legal_app/core/di/core_providers.dart';
import 'package:lsb_legal_app/core/domain/entities/context_suggestion.dart';
import 'package:lsb_legal_app/core/domain/entities/semantic_context.dart';

/// Pantalla de selección de contexto — estilo reference design.
/// Fondo blanco, botones con borde negro, hover naranja.
///
/// Cuando se llega aquí para responder a la persona oyente, la pantalla deja
/// de ser una lista neutra: muestra la frase que se está respondiendo y
/// propone el contexto inferido de ella, con la evidencia que lo justifica.
/// La sugerencia se ofrece, no se impone — la persona sorda decide.
class ContextSelectionWidget extends ConsumerStatefulWidget {
  const ContextSelectionWidget({super.key});

  @override
  ConsumerState<ContextSelectionWidget> createState() =>
      _ContextSelectionWidgetState();
}

class _ContextSelectionWidgetState
    extends ConsumerState<ContextSelectionWidget> {
  /// Familia desplegada. `null` mientras se muestran las cuatro entradas.
  ContextFamily? _abierta;

  @override
  Widget build(BuildContext context) {
    final pending = ref.watch(pendingReplyProvider);
    final suggestion = pending?.suggestion;
    final highlightedId = pending?.proposedContextId;

    // Una familia con un solo contexto entra directo; con varios se despliega
    // para preguntar de cuál se trata.
    final familia = _abierta;
    final desplegados = familia == null
        ? const <SemanticContext>[]
        : contextsOfFamily(familia);

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            if (pending != null) ...[
              _ReplyingToBanner(text: pending.question),
              const SizedBox(height: 20),
            ],
            Text(
              pending != null
                  ? '¿Desde qué contexto respondes?'
                  : 'Selecciona el contexto',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: AppTheme.lightText,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              pending != null
                  ? 'Puedes aceptar el contexto propuesto o elegir otro.'
                  : '¿Qué necesitas hacer?',
              style: const TextStyle(
                fontSize: 15,
                color: AppTheme.lightTextSub,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 28),
            if (familia == null)
              ...contextFamilies.map(
                (f) => _FamilyButton(
                  family: f,
                  highlighted: highlightedId != null &&
                      f.contextIds.contains(highlightedId),
                  onTap: () {
                    final contextos = contextsOfFamily(f);
                    if (contextos.length == 1) {
                      ref.read(contextProvider.notifier).setContext(contextos.first);
                    } else {
                      setState(() => _abierta = f);
                    }
                  },
                ),
              )
            else ...[
              TextButton.icon(
                onPressed: () => setState(() => _abierta = null),
                icon: const Icon(Icons.arrow_back, size: 18),
                label: const Text('Volver'),
                style: TextButton.styleFrom(
                    foregroundColor: AppTheme.lightTextSub),
              ),
              const SizedBox(height: 8),
              ...desplegados.map(
                (ctx) => _ContextButton(
                  context: ctx,
                  highlighted: ctx.id == highlightedId,
                  suggestion:
                      ctx.id == suggestion?.contextId ? suggestion : null,
                ),
              ),
            ],
            const SizedBox(height: 32),
            Center(
              child: Text(
                'Diseñado para ser accesible y fácil de usar',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.lightTextSub.withValues(alpha: 0.8),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

/// Entrada de primer nivel: la gestión que trae la persona.
///
/// Deliberadamente sin la urgencia ni la evidencia que muestra
/// [_ContextButton]: aquí todavía no se ha dicho qué pasó, y teñir de rojo
/// "Denuncias" antes de saberlo presiona la elección.
class _FamilyButton extends StatelessWidget {
  final ContextFamily family;
  final VoidCallback onTap;

  /// La familia que contiene el contexto inferido de la pregunta del oyente.
  ///
  /// Sin esto la inferencia era invisible justo donde más falta hace: «Mis
  /// datos» agrupa un solo contexto, así que se entra directo y el botón
  /// resaltado de dentro no llega a dibujarse nunca. Acertar el contexto y no
  /// enseñarlo deja a la persona buscándolo a mano igual que antes.
  final bool highlighted;

  const _FamilyButton({
    required this.family,
    required this.onTap,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: highlighted
          ? '${family.name}. ${family.description}. Sugerido para responder.'
          : '${family.name}. ${family.description}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            decoration: BoxDecoration(
              color: AppTheme.lightSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: highlighted ? AppTheme.brandPrimary : AppTheme.lightBorder,
                width: highlighted ? 2 : 1,
              ),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Row(
              children: [
                Text(family.emoji, style: const TextStyle(fontSize: 30)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        family.name,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.lightText,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        family.description,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.lightTextSub,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppTheme.lightTextSub),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Frase de la persona oyente que se está respondiendo. Mantenerla a la vista
/// evita que la persona sorda tenga que recordar la pregunta mientras navega
/// el flujo de tarjetas.
class _ReplyingToBanner extends StatelessWidget {
  final String text;

  const _ReplyingToBanner({required this.text});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Respondiendo a: $text',
      excludeSemantics: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.brandPrimary.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.brandPrimary.withValues(alpha: 0.30),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.record_voice_over,
                    size: 14, color: AppTheme.brandPrimary),
                SizedBox(width: 6),
                Text(
                  'RESPONDIENDO A',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: AppTheme.brandPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '«$text»',
              style: const TextStyle(
                fontSize: 15,
                height: 1.35,
                color: AppTheme.lightText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContextButton extends ConsumerStatefulWidget {
  final SemanticContext context;

  /// Contexto propuesto para responder: se dibuja primero y resaltado.
  final bool highlighted;

  /// Presente solo cuando la propuesta viene de analizar la frase del oyente
  /// (y no de heredar el contexto ya declarado). Aporta la evidencia.
  final ContextSuggestion? suggestion;

  const _ContextButton({
    required this.context,
    this.highlighted = false,
    this.suggestion,
  });

  @override
  ConsumerState<_ContextButton> createState() => _ContextButtonState();
}

class _ContextButtonState extends ConsumerState<_ContextButton> {
  bool _hovered = false;

  static const _orange = AppTheme.brandPrimary;

  /// Etiqueta del distintivo, o `null` si este contexto no está propuesto.
  /// Se distingue una inferencia ("sugerido") de una herencia del contexto
  /// que ya se declaró antes en la conversación: no son lo mismo y la
  /// persona sorda merece saber cuál de las dos está viendo.
  String? get _badge {
    if (!widget.highlighted) return null;
    return widget.suggestion != null ? 'SUGERIDO' : 'CONTEXTO ACTUAL';
  }

  @override
  Widget build(BuildContext context) {
    final badge = _badge;
    final evidence = widget.suggestion?.evidence ?? const <String>[];
    final active = _hovered || widget.highlighted;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      // A11Y-01: el lector de pantalla anuncia cada contexto como un botón con
      // su nombre y descripción (el emoji y la flecha son decorativos).
      child: Semantics(
        button: true,
        label: [
          ?badge,
          '${widget.context.name}.',
          widget.context.description,
          if (evidence.isNotEmpty) 'Detectado: ${evidence.join(", ")}',
        ].join(' '),
        excludeSemantics: true,
        child: GestureDetector(
          onTapDown: (_) => setState(() => _hovered = true),
          onTapUp: (_) {
            setState(() => _hovered = false);
            ref.read(contextProvider.notifier).setContext(widget.context);
          },
          onTapCancel: () => setState(() => _hovered = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            decoration: BoxDecoration(
              color: AppTheme.lightSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: active ? _orange : AppTheme.lightBorder,
                width: active ? 2 : 1.5,
              ),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Row(
              children: [
                Text(
                  widget.context.emoji,
                  style: const TextStyle(fontSize: 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              widget.context.name,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: active ? _orange : AppTheme.lightText,
                              ),
                            ),
                          ),
                          if (badge != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: _orange,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                badge,
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.6,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.context.description,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.lightTextSub,
                        ),
                      ),
                      // Por qué se propone este contexto: la sugerencia debe
                      // poder justificarse, no pedirse a ciegas.
                      if (evidence.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Detectado: ${evidence.join(" · ")}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.brandPrimary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: active ? _orange : AppTheme.lightTextSub,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
