import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lsb_legal_app/app/app_theme.dart';
import 'package:lsb_legal_app/core/domain/entities/declaration_draft.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/denuncia_robo_draft_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/widgets/amount_input_sheet.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/widgets/app_toast_manager.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/widgets/disambiguation_modal.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/widgets/entity_editor_sheets.dart';

/// Panel de Fichas de Entidades Configuradas (Chips Visuales Dinámicos).
///
/// Muestra un resumen visual editable de las personas, objetos, lugares y hechos
/// que la persona usuaria ha personalizado en su declaración.
/// Permite tocar cualquier ficha para reabrir su editor o eliminarla con un toque.
class ConfiguredEntityChips extends ConsumerWidget {
  const ConfiguredEntityChips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(declarationDraftProvider);
    final chips = <Widget>[];

    // 1. Fichas de Personas
    for (final p in draft.persons) {
      final desc = _describirPersona(p);
      chips.add(
        _EntityChip(
          icon: p.role == 'victim' ? Icons.person : Icons.person_outline,
          label: desc,
          color: const Color(0xFF2563EB), // Azul
          onTap: () async {
            await _reabrirEditorPersona(context, ref, p);
          },
          onDelete: () {
            ref.read(declarationDraftProvider.notifier).removePerson(p.id);
            AppToastManager.showInfo(context, 'Persona eliminada del relato');
          },
        ),
      );
    }

    // 2. Fichas de Objetos y Dinero
    for (final o in draft.objects) {
      final desc = _describirObjeto(o);
      final isDinero = o.concept == 'BILLETES' || o.concept == 'DINERO';
      chips.add(
        _EntityChip(
          icon: isDinero
              ? Icons.payments_outlined
              : (o.role == 'lost'
                  ? Icons.search_off
                  : (o.docType != null
                      ? Icons.badge_outlined
                      : Icons.inventory_2_outlined)),
          label: desc,
          color: isDinero
              ? const Color(0xFF16A34A) // Verde esmeralda para dinero
              : const Color(0xFF0D9488), // Verde azulado / Teal
          onTap: () async {
            await _reabrirEditorObjeto(context, ref, o);
          },
          onDelete: () {
            ref.read(declarationDraftProvider.notifier).removeObject(o.id);
            AppToastManager.showInfo(context, 'Objeto eliminado del relato');
          },
        ),
      );
    }

    // 3. Ficha de Lugar
    if (!draft.location.isEmpty) {
      final desc = _describirLugar(draft.location);
      chips.add(
        _EntityChip(
          icon: Icons.location_on_outlined,
          label: desc,
          color: const Color(0xFFE11D48), // Rojo coral
          onTap: () async {
            await reabrirEditorLugar(context, ref);
          },
          onDelete: () {
            ref.read(declarationDraftProvider.notifier).clearLocationReference();
            AppToastManager.showInfo(context, 'Referencia de lugar restablecida');
          },
        ),
      );
    }

    // 4. Una ficha por hecho. Dos acciones son dos fichas: quitar una no
    // toca la otra, porque cada `onDelete` lleva el id de su propio hecho.
    for (final f in draft.facts) {
      chips.add(
        _EntityChip(
          key: ValueKey('hecho_${f.id}'),
          icon: Icons.bolt,
          label: _describirHecho(f),
          color: AppTheme.brandPrimary,
          onTap: () async {
            if (f.action == 'ESCAPAR') {
              await DisambiguationModal.desambiguarEscapar(context, ref);
            } else if (f.action == 'PERDER' || f.action == 'ROBAR') {
              await DisambiguationModal.desambiguarPerderVsRobar(context, ref);
            }
          },
          onDelete: () {
            ref.read(declarationDraftProvider.notifier).removeFact(f.id);
            AppToastManager.showInfo(context, 'Se quitó: ${f.action}');
          },
        ),
      );
    }

    // 5. Fichas de Evidencia
    for (final e in draft.evidence) {
      chips.add(
        _EntityChip(
          icon: Icons.attach_file,
          label: e.concept.replaceAll('_', ' '),
          color: const Color(0xFF7C3AED), // Violeta
          onTap: null,
          onDelete: () {
            ref.read(declarationDraftProvider.notifier).removeEvidence(e.id);
            AppToastManager.showInfo(context, 'Evidencia eliminada');
          },
        ),
      );
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_outline, size: 14, color: AppTheme.brandPrimary),
              const SizedBox(width: 6),
              Text(
                'ELEMENTOS CONFIGURADOS (${chips.length}) · Toca para editar',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.lightTextSub,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < chips.length; i++) ...[
                  chips[i],
                  if (i < chips.length - 1) const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _describirPersona(PersonEntity p) {
    final partes = <String>[];
    if (p.gender != null) partes.add(p.gender!);
    if (p.build != null) partes.add(p.build!);
    if (p.height != null) partes.add(p.height!);
    if (p.clothing.isNotEmpty) {
      final prendas = p.clothing.map((c) {
        if (c.color != null) return '${c.concept.toLowerCase()} (${c.color})';
        return c.concept.toLowerCase();
      }).join(', ');
      partes.add('Ropa: $prendas');
    }
    return partes.isEmpty ? 'Persona descrita' : partes.join(' · ');
  }

  static String _describirObjeto(ObjectInvolved o) {
    if (o.concept == 'BILLETES' || o.concept == 'DINERO') {
      final moneda = (o.unit != null && o.unit!.toLowerCase().contains('dolar'))
          ? 'USD'
          : 'Bs.';
      if (o.quantity != null && o.quantity!.isNotEmpty) {
        return 'Monto: ${o.quantity} $moneda';
      }
      return 'Dinero / Billetes';
    }
    if (o.docType != null && o.docType!.isNotEmpty) {
      return o.docType!;
    }
    if (o.contents != null && o.contents!.isNotEmpty) {
      return '${o.concept} (${o.contents})';
    }
    if (o.detail != null && o.detail!.isNotEmpty) {
      return '${o.concept} · ${o.detail}';
    }
    final rolStr = o.role == 'lost' ? 'Extraviado' : (o.role == 'stolen' ? 'Robado' : 'Prueba');
    return '${o.concept.replaceAll('_', ' ')} ($rolStr)';
  }

  static String _describirLugar(LocationInfo loc) {
    final partes = <String>[];
    if (loc.mainPlaceConcept != null) {
      partes.add(loc.mainPlaceConcept!);
    }
    if (loc.mainPlaceDetail != null && loc.mainPlaceDetail!.isNotEmpty) {
      partes.add(loc.mainPlaceDetail!);
    }
    if (loc.relation != null) {
      partes.add(loc.relation!.toLowerCase());
      if (loc.referenceLiteralText != null) {
        partes.add(loc.referenceLiteralText!);
      } else if (loc.referenceType == 'home') {
        partes.add('mi casa');
      }
    }
    return partes.isEmpty ? 'Lugar registrado' : partes.join(' · ');
  }

  static String _describirHecho(Fact fact) {
    if (fact.action == 'ESCAPAR') {
      // Se dice quién escapó solo cuando está resuelto. Sin resolver no se
      // atribuye a nadie: la ficha invita a aclararlo.
      return switch (fact.actorRole) {
        ActorRole.suspect => 'Escapó: sospechoso',
        ActorRole.victim => 'Escapó: yo',
        ActorRole.thirdParty => 'Escapó: un tercero',
        ActorRole.unknown => fact.actorDetail != null &&
                fact.actorDetail!.isNotEmpty
            ? 'Escapó: ${fact.actorDetail}'
            : 'Escapó: falta aclarar quién',
      };
    }
    if (fact.lossType == 'loss') return 'Extravío de pertenencias';
    if (fact.lossType == 'theft') return 'Denuncia de robo / sustracción';
    return fact.action;
  }

  static Future<void> _reabrirEditorPersona(
      BuildContext context, WidgetRef ref, PersonEntity p) async {
    await reabrirEditorPersona(context, ref, p.id);
  }

  static Future<void> _reabrirEditorObjeto(
      BuildContext context, WidgetRef ref, ObjectInvolved o) async {
    if (o.concept == 'BILLETES' || o.concept == 'DINERO') {
      await mostrarEditorMontoDinero(context, ref, existingObjectId: o.id);
      return;
    }
    await reabrirEditorObjeto(context, ref, o.id);
  }
}

class _EntityChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const _EntityChip({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.09),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.40), width: 1.2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 220),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 4),
                Icon(Icons.edit, size: 13, color: color.withValues(alpha: 0.7)),
              ],
              if (onDelete != null) ...[
                const SizedBox(width: 6),
                InkWell(
                  onTap: onDelete,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.close, size: 12, color: color),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
