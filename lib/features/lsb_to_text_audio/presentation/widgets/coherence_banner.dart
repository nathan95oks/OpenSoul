import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lsb_legal_app/app/app_theme.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/denuncia_robo_draft_provider.dart';

/// Banner superior de coherencia y validación semántica en tiempo real.
///
/// Detecta datos pendientes (ej. una relación espacial "CERCA" sin lugar de referencia,
/// un objeto "BOLSA" sin contenido aclarado o un sospechoso sin prendas) y orienta
/// visualmente a la persona usuaria para construir una declaración formal sólida.
class CoherenceBanner extends ConsumerWidget {
  const CoherenceBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(declarationDraftProvider);
    final aviso = _analizarCoherencia(draft);

    if (aviso == null) return const SizedBox.shrink();

    final isWarning = aviso.isWarning;
    final color = isWarning ? const Color(0xFFD97706) : AppTheme.brandPrimary;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isWarning ? Icons.info_outline : Icons.lightbulb_outline,
            color: color,
            size: 19,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  aviso.titulo,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: color,
                    letterSpacing: 0.1,
                  ),
                ),
                if (aviso.detalle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    aviso.detalle!,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.lightText.withValues(alpha: 0.85),
                      height: 1.25,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  _CoherenceNotice? _analizarCoherencia(dynamic draft) {
    if (draft == null) return null;

    // 1. Relación espacial sin ancla
    if (draft.location.relation != null && draft.location.pending) {
      final rel = draft.location.relation;
      return _CoherenceNotice(
        titulo: 'Falta precisar el lugar de referencia',
        detalle: 'Indicaste "$rel", pero falta especificar: ¿$rel de qué lugar?',
        isWarning: true,
      );
    }

    // 2. Objetos sin detalle de contenido
    for (final obj in draft.objects) {
      if ((obj.concept == 'BOLSA' || obj.concept == 'CAJA') &&
          (obj.contents == null || obj.contents.isEmpty)) {
        return _CoherenceNotice(
          titulo: 'Detalle sugerido para ${obj.concept}',
          detalle: 'Puedes especificar qué contenía en su interior para mayor precisión formal.',
          isWarning: false,
        );
      }
    }

    // 3. Documento papel vago
    for (final obj in draft.objects) {
      if (obj.concept == 'PAPEL' && (obj.docType == null || obj.docType.isEmpty)) {
        return _CoherenceNotice(
          titulo: 'Especificar tipo de documento',
          detalle: 'Aclara si se trata de tu C.I., una factura o un trámite judicial.',
          isWarning: true,
        );
      }
    }

    // 4. Personas con prendas sin color
    for (final p in draft.persons) {
      for (final c in p.clothing) {
        if (c.color == null) {
          return _CoherenceNotice(
            titulo: 'Detalle de vestimenta',
            detalle: 'Asignar color a ${c.concept.toLowerCase()} ayudará a identificar mejor a la persona.',
            isWarning: false,
          );
        }
      }
    }

    return null;
  }
}

class _CoherenceNotice {
  final String titulo;
  final String? detalle;
  final bool isWarning;

  const _CoherenceNotice({
    required this.titulo,
    this.detalle,
    this.isWarning = false,
  });
}
