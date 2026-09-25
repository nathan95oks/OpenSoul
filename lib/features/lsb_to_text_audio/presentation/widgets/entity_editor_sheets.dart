import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lsb_legal_app/app/app_theme.dart';
import 'package:lsb_legal_app/core/domain/entities/declaration_draft.dart';
import 'package:lsb_legal_app/core/domain/entities/lsb_card.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/denuncia_robo_draft_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/widgets/amount_input_sheet.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/widgets/app_toast_manager.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/widgets/disambiguation_modal.dart';

/// Editores de entidades jerárquicas y desambiguación interactiva.
///
/// Gestiona la captura estructurada de:
/// - Personas con prendas y colores anidados (aislados por entidad y prenda).
/// - Objetos con roles, subtipos y contenidos (PAPEL, IDENTIDAD, CAJA/BOLSA).
/// - Lugares con anclas y relaciones espaciales (CERCA, LEJOS, DENTRO de transporte).

const _placeConcepts = {
  'CALLE',
  'AVENIDA',
  'PLAZA',
  'MERCADO',
  'BARRIO',
  'TIENDA',
  'CASA',
  'COCHABAMBA'
};
const _relationConcepts = {'CERCA', 'LEJOS', 'DENTRO', 'FUERA', 'AL_LADO'};
const _vehicleConcepts = {'MICRO', 'TRUFI'};
const _clothingConcepts = {
  'POLERA',
  'PANTALÓN',
  'PANTALON',
  'GORRA',
  'CHAMARRA',
  'LENTES',
  'MOCHILA'
};
const _genderConcepts = {'HOMBRE', 'MUJER'};
const _ageConcepts = {'JOVEN', 'ADULTO'};
const _buildConcepts = {'FLACO', 'GORDO'};
const _heightConcepts = {'ALTO', 'BAJO'};

/// Abre el teclado de texto libre accesible con preservación de tildes y mayúsculas.
Future<String?> mostrarTecladoTextoLibre(
  BuildContext context, {
  required String titulo,
  String? valorInicial,
  String? hint,
}) {
  final controlador = TextEditingController(text: valorInicial ?? '');
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppTheme.lightSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => StatefulBuilder(
      // El botón necesita su propio rebuild al teclear: sin el
      // StatefulBuilder, `controlador.text` cambiaba pero el botón —
      // calculado una sola vez al construirse la hoja— se quedaba diciendo
      // "Omitir" para siempre, aunque ya hubiera un nombre escrito listo
      // para confirmar.
      builder: (ctx, setModalState) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
              20, 4, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                titulo,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.lightText,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controlador,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                maxLength: 80,
                decoration: InputDecoration(
                  hintText: hint ?? 'Escribe aquí (se conservan espacios y tildes)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  filled: true,
                  fillColor: AppTheme.lightBg,
                ),
                onChanged: (_) => setModalState(() {}),
                onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
              ),
              const SizedBox(height: 10),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(controlador.text.trim()),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  controlador.text.trim().isEmpty ? 'Omitir' : 'Continuar',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
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
    isScrollControlled: true,
    backgroundColor: AppTheme.lightSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppTheme.lightText,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.55,
              ),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (final (label, value) in opciones)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Material(
                          color: AppTheme.lightBg,
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => Navigator.of(ctx).pop(value),
                            child: Container(
                              height: 56,
                              padding: const EdgeInsets.symmetric(horizontal: 18),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppTheme.lightBorder, width: 1.2),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      label,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.lightText,
                                      ),
                                    ),
                                  ),
                                  const Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    size: 14,
                                    color: Color(0xFF7C3AED),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// -----------------------------------------------------------------------------
// LUGAR & RELACIONES ESPACIALES
// -----------------------------------------------------------------------------

Future<void> mostrarEditorLugar(
    BuildContext context, WidgetRef ref, LsbCard card) async {
  final gloss = card.gloss.toUpperCase();
  final notifier = ref.read(declarationDraftProvider.notifier);

  if (_relationConcepts.contains(gloss)) {
    await _abrirRelacionEspacial(context, ref, gloss);
    return;
  }

  if (_vehicleConcepts.contains(gloss)) {
    await DisambiguationModal.desambiguarTransporteVehiculo(
        context, ref, gloss);
    return;
  }

  if (_placeConcepts.contains(gloss)) {
    notifier.setMainPlace(gloss);
    if (gloss == 'CASA' || gloss == 'COCHABAMBA') {
      AppToastManager.showSuccess(context, 'Lugar fijado: $gloss');
      return;
    }
    if (!context.mounted) return;
    final detalle = await mostrarTecladoTextoLibre(
      context,
      titulo: '¿Nombre o referencia de ese lugar? (opcional)',
      hint: 'Ej: Mercado Calatayud, Calle San Martín',
    );
    if (detalle != null && detalle.isNotEmpty) {
      notifier.setMainPlace(gloss, detail: detalle);
      if (context.mounted) {
        AppToastManager.showSuccess(context, 'Lugar registrado: $detalle');
      }
    } else if (context.mounted) {
      AppToastManager.showSuccess(context, 'Lugar registrado: $gloss');
    }
  }
}

Future<void> _abrirRelacionEspacial(
    BuildContext context, WidgetRef ref, String relation) async {
  final notifier = ref.read(declarationDraftProvider.notifier);
  final relLabel = switch (relation) {
    'CERCA' => 'cerca',
    'LEJOS' => 'lejos',
    'DENTRO' => 'dentro',
    'FUERA' => 'fuera',
    'AL_LADO' => 'al lado',
    _ => relation.toLowerCase(),
  };
  notifier.setLocationRelation(relation);

  final draft = ref.read(declarationDraftProvider);
  final lugarPrevio = draft.location.mainPlaceConcept;

  final eleccion = await _opciones<String>(
    context,
    titulo: '¿${relLabel[0].toUpperCase()}${relLabel.substring(1)} de qué lugar?',
    opciones: [
      ('Mi casa', 'home'),
      if (lugarPrevio != null) ('El lugar ya indicado ($lugarPrevio)', 'previous'),
      ('Otro lugar / referencia (escribir)', 'other'),
      ('Todavía no lo sé — dejar pendiente', 'pending'),
    ],
  );

  if (eleccion == null || eleccion == 'pending') return;

  if (eleccion == 'home') {
    notifier.setLocationReference(referenceType: 'home');
    if (context.mounted) {
      AppToastManager.showSuccess(context, 'Referencia: $relLabel de mi casa');
    }
    return;
  }
  if (eleccion == 'previous') {
    notifier.setLocationReference(
      referenceType: 'knownPlace',
      referenceConceptGloss: lugarPrevio,
    );
    if (context.mounted) {
      AppToastManager.showSuccess(
          context, 'Referencia: $relLabel de $lugarPrevio');
    }
    return;
  }
  if (!context.mounted) return;
  final texto = await mostrarTecladoTextoLibre(
    context,
    titulo: '¿$relLabel de qué lugar? Escribe la referencia',
    hint: 'Ej: Mercado Calatayud, Cancha, Hospital Viedma',
  );
  if (texto != null && texto.isNotEmpty) {
    notifier.setLocationReference(
        referenceType: 'other', referenceLiteralText: texto);
    if (context.mounted) {
      AppToastManager.showSuccess(context, 'Referencia: $relLabel de $texto');
    }
  }
}

// -----------------------------------------------------------------------------
// OBJETOS & CATEGORIZACIÓN CONDICIONAL
// -----------------------------------------------------------------------------

Future<void> mostrarEditorObjeto(
    BuildContext context, WidgetRef ref, LsbCard card) async {
  final gloss = card.gloss.toUpperCase();
  final notifier = ref.read(declarationDraftProvider.notifier);

  // 1. PAPEL
  if (gloss == 'PAPEL') {
    await DisambiguationModal.desambiguarPapel(context, ref);
    return;
  }

  // 2. IDENTIDAD
  if (gloss == 'IDENTIDAD') {
    await DisambiguationModal.desambiguarIdentidad(context, ref);
    return;
  }

  // 3. CAJA / BOLSA
  if (gloss == 'CAJA' || gloss == 'BOLSA' || gloss == 'MOCHILA') {
    await DisambiguationModal.desambiguarCajaBolsa(context, ref, gloss);
    return;
  }

  // 4. MICRO / TRUFI
  if (_vehicleConcepts.contains(gloss)) {
    await DisambiguationModal.desambiguarTransporteVehiculo(
        context, ref, gloss);
    return;
  }

  // 5. BILLETES / DINERO
  if (gloss == 'BILLETES' || gloss == 'DINERO') {
    await mostrarEditorMontoDinero(context, ref);
    return;
  }

  // 6. Otros objetos genéricos (CELULAR, MOCHILA, etc.)
  final rol = await _opciones<String>(
    context,
    titulo: '¿Qué pasó con ${card.displayText.toLowerCase()}?',
    opciones: const [
      ('Me lo robaron', 'stolen'),
      ('Lo perdí / extravié', 'lost'),
      ('Lo llevaba la otra persona', 'carriedByOtherPerson'),
      ('Es una evidencia que tengo', 'evidenceSupport'),
    ],
  );
  if (rol == null) return;

  notifier.addObject(concept: gloss, role: rol);
  if (context.mounted) {
    AppToastManager.showSuccess(
      context,
      '${card.displayText} agregado al relato',
    );
  }
}

// -----------------------------------------------------------------------------
// WIZARD SECUENCIAL DE DESCRIPCIÓN DE PERSONA (PASOS JERÁRQUICOS 1 -> 2 -> 3 -> 4)
// -----------------------------------------------------------------------------

/// Abre el Wizard Guiado Secuencial Estricto para describir a una persona.
///
/// Paso 1: Género / Identidad principal (Hombre, Mujer, Omitir) -> Avanza al Paso 2.
/// Paso 2: Rango de Edad (Niño/a, Joven, Adulto/a, Anciano/a, Omitir) -> Avanza al Paso 3.
/// Paso 3: Complexión y Estatura (Alto/a, Bajo/a, Delgado/a, Robusto/a, Omitir) -> Avanza al Paso 4.
/// Paso 4: Vestimenta y Accesorios (Chamarra, Polera, Pantalón, Gorra, Lentes, Mochila) -> Abre selector de color específico.
Future<void> mostrarEditorPersona(
    BuildContext context, WidgetRef ref, LsbCard card) async {
  await ejecutarWizardSecuencialPersona(
    context,
    ref,
    initialConcept: card.gloss.toUpperCase(),
  );
}

Future<void> ejecutarWizardSecuencialPersona(
  BuildContext context,
  WidgetRef ref, {
  String? personId,
  int startStep = 1,
  String role = 'suspect',
  String? initialConcept,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppTheme.lightSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => _PersonSequentialWizardSheet(
      personId: personId,
      startStep: startStep,
      role: role,
      initialConcept: initialConcept,
    ),
  );
}

class _PersonSequentialWizardSheet extends ConsumerStatefulWidget {
  final String? personId;
  final int startStep;
  final String role;
  final String? initialConcept;

  const _PersonSequentialWizardSheet({
    this.personId,
    this.startStep = 1,
    this.role = 'suspect',
    this.initialConcept,
  });

  @override
  ConsumerState<_PersonSequentialWizardSheet> createState() =>
      _PersonSequentialWizardSheetState();
}

class _PersonSequentialWizardSheetState
    extends ConsumerState<_PersonSequentialWizardSheet> {
  late String _personId;
  int _currentStep = 1;
  // Al elegir una vez alto/bajo o flaco/gordo se oculta el otro extremo del
  // mismo grupo; volver a tocar la opción elegida reabre el par para poder
  // cambiarla, sin necesitar un estado "sin elegir" en el borrador.
  bool _editarEstatura = false;
  bool _editarComplexion = false;

  @override
  void initState() {
    super.initState();
    _currentStep = widget.startStep;

    final draft = ref.read(declarationDraftProvider);
    final esPersonaNueva =
        widget.personId == null && !(draft.persons.isNotEmpty && widget.initialConcept == null);

    if (widget.personId != null) {
      _personId = widget.personId!;
    } else if (draft.persons.isNotEmpty && widget.initialConcept == null) {
      _personId = draft.persons.last.id;
    } else {
      // No se puede mutar el provider aquí sin conocer antes el id: se
      // genera localmente (solo lectura, sin tocar el estado) y la
      // creación real en el draft se hace en el primer frame ya montado.
      // `build()` ya sabe mostrar una PersonEntity local con este id
      // mientras tanto (ver más abajo).
      _personId = 'p_${DateTime.now().microsecondsSinceEpoch}_${identityHashCode(this)}';
    }

    String? genero, edad, complexion, estatura;
    if (widget.initialConcept != null) {
      final gloss = widget.initialConcept!.toUpperCase();
      if (_genderConcepts.contains(gloss)) {
        genero = gloss;
        _currentStep = 2;
      } else if (_ageConcepts.contains(gloss)) {
        edad = gloss;
        _currentStep = 3;
      } else if (_buildConcepts.contains(gloss)) {
        complexion = gloss;
        _currentStep = 4;
      } else if (_heightConcepts.contains(gloss)) {
        estatura = gloss;
        _currentStep = 4;
      } else if (_clothingConcepts.contains(gloss)) {
        _currentStep = 4;
      }
    }

    // Mutar `declarationDraftProvider` en pleno `initState` puede coincidir
    // con el montaje de esta hoja modal mientras otros widgets que también
    // lo observan (ConfiguredEntityChips, LiveDeclarationPreviewPanel,
    // GuidedWizardStepper) siguen en su propio paso de construcción, lo que
    // dispara "Tried to modify a provider while the widget tree was
    // building". Se difiere la escritura al primer frame ya renderizado.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final notifier = ref.read(declarationDraftProvider.notifier);
      if (esPersonaNueva) {
        notifier.addPerson(role: widget.role, id: _personId);
      }
      if (genero != null) notifier.updatePerson(_personId, gender: genero);
      if (edad != null) notifier.updatePerson(_personId, ageApprox: edad);
      if (complexion != null) notifier.updatePerson(_personId, build: complexion);
      if (estatura != null) notifier.updatePerson(_personId, height: estatura);
    });
  }

  void _irAlPaso(int paso) {
    if (paso < 1 || paso > 4) return;
    setState(() => _currentStep = paso);
  }

  void _seleccionarGenero(String? genero) {
    final notifier = ref.read(declarationDraftProvider.notifier);
    if (genero != null) {
      notifier.updatePerson(_personId, gender: genero);
      AppToastManager.showSuccess(context, 'Género: $genero');
    }
    _irAlPaso(2);
  }

  void _seleccionarEdad(String? edad) {
    final notifier = ref.read(declarationDraftProvider.notifier);
    if (edad != null) {
      notifier.updatePerson(_personId, ageApprox: edad);
      AppToastManager.showSuccess(context, 'Edad: $edad');
    }
    _irAlPaso(3);
  }

  void _seleccionarRasgoFisico({String? estatura, String? complexion}) {
    final notifier = ref.read(declarationDraftProvider.notifier);
    if (estatura != null) {
      notifier.updatePerson(_personId, height: estatura);
      AppToastManager.showSuccess(context, 'Estatura: $estatura');
    }
    if (complexion != null) {
      notifier.updatePerson(_personId, build: complexion);
      AppToastManager.showSuccess(context, 'Complexión: $complexion');
    }
    // Estatura y complexión son ejes independientes (alguien puede ser alto
    // Y flaco a la vez): elegir uno ya no avanza de paso solo, para que se
    // pueda completar el otro eje antes de seguir con "SIGUIENTE PASO".
    setState(() {
      if (estatura != null) _editarEstatura = false;
      if (complexion != null) _editarComplexion = false;
    });
  }

  Future<void> _agregarPrenda(String concept) async {
    final notifier = ref.read(declarationDraftProvider.notifier);
    final clothingId = notifier.addClothing(_personId, concept);
    await _elegirColorPrenda(context, ref, _personId, clothingId, concept);
    if (mounted) setState(() {});
  }

  void _finalizar() {
    AppToastManager.showSuccess(
        context, 'Descripción de la persona guardada correctamente');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(declarationDraftProvider);
    final person = draft.persons.where((p) => p.id == _personId).firstOrNull ??
        PersonEntity(id: _personId, role: widget.role);

    return SafeArea(
      child: ConstrainedBox(
        // Sin este tope, la hoja crecía con el contenido del paso (por
        // ejemplo varias prendas agregadas) y los botones de navegación —
        // incluido "FINALIZAR DESCRIPCIÓN" — terminaban fuera de la pantalla,
        // alcanzables solo si se sabía que había que seguir desplazándose.
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Barra de Pasos Secuenciales (1 ➔ 2 ➔ 3 ➔ 4) — fija.
              _WizardStepIndicator(
                currentStep: _currentStep,
                onStepTap: (step) {
                  if (step <= _currentStep) _irAlPaso(step);
                },
              ),

              const SizedBox(height: 16),

              // Único tramo que se desplaza: el contenido propio del paso
              // activo. Los botones de abajo quedan siempre visibles.
              Flexible(
                child: SingleChildScrollView(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: switch (_currentStep) {
                      1 => _buildPaso1Genero(person),
                      2 => _buildPaso2Edad(person),
                      3 => _buildPaso3Rasgos(person),
                      _ => _buildPaso4Vestimenta(person),
                    },
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Botones de Navegación del Wizard (fijos)
              Row(
                children: [
                  if (_currentStep > 1) ...[
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: OutlinedButton.icon(
                          onPressed: () => _irAlPaso(_currentStep - 1),
                          icon: const Icon(Icons.arrow_back_rounded, size: 18),
                          label: const Text(
                            'ANTERIOR',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.lightTextSub,
                            side: const BorderSide(color: AppTheme.lightBorder),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    flex: _currentStep == 4 ? 2 : 1,
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _currentStep == 4
                            ? _finalizar
                            : () => _irAlPaso(_currentStep + 1),
                        icon: Icon(
                          _currentStep == 4
                              ? Icons.check_circle_outline
                              : Icons.arrow_forward_rounded,
                          size: 20,
                        ),
                        label: Text(
                          _currentStep == 4
                              ? 'FINALIZAR DESCRIPCIÓN'
                              : 'SIGUIENTE PASO',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF660066),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---- PASO 1: GÉNERO / IDENTIDAD PRINCIPAL ---------------------------------
  Widget _buildPaso1Genero(PersonEntity person) {
    return Column(
      key: const ValueKey('paso1'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _StepHeader(
          title: 'Paso 1: Género / Identidad',
          subtitle: 'Selecciona la identidad principal de la persona',
          icon: Icons.person_search_rounded,
        ),
        const SizedBox(height: 16),
        _OptionTile(
          icon: Icons.man_rounded,
          label: 'Hombre',
          isSelected: person.gender?.toUpperCase() == 'HOMBRE',
          onTap: () => _seleccionarGenero('HOMBRE'),
        ),
        const SizedBox(height: 10),
        _OptionTile(
          icon: Icons.woman_rounded,
          label: 'Mujer',
          isSelected: person.gender?.toUpperCase() == 'MUJER',
          onTap: () => _seleccionarGenero('MUJER'),
        ),
        const SizedBox(height: 10),
        _OptionTile(
          icon: Icons.help_outline_rounded,
          label: 'No identificado / Omitir',
          isSelected: person.gender == null,
          isSecondary: true,
          onTap: () => _seleccionarGenero(null),
        ),
      ],
    );
  }

  // ---- PASO 2: RANGO DE EDAD -----------------------------------------------
  Widget _buildPaso2Edad(PersonEntity person) {
    return Column(
      key: const ValueKey('paso2'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _StepHeader(
          title: 'Paso 2: Rango de Edad',
          subtitle: '¿Qué edad aproximada tenía la persona?',
          icon: Icons.cake_outlined,
        ),
        const SizedBox(height: 16),
        _OptionTile(
          icon: Icons.child_care_rounded,
          label: 'Niño / Niña',
          isSelected: person.ageApprox?.toUpperCase() == 'NIÑO',
          onTap: () => _seleccionarEdad('NIÑO'),
        ),
        const SizedBox(height: 10),
        _OptionTile(
          icon: Icons.person_rounded,
          label: 'Joven',
          isSelected: person.ageApprox?.toUpperCase() == 'JOVEN',
          onTap: () => _seleccionarEdad('JOVEN'),
        ),
        const SizedBox(height: 10),
        _OptionTile(
          icon: Icons.person_2_rounded,
          label: 'Adulto / Adulta',
          isSelected: person.ageApprox?.toUpperCase() == 'ADULTO',
          onTap: () => _seleccionarEdad('ADULTO'),
        ),
        const SizedBox(height: 10),
        _OptionTile(
          icon: Icons.elderly_rounded,
          label: 'Anciano / Anciana (Adulto mayor)',
          isSelected: person.ageApprox?.toUpperCase() == 'ANCIANO',
          onTap: () => _seleccionarEdad('ANCIANO'),
        ),
        const SizedBox(height: 10),
        _OptionTile(
          icon: Icons.help_outline_rounded,
          label: 'No recuerdo / Omitir edad',
          isSelected: person.ageApprox == null,
          isSecondary: true,
          onTap: () => _seleccionarEdad(null),
        ),
      ],
    );
  }

  // ---- PASO 3: COMPLEXIÓN Y ESTATURA ---------------------------------------
  Widget _buildPaso3Rasgos(PersonEntity person) {
    final estatura = person.height?.toUpperCase();
    final complexion = person.build?.toUpperCase();

    return Column(
      key: const ValueKey('paso3'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _StepHeader(
          title: 'Paso 3: Complexión y Estatura',
          subtitle: 'Opcional: puedes elegir una estatura y una complexión',
          icon: Icons.accessibility_new_rounded,
        ),
        const SizedBox(height: 18),
        const _GroupLabel('ESTATURA'),
        const SizedBox(height: 8),
        _buildParExclusivo(
          valorActual: estatura,
          mostrarAmbas: _editarEstatura,
          onReabrir: () => setState(() => _editarEstatura = true),
          opciones: const [
            ('ALTO', 'Alto / Alta', Icons.height_rounded),
            ('BAJO', 'Bajo / Baja', Icons.vertical_align_bottom_rounded),
          ],
          onSeleccionar: (v) => _seleccionarRasgoFisico(estatura: v),
        ),
        const SizedBox(height: 18),
        const _GroupLabel('COMPLEXIÓN'),
        const SizedBox(height: 8),
        _buildParExclusivo(
          valorActual: complexion,
          mostrarAmbas: _editarComplexion,
          onReabrir: () => setState(() => _editarComplexion = true),
          opciones: const [
            ('FLACO', 'Delgado / Delgada', Icons.accessibility_rounded),
            ('GORDO', 'Robusto / Robusta', Icons.accessibility_new_rounded),
          ],
          onSeleccionar: (v) => _seleccionarRasgoFisico(complexion: v),
        ),
      ],
    );
  }

  /// Un par de opciones mutuamente excluyentes ("Alto"/"Bajo",
  /// "Flaco"/"Gordo"): mientras no haya elección, o mientras se esté
  /// reabriendo para cambiarla, se muestran ambas; en cuanto se elige una,
  /// la otra desaparece y solo queda la elegida (tocarla de nuevo la reabre).
  Widget _buildParExclusivo({
    required String? valorActual,
    required bool mostrarAmbas,
    required VoidCallback onReabrir,
    required List<(String, String, IconData)> opciones,
    required ValueChanged<String> onSeleccionar,
  }) {
    if (valorActual == null || mostrarAmbas) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (valor, etiqueta, icono) in opciones) ...[
            _OptionTile(
              icon: icono,
              label: etiqueta,
              isSelected: valorActual == valor,
              onTap: () => onSeleccionar(valor),
            ),
            if (opciones.last.$1 != valor) const SizedBox(height: 10),
          ],
        ],
      );
    }
    final elegido = opciones.firstWhere((o) => o.$1 == valorActual);
    return _OptionTile(
      icon: elegido.$3,
      label: '${elegido.$2}  ·  toca para cambiar',
      isSelected: true,
      onTap: onReabrir,
    );
  }

  // ---- PASO 4: VESTIMENTA Y ACCESORIOS CON SELECTOR DE COLOR INMEDIATO -----
  Widget _buildPaso4Vestimenta(PersonEntity person) {
    final notifier = ref.read(declarationDraftProvider.notifier);

    const prendasDisponibles = [
      ('Chamarra', 'CHAMARRA', Icons.dry_cleaning_rounded),
      ('Polera', 'POLERA', Icons.checkroom_rounded),
      ('Pantalón', 'PANTALÓN', Icons.accessibility_rounded),
      ('Gorra', 'GORRA', Icons.sports_baseball_rounded),
      ('Lentes', 'LENTES', Icons.visibility_rounded),
      ('Mochila', 'MOCHILA', Icons.backpack_rounded),
    ];

    return Column(
      key: const ValueKey('paso4'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _StepHeader(
          title: 'Paso 4: Vestimenta y Accesorios',
          subtitle:
              'Elige las prendas y define su color visual específico',
          icon: Icons.checkroom_rounded,
        ),
        const SizedBox(height: 14),

        // Grilla de Prendas Seleccionables
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.2,
          children: [
            for (final (nombre, concept, icon) in prendasDisponibles)
              Material(
                color: AppTheme.lightBg,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _agregarPrenda(concept),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppTheme.lightBorder,
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF7C3AED).withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(icon, color: const Color(0xFF7C3AED), size: 18),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            nombre,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.lightText,
                            ),
                          ),
                        ),
                        const Icon(Icons.add_circle_outline,
                            size: 18, color: Color(0xFF7C3AED)),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),

        const SizedBox(height: 16),

        // Lista de Prendas Agregadas
        if (person.clothing.isNotEmpty) ...[
          const Text(
            'PRENDAS REGISTRADAS:',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: AppTheme.lightTextSub,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in person.clothing)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF660066).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFFC084FC).withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${c.concept.toLowerCase()}${c.color != null ? " (${c.color})" : ""}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF660066),
                        ),
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () {
                          notifier.removeClothing(_personId, c.id);
                          setState(() {});
                        },
                        child: const Icon(Icons.close, size: 15, color: Color(0xFF660066)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.lightBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.lightBorder),
            ),
            child: const Text(
              'Toca una prenda para agregarla y asignarle su color.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                fontStyle: FontStyle.italic,
                color: AppTheme.lightTextSub,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _GroupLabel extends StatelessWidget {
  final String label;
  const _GroupLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
        color: AppTheme.lightTextSub,
      ),
    );
  }
}

class _StepHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _StepHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  static const _purple = Color(0xFF7C3AED);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _purple.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: _purple, size: 22),
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppTheme.lightText,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 12.5,
            color: AppTheme.lightTextSub,
          ),
        ),
      ],
    );
  }
}

class _WizardStepIndicator extends StatelessWidget {
  final int currentStep;
  final ValueChanged<int> onStepTap;

  const _WizardStepIndicator({
    required this.currentStep,
    required this.onStepTap,
  });

  static const _purple = Color(0xFF7C3AED);
  static const _purpleDark = Color(0xFF660066);

  @override
  Widget build(BuildContext context) {
    const pasos = [
      (1, 'Género'),
      (2, 'Edad'),
      (3, 'Rasgos'),
      (4, 'Ropa'),
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < pasos.length; i++) ...[
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => onStepTap(pasos[i].$1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                gradient: pasos[i].$1 == currentStep
                    ? const LinearGradient(
                        colors: [_purple, _purpleDark],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: pasos[i].$1 == currentStep
                    ? null
                    : (pasos[i].$1 < currentStep
                        ? _purple.withValues(alpha: 0.15)
                        : AppTheme.lightBg),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: pasos[i].$1 == currentStep
                      ? const Color(0xFFC084FC)
                      : (pasos[i].$1 < currentStep
                          ? _purple
                          : AppTheme.lightBorder),
                  width: pasos[i].$1 == currentStep ? 1.5 : 1.0,
                ),
                boxShadow: pasos[i].$1 == currentStep
                    ? [
                        BoxShadow(
                          color: _purple.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (pasos[i].$1 < currentStep)
                    const Icon(Icons.check, size: 12, color: _purple)
                  else
                    Text(
                      '${pasos[i].$1}.',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: pasos[i].$1 == currentStep
                            ? Colors.white
                            : AppTheme.lightTextSub,
                      ),
                    ),
                  const SizedBox(width: 4),
                  Text(
                    pasos[i].$2,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: pasos[i].$1 == currentStep
                          ? Colors.white
                          : (pasos[i].$1 < currentStep
                              ? _purple
                              : AppTheme.lightTextSub),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (i < pasos.length - 1)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Icon(
                Icons.arrow_forward_ios_rounded,
                size: 9,
                color: pasos[i].$1 < currentStep ? _purple : AppTheme.lightBorder,
              ),
            ),
        ],
      ],
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final bool isSecondary;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.label,
    this.isSelected = false,
    this.isSecondary = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(
                    colors: [Color(0xFF7C3AED), Color(0xFF660066)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isSelected
                ? null
                : (isSecondary ? AppTheme.lightSurface : AppTheme.lightBg),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFFC084FC)
                  : AppTheme.lightBorder,
              width: isSelected ? 2.2 : 1.2,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF7C3AED).withValues(alpha: 0.40),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 22,
                color: isSelected
                    ? Colors.white
                    : (isSecondary ? AppTheme.lightTextSub : const Color(0xFF7C3AED)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                    color: isSelected
                        ? Colors.white
                        : (isSecondary ? AppTheme.lightTextSub : AppTheme.lightText),
                  ),
                ),
              ),
              Icon(
                isSelected ? Icons.check_circle_rounded : Icons.arrow_forward_ios_rounded,
                size: isSelected ? 22 : 14,
                color: isSelected ? const Color(0xFFC084FC) : AppTheme.lightTextSub,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _elegirColorPrenda(
  BuildContext context,
  WidgetRef ref,
  String personId,
  String clothingId,
  String clothingConcept,
) async {
  final notifier = ref.read(declarationDraftProvider.notifier);

  const colores = [
    ('Negro', 'NEGRO', Color(0xFF0F172A)),
    ('Azul', 'AZUL', Color(0xFF2563EB)),
    ('Rojo', 'ROJO', Color(0xFFDC2626)),
    ('Blanco', 'BLANCO', Color(0xFFF8FAFC)),
    ('Verde', 'VERDE', Color(0xFF16A34A)),
    ('Café / Marrón', 'CAFÉ', Color(0xFF78350F)),
    ('Gris / Plomo', 'GRIS', Color(0xFF64748B)),
    ('Amarillo', 'AMARILLO', Color(0xFFEAB308)),
    ('Naranja', 'NARANJA', Color(0xFFEA580C)),
    ('Morado / Violeta', 'MORADO', Color(0xFF9333EA)),
  ];

  final eleccion = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: AppTheme.lightSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '¿De qué color era la ${clothingConcept.toLowerCase()}?',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppTheme.lightText,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Selecciona el color visual para una descripción formal exacta',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                color: AppTheme.lightTextSub,
              ),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                for (final (label, value, color) in colores)
                  Material(
                    color: AppTheme.lightBg,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => Navigator.of(ctx).pop(value),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: AppTheme.lightBorder, width: 1.2),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: color == const Color(0xFFF8FAFC)
                                      ? Colors.grey.shade400
                                      : Colors.transparent,
                                  width: 1,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              label,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.lightText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop('UNKNOWN'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      side: const BorderSide(color: AppTheme.lightBorder),
                    ),
                    child: const Text(
                      'No recuerdo / Omitir',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.lightTextSub,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop('OTHER'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      side: const BorderSide(color: Color(0xFF7C3AED)),
                    ),
                    child: const Text(
                      'Escribir otro…',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF7C3AED),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  if (eleccion == null) return;
  if (eleccion == 'UNKNOWN') {
    notifier.setClothingColor(personId, clothingId, null,
        state1: ConfirmationState.uncertain);
    if (context.mounted) {
      AppToastManager.showInfo(
          context, 'Prenda ${clothingConcept.toLowerCase()} registrada sin color');
    }
    return;
  }
  if (eleccion == 'OTHER') {
    if (!context.mounted) return;
    final texto = await mostrarTecladoTextoLibre(
      context,
      titulo: 'Escribe el color de la ${clothingConcept.toLowerCase()}',
      hint: 'Ej: Mostaza, Celeste, Beige',
    );
    if (texto != null && texto.isNotEmpty) {
      notifier.setClothingColor(personId, clothingId, texto);
      if (context.mounted) {
        AppToastManager.showSuccess(
            context, 'Color $texto asignado a $clothingConcept');
      }
    }
    return;
  }

  notifier.setClothingColor(personId, clothingId, eleccion);
  if (context.mounted) {
    AppToastManager.showSuccess(
        context, 'Color $eleccion asignado a $clothingConcept');
  }
}

/// Permite agregar explícitamente una nueva persona sin reutilizar la última.
void agregarOtraPersona(WidgetRef ref) {
  ref.read(declarationDraftProvider.notifier).addPerson(role: 'suspect');
}

/// Resumen visual interactivo de las personas ya descritas.
class PersonasDescritasResumen extends ConsumerWidget {
  const PersonasDescritasResumen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(declarationDraftProvider);
    if (draft.persons.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'PERSONAS DESCRITAS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.lightTextSub,
                  letterSpacing: 0.8,
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  agregarOtraPersona(ref);
                  AppToastManager.showInfo(context, 'Nueva persona agregada');
                },
                icon: const Icon(Icons.person_add_alt_1, size: 15),
                label: const Text('Otra persona',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (var i = 0; i < draft.persons.length; i++)
            _PersonaCard(
              index: i + 1,
              person: draft.persons[i],
              onDelete: () => ref
                  .read(declarationDraftProvider.notifier)
                  .removePerson(draft.persons[i].id),
              onAddClothing: () async {
                final eleccion = await _opciones<String>(
                  context,
                  titulo: '¿Qué prenda o accesorio llevaba?',
                  opciones: const [
                    ('Chamarra', 'CHAMARRA'),
                    ('Polera', 'POLERA'),
                    ('Pantalón', 'PANTALÓN'),
                    ('Gorra', 'GORRA'),
                    ('Lentes', 'LENTES'),
                    ('Mochila', 'MOCHILA'),
                  ],
                );
                if (eleccion != null && context.mounted) {
                  final cid = ref
                      .read(declarationDraftProvider.notifier)
                      .addClothing(draft.persons[i].id, eleccion);
                  await _elegirColorPrenda(
                      context, ref, draft.persons[i].id, cid, eleccion);
                }
              },
            ),
        ],
      ),
    );
  }
}

class _PersonaCard extends StatelessWidget {
  final int index;
  final PersonEntity person;
  final VoidCallback onDelete;
  final VoidCallback onAddClothing;

  const _PersonaCard({
    required this.index,
    required this.person,
    required this.onDelete,
    required this.onAddClothing,
  });

  @override
  Widget build(BuildContext context) {
    final traits = <String>[
      if (person.gender != null) person.gender!,
      if (person.ageApprox != null) person.ageApprox!,
      if (person.build != null) person.build!,
      if (person.height != null) person.height!,
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.lightSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.lightBorder, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Persona $index (${person.role == "suspect" ? "Sospechoso" : person.role})',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF7C3AED),
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18),
                color: AppTheme.errorLight,
                tooltip: 'Quitar persona',
                onPressed: onDelete,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            traits.isEmpty
                ? 'Rasgos físicos pendientes'
                : 'Rasgos: ${traits.join(" · ")}',
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
          ),
          if (person.clothing.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final c in person.clothing)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.lightBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.lightBorder),
                    ),
                    child: Text(
                      '${c.concept}: ${c.color ?? "sin color"}',
                      style: const TextStyle(
                          fontSize: 11.5, fontWeight: FontWeight.w700),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 6),
          TextButton.icon(
            onPressed: onAddClothing,
            icon: const Icon(Icons.add, size: 14),
            label: const Text('Agregar prenda / color',
                style: TextStyle(fontSize: 11.5)),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 24),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// REAPERTURA DE ENTIDADES DESDE FICHAS VISUALES (CHIPS)
// -----------------------------------------------------------------------------

Future<void> reabrirEditorLugar(BuildContext context, WidgetRef ref) async {
  final draft = ref.read(declarationDraftProvider);
  final notifier = ref.read(declarationDraftProvider.notifier);

  final eleccion = await _opciones<String>(
    context,
    titulo: '¿Qué deseas modificar del lugar?',
    opciones: [
      if (draft.location.relation != null)
        ('Modificar la referencia espacial (${draft.location.relation})', 'relation'),
      ('Escribir o cambiar el nombre/detalle del lugar', 'detail'),
      ('Restablecer lugar', 'clear'),
    ],
  );

  if (eleccion == 'relation' && draft.location.relation != null) {
    if (context.mounted) {
      await _abrirRelacionEspacial(context, ref, draft.location.relation!);
    }
  } else if (eleccion == 'detail') {
    if (!context.mounted) return;
    final detalle = await mostrarTecladoTextoLibre(
      context,
      titulo: 'Nombre o referencia del lugar',
      hint: 'Ej: Mercado Calatayud, Calle San Martín',
    );
    if (detalle != null && detalle.isNotEmpty) {
      notifier.setMainPlace(draft.location.mainPlaceConcept ?? 'LUGAR', detail: detalle);
      if (context.mounted) {
        AppToastManager.showSuccess(context, 'Lugar actualizado: $detalle');
      }
    }
  } else if (eleccion == 'clear') {
    notifier.clearLocationReference();
    if (context.mounted) {
      AppToastManager.showInfo(context, 'Referencia de lugar restablecida');
    }
  }
}

Future<void> reabrirEditorPersona(
    BuildContext context, WidgetRef ref, String personId) async {
  await ejecutarWizardSecuencialPersona(context, ref, personId: personId);
}

Future<void> reabrirEditorObjeto(
    BuildContext context, WidgetRef ref, String objectId) async {
  final draft = ref.read(declarationDraftProvider);
  final notifier = ref.read(declarationDraftProvider.notifier);
  final o = draft.objects.firstWhere(
    (e) => e.id == objectId,
    orElse: () => ObjectInvolved(id: objectId, concept: 'OBJETO', role: 'stolen'),
  );

  final gloss = o.concept.toUpperCase();
  if (gloss == 'BILLETES' || gloss == 'DINERO') {
    await mostrarEditorMontoDinero(context, ref,
        existingObjectId: objectId, initialRole: o.role);
    return;
  }
  if (gloss == 'PAPEL') {
    await DisambiguationModal.desambiguarPapel(context, ref);
    return;
  }
  if (gloss == 'IDENTIDAD') {
    await DisambiguationModal.desambiguarIdentidad(context, ref);
    return;
  }
  if (gloss == 'CAJA' || gloss == 'BOLSA' || gloss == 'MOCHILA') {
    await DisambiguationModal.desambiguarCajaBolsa(context, ref, gloss);
    return;
  }
  if (_vehicleConcepts.contains(gloss)) {
    await DisambiguationModal.desambiguarTransporteVehiculo(context, ref, gloss);
    return;
  }

  final rol = await _opciones<String>(
    context,
    titulo: 'Modificar objeto: ${o.concept}',
    opciones: const [
      ('Marcar como Robado / Sustraído', 'stolen'),
      ('Marcar como Extraviado / Perdido', 'lost'),
      ('Marcar como Evidencia / Prueba', 'evidenceSupport'),
    ],
  );
  if (rol != null && context.mounted) {
    notifier.setObjectDetail(objectId, role: rol);
    AppToastManager.showSuccess(context, 'Objeto actualizado');
  }
}
