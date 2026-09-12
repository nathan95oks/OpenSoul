import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lsb_legal_app/app/app_theme.dart';
import 'package:lsb_legal_app/core/domain/entities/declaration_draft.dart';
import 'package:lsb_legal_app/core/domain/entities/lsb_card.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/denuncia_robo_draft_provider.dart';

/// Editores de entidades para `denuncia_robo` (auditoría 2026-09).
///
/// A diferencia de `qualifier_sheets.dart` (una glosa, un detalle), estas
/// hojas capturan relaciones: qué prenda y color son de qué persona, qué
/// papel cumple cada objeto, y de qué lugar es referencia una relación
/// espacial. Escriben en [denunciaRoboDraftProvider], no en la lista plana
/// de glosas.

const _placeConcepts = {'CALLE', 'AVENIDA', 'PLAZA', 'MERCADO', 'BARRIO', 'TIENDA', 'CASA', 'COCHABAMBA'};
const _relationConcepts = {'CERCA', 'LEJOS', 'DENTRO', 'FUERA', 'AL_LADO'};
const _vehicleConcepts = {'MICRO', 'TRUFI'};
const _clothingConcepts = {'POLERA', 'PANTALÓN', 'PANTALON', 'GORRA', 'CHAMARRA', 'LENTES', 'MOCHILA'};
const _genderConcepts = {'HOMBRE', 'MUJER'};
const _ageConcepts = {'JOVEN', 'ADULTO'};
const _buildConcepts = {'FLACO', 'GORDO'};
const _heightConcepts = {'ALTO', 'BAJO'};

/// Campo de texto libre que conserva exactamente lo escrito: espacios,
/// tildes, números y signos de una dirección. A diferencia del teclado
/// dactilológico (que deletrea letra por letra para el avatar), este texto
/// no se traduce a señas: viaja como dato literal.
Future<String?> mostrarTecladoTextoLibre(
  BuildContext context, {
  required String titulo,
  String? valorInicial,
}) {
  final controlador = TextEditingController(text: valorInicial ?? '');
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            20, 4, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(titulo,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            TextField(
              controller: controlador,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              maxLength: 80,
              decoration: const InputDecoration(
                hintText: 'Escribe aquí (se conservan espacios y tildes)',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(controlador.text.trim()),
              child: Text(controlador.text.trim().isEmpty ? 'Omitir' : 'Confirmar'),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<T?> _opciones<T>(
  BuildContext context, {
  required String titulo,
  required List<(String, T)> opciones,
}) {
  return showModalBottomSheet<T>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(titulo,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            for (final (label, value) in opciones)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: OutlinedButton(
                  onPressed: () => Navigator.of(ctx).pop(value),
                  child: Text(label),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------
// Lugar
// ---------------------------------------------------------------------

Future<void> mostrarEditorLugar(BuildContext context, WidgetRef ref, LsbCard card) async {
  final gloss = card.gloss.toUpperCase();
  final notifier = ref.read(denunciaRoboDraftProvider.notifier);

  if (_relationConcepts.contains(gloss)) {
    await _abrirRelacionEspacial(context, ref, gloss);
    return;
  }

  if (_vehicleConcepts.contains(gloss)) {
    notifier.setMainPlace(gloss);
    return;
  }

  if (_placeConcepts.contains(gloss)) {
    notifier.setMainPlace(gloss);
    if (gloss == 'CASA' || gloss == 'COCHABAMBA') return;
    if (!context.mounted) return;
    final detalle = await mostrarTecladoTextoLibre(
      context,
      titulo: '¿Nombre o referencia de ese lugar? (opcional)',
    );
    if (detalle != null && detalle.isNotEmpty) {
      notifier.setMainPlace(gloss, detail: detalle);
    }
  }
}

Future<void> _abrirRelacionEspacial(BuildContext context, WidgetRef ref, String relation) async {
  final notifier = ref.read(denunciaRoboDraftProvider.notifier);
  final relLabel = switch (relation) {
    'CERCA' => 'cerca',
    'LEJOS' => 'lejos',
    'DENTRO' => 'dentro',
    'FUERA' => 'fuera',
    'AL_LADO' => 'al lado',
    _ => relation.toLowerCase(),
  };
  notifier.setLocationRelation(relation);

  final draft = ref.read(denunciaRoboDraftProvider);
  final lugarPrevio = draft.location.mainPlaceConcept;

  final eleccion = await _opciones<String>(
    context,
    titulo: '¿${relLabel[0].toUpperCase()}${relLabel.substring(1)} de qué lugar?',
    opciones: [
      ('Mi casa', 'home'),
      if (lugarPrevio != null) ('El lugar ya indicado', 'previous'),
      ('Otro lugar (escribir)', 'other'),
      ('Todavía no lo sé — dejar pendiente', 'pending'),
    ],
  );

  if (eleccion == null || eleccion == 'pending') return;

  if (eleccion == 'home') {
    notifier.setLocationReference(referenceType: 'home');
    return;
  }
  if (eleccion == 'previous') {
    notifier.setLocationReference(
      referenceType: 'knownPlace',
      referenceConceptGloss: lugarPrevio,
    );
    return;
  }
  if (!context.mounted) return;
  final texto = await mostrarTecladoTextoLibre(
    context,
    titulo: '¿$relLabel de qué lugar? Escribe la referencia',
  );
  if (texto != null && texto.isNotEmpty) {
    notifier.setLocationReference(referenceType: 'other', referenceLiteralText: texto);
  }
}

// ---------------------------------------------------------------------
// Objetos
// ---------------------------------------------------------------------

Future<void> mostrarEditorObjeto(BuildContext context, WidgetRef ref, LsbCard card) async {
  final gloss = card.gloss.toUpperCase();
  final notifier = ref.read(denunciaRoboDraftProvider.notifier);
  final esVehiculo = _vehicleConcepts.contains(gloss);

  final rol = await _opciones<String>(
    context,
    titulo: '¿Qué pasó con ${card.displayText.toLowerCase()}?',
    opciones: [
      if (esVehiculo) ('Me lo robaron (vehículo sustraído)', 'stolen'),
      if (!esVehiculo) ('Me lo robaron', 'stolen'),
      if (!esVehiculo) ('Lo perdí', 'lost'),
      if (!esVehiculo) ('Lo llevaba la otra persona', 'carriedByOtherPerson'),
    ],
  );
  if (rol == null) return;

  final id = notifier.addObject(concept: gloss, role: rol);

  if (gloss == 'BILLETES' && rol != 'carriedByOtherPerson') {
    if (!context.mounted) return;
    final monto = await mostrarTecladoTextoLibre(
      context,
      titulo: '¿Cuánto dinero, si lo sabe? (opcional, solo números)',
    );
    if (monto != null && monto.isNotEmpty && RegExp(r'^\d+$').hasMatch(monto)) {
      notifier.setObjectDetail(id, quantity: monto, unit: 'bolivianos');
    }
  }
}

// ---------------------------------------------------------------------
// Persona
// ---------------------------------------------------------------------

Future<void> mostrarEditorPersona(BuildContext context, WidgetRef ref, LsbCard card) async {
  final gloss = card.gloss.toUpperCase();
  final notifier = ref.read(denunciaRoboDraftProvider.notifier);
  final draft = ref.read(denunciaRoboDraftProvider);

  final personId =
      draft.persons.isEmpty ? notifier.addPerson(role: 'suspect') : draft.persons.last.id;

  if (_genderConcepts.contains(gloss)) {
    notifier.updatePerson(personId, gender: gloss);
  } else if (_ageConcepts.contains(gloss)) {
    notifier.updatePerson(personId, ageApprox: gloss);
  } else if (_buildConcepts.contains(gloss)) {
    notifier.updatePerson(personId, build: gloss);
  } else if (_heightConcepts.contains(gloss)) {
    notifier.updatePerson(personId, height: gloss);
  } else if (_clothingConcepts.contains(gloss)) {
    final clothingId = notifier.addClothing(personId, gloss);
    if (!context.mounted) return;
    await _elegirColorPrenda(context, ref, personId, clothingId);
  }
}

Future<void> _elegirColorPrenda(
    BuildContext context, WidgetRef ref, String personId, String clothingId) async {
  final notifier = ref.read(denunciaRoboDraftProvider.notifier);
  final eleccion = await _opciones<String>(
    context,
    titulo: '¿De qué color?',
    opciones: const [
      ('Rojo', 'ROJO'),
      ('Negro', 'NEGRO'),
      ('Azul', 'AZUL'),
      ('Otro color (escribir)', 'OTHER'),
      ('No lo sé / no lo recuerdo', 'UNKNOWN'),
    ],
  );
  if (eleccion == null) return;

  if (eleccion == 'UNKNOWN') {
    notifier.setClothingColor(personId, clothingId, null,
        state1: ConfirmationState.uncertain);
    return;
  }
  if (eleccion == 'OTHER') {
    if (!context.mounted) return;
    final texto = await mostrarTecladoTextoLibre(context, titulo: 'Escribe el color');
    if (texto != null && texto.isNotEmpty) {
      notifier.setClothingColor(personId, clothingId, texto);
    }
    return;
  }
  notifier.setClothingColor(personId, clothingId, eleccion);
}

/// Permite agregar explícitamente una nueva persona sin reutilizar la
/// última (p. ej. al describir a un segundo sospechoso o testigo).
void agregarOtraPersona(WidgetRef ref) {
  ref.read(denunciaRoboDraftProvider.notifier).addPerson(role: 'suspect');
}

/// Resumen compacto de las personas ya descritas, para revisarlas o quitar
/// una sin afectar a las demás.
class PersonasDescritasResumen extends ConsumerWidget {
  const PersonasDescritasResumen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(denunciaRoboDraftProvider);
    if (draft.persons.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final p in draft.persons)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.lightSurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.lightBorder),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _resumenPersona(p),
                      style: const TextStyle(fontSize: 12.5),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    tooltip: 'Quitar esta persona',
                    onPressed: () =>
                        ref.read(denunciaRoboDraftProvider.notifier).removePerson(p.id),
                  ),
                ],
              ),
            ),
          TextButton.icon(
            onPressed: () => agregarOtraPersona(ref),
            icon: const Icon(Icons.person_add_alt, size: 16),
            label: const Text('Agregar otra persona'),
          ),
        ],
      ),
    );
  }

  String _resumenPersona(PersonEntity p) {
    final partes = <String>[
      if (p.gender != null) p.gender!,
      if (p.ageApprox != null) p.ageApprox!,
      if (p.build != null) p.build!,
      if (p.height != null) p.height!,
      for (final c in p.clothing)
        '${c.concept}${c.color != null ? " ${c.color}" : ""}',
    ];
    return partes.isEmpty ? 'Persona sin describir todavía' : partes.join(' · ');
  }
}
