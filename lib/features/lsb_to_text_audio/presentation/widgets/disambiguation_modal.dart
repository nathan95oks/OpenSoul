import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lsb_legal_app/app/app_theme.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/providers/denuncia_robo_draft_provider.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/presentation/widgets/app_toast_manager.dart';

/// Modal interactivo de desambiguación semántica para verbos y conceptos polisémicos o vagos.
/// Garantiza precisión antes de asentar un dato en el borrador de declaración.
class DisambiguationModal {
  // ---------------------------------------------------------------------------
  // 1. ESCAPAR: ¿Quién escapó?
  // ---------------------------------------------------------------------------
  static Future<void> desambiguarEscapar(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final eleccion = await _mostrarOpciones<(String, String?)>(
      context,
      titulo: '¿Quién escapó?',
      subtitulo: 'Indica quién realizó la acción de escapar o huir',
      icono: Icons.directions_run,
      opciones: [
        ('El agresor / sospechoso', ('suspect', null)),
        ('La víctima / Yo logré escapar', ('victim', null)),
        ('Un tercero / otra persona', ('thirdParty', null)),
        ('Escribir nombre o detalle…', ('other', null)),
      ],
    );

    if (eleccion == null) return;

    final notifier = ref.read(declarationDraftProvider.notifier);
    if (eleccion.$1 == 'other') {
      if (!context.mounted) return;
      final detalle = await _mostrarCampoTexto(
        context,
        titulo: '¿Quién escapó? Escribe el detalle',
        hint: 'Ej: El acompañante del agresor',
      );
      if (detalle != null && detalle.isNotEmpty) {
        notifier.setFactActor(
          action: 'ESCAPAR',
          actorRole: 'other',
          actorDetail: detalle,
        );
        if (context.mounted) {
          AppToastManager.showSuccess(context, 'Registrado: Escapó "$detalle"');
        }
      }
    } else {
      notifier.setFactActor(
        action: 'ESCAPAR',
        actorRole: eleccion.$1,
        actorDetail: eleccion.$2,
      );
      if (context.mounted) {
        final label = eleccion.$1 == 'suspect'
            ? 'El agresor escapó'
            : (eleccion.$1 == 'victim' ? 'El declarante escapó' : 'Un tercero escapó');
        AppToastManager.showSuccess(context, 'Registrado: $label');
      }
    }
  }

  // ---------------------------------------------------------------------------
  // 2. PERDER vs ROBAR: Tipificación sin falsa imputación de delito
  // ---------------------------------------------------------------------------
  static Future<void> desambiguarPerderVsRobar(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final eleccion = await _mostrarOpciones<String>(
      context,
      titulo: 'Aclaración de lo ocurrido con el objeto',
      subtitulo: '¿Fue un extravío de tu parte o sospechas de una sustracción?',
      icono: Icons.help_outline,
      opciones: const [
        ('Fue un extravío / pérdida mía', 'loss'),
        ('Sospecho de robo o sustracción', 'theft'),
        ('No lo sé con certeza / Desconozco', 'unknown'),
      ],
    );

    if (eleccion == null) return;

    final notifier = ref.read(declarationDraftProvider.notifier);
    notifier.setLossDisambiguation(lossType: eleccion);

    if (context.mounted) {
      final msg = eleccion == 'loss'
          ? 'Registrado como extravío personal'
          : (eleccion == 'theft'
              ? 'Registrado como presunta sustracción'
              : 'Registrado con certeza pendiente');
      AppToastManager.showInfo(context, msg);
    }
  }

  // ---------------------------------------------------------------------------
  // 3. PAPEL: Especificación de documento o trámite
  // ---------------------------------------------------------------------------
  static Future<void> desambiguarPapel(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final eleccion = await _mostrarOpciones<String>(
      context,
      titulo: '¿Qué tipo de papel o documento es?',
      subtitulo: 'Selecciona la categoría exacta para el acta formal',
      icono: Icons.description,
      opciones: const [
        ('Documento de identidad (C.I.)', 'Carnet de Identidad (C.I.)'),
        ('Trámite policial o judicial', 'Trámite policial/judicial'),
        ('Factura o recibo comercial', 'Factura/Recibo'),
        ('Certificado médico o legal', 'Certificado'),
        ('Otro documento (escribir)', 'OTRO'),
      ],
    );

    if (eleccion == null) return;

    final notifier = ref.read(declarationDraftProvider.notifier);
    if (eleccion == 'OTRO') {
      if (!context.mounted) return;
      final texto = await _mostrarCampoTexto(
        context,
        titulo: 'Escribe el nombre o tipo de documento',
        hint: 'Ej: Título de propiedad, Licencia',
      );
      if (texto != null && texto.isNotEmpty) {
        notifier.addObject(
          concept: 'PAPEL',
          role: 'evidenceSupport',
          docType: texto,
        );
        if (context.mounted) {
          AppToastManager.showSuccess(context, 'Documento registrado: $texto');
        }
      }
    } else {
      notifier.addObject(
        concept: 'PAPEL',
        role: 'evidenceSupport',
        docType: eleccion,
      );
      if (context.mounted) {
        AppToastManager.showSuccess(context, 'Documento registrado: $eleccion');
      }
    }
  }

  // ---------------------------------------------------------------------------
  // 4. IDENTIDAD: Desglose específico
  // ---------------------------------------------------------------------------
  static Future<void> desambiguarIdentidad(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final eleccion = await _mostrarOpciones<String>(
      context,
      titulo: '¿Qué documento de identidad presenta?',
      subtitulo: 'Indica el documento oficial de acreditación personal',
      icono: Icons.badge,
      opciones: const [
        ('Carnet de Identidad (C.I.)', 'Carnet de Identidad (C.I.)'),
        ('Licencia de Conducir', 'Licencia de Conducir'),
        ('Pasaporte', 'Pasaporte'),
        ('Certificado de Nacimiento', 'Certificado de Nacimiento'),
      ],
    );

    if (eleccion == null) return;

    final notifier = ref.read(declarationDraftProvider.notifier);
    notifier.addObject(
      concept: 'IDENTIDAD',
      role: 'evidenceSupport',
      docType: eleccion,
    );

    if (context.mounted) {
      AppToastManager.showSuccess(context, 'Identificación: $eleccion');
    }
  }

  // ---------------------------------------------------------------------------
  // 5. CAJA / BOLSA: Contenido interior y rol
  // ---------------------------------------------------------------------------
  static Future<void> desambiguarCajaBolsa(
    BuildContext context,
    WidgetRef ref,
    String concept,
  ) async {
    final rol = await _mostrarOpciones<String>(
      context,
      titulo: '¿Qué función cumple la ${concept.toLowerCase()}?',
      subtitulo: 'Indica si fue sustraída o es una evidencia que presenta',
      icono: Icons.shopping_bag,
      opciones: [
        ('Me la robaron / fue sustraída', 'stolen'),
        ('La perdí / extravío', 'lost'),
        ('Es una evidencia que traigo', 'evidenceSupport'),
        ('La llevaba la otra persona', 'carriedByOtherPerson'),
      ],
    );

    if (rol == null) return;

    if (!context.mounted) return;
    final contenido = await _mostrarCampoTexto(
      context,
      titulo: '¿Qué contenía en su interior?',
      hint: 'Ej: Herramientas, ropa, dinero, papeles personales',
    );

    final notifier = ref.read(declarationDraftProvider.notifier);
    notifier.addObject(
      concept: concept,
      role: rol,
      contents: contenido,
    );

    if (context.mounted) {
      AppToastManager.showSuccess(
        context,
        '${concept[0].toUpperCase()}${concept.substring(1).toLowerCase()} registrada con su contenido',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // 6. MICRO / TRUFI: Función semántica
  // ---------------------------------------------------------------------------
  static Future<void> desambiguarTransporteVehiculo(
    BuildContext context,
    WidgetRef ref,
    String vehicleConcept,
  ) async {
    final eleccion = await _mostrarOpciones<String>(
      context,
      titulo: '¿Cuál es la función del ${vehicleConcept.toLowerCase()}?',
      subtitulo: 'Aclara si fue el lugar donde ocurrió el hecho o si fue robado',
      icono: Icons.directions_bus,
      opciones: [
        ('Ocurrió dentro / es el transporte público', 'transport'),
        ('Es el vehículo robado / sustraído', 'stolen'),
      ],
    );

    if (eleccion == null) return;

    final notifier = ref.read(declarationDraftProvider.notifier);
    if (eleccion == 'transport') {
      notifier.setMainPlace(vehicleConcept, isVehicleTransport: true);
      notifier.setLocationRelation('DENTRO');
      notifier.setLocationReference(
        referenceType: 'conceptCard',
        referenceConceptGloss: vehicleConcept,
        isVehicleTransport: true,
      );
      if (context.mounted) {
        AppToastManager.showSuccess(
          context,
          'Lugar fijado: Dentro de un ${vehicleConcept.toLowerCase()}',
        );
      }
    } else {
      notifier.addObject(concept: vehicleConcept, role: 'stolen');
      if (context.mounted) {
        AppToastManager.showSuccess(
          context,
          'Vehículo ${vehicleConcept.toLowerCase()} registrado como sustraído',
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers de Diálogo / BottomSheet
  // ---------------------------------------------------------------------------
  static Future<T?> _mostrarOpciones<T>(
    BuildContext context, {
    required String titulo,
    required String subtitulo,
    required IconData icono,
    required List<(String, T)> opciones,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.brandPrimary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icono,
                        color: AppTheme.brandPrimary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          titulo,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.lightText,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitulo,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.lightTextSub,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              for (final (label, value) in opciones)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Material(
                    color: AppTheme.lightBg,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => Navigator.of(ctx).pop(value),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: AppTheme.lightBorder, width: 1.2),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                label,
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.lightText,
                                ),
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios,
                                size: 14, color: AppTheme.lightTextSub),
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
    );
  }

  static Future<String?> _mostrarCampoTexto(
    BuildContext context, {
    required String titulo,
    String? hint,
  }) {
    final controller = TextEditingController();
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppTheme.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
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
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: hint ?? 'Escribe aquí…',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  filled: true,
                  fillColor: AppTheme.lightBg,
                ),
                onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
              ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  controller.text.trim().isEmpty ? 'Confirmar' : 'Guardar detalle',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
