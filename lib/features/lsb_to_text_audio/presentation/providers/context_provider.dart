import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/semantic_context.dart';
import '../../domain/entities/semantic_zone.dart';

/// Catálogo de contextos situacionales — labels en primera persona,
/// IDs preservados porque el datasource de tarjetas los referencia.
///
/// Cada contexto declara zonas semánticas con peso base, urgencia
/// intrínseca y relaciones cruzadas. El [SemanticNavigationEngine]
/// usa esa información para ordenar y resaltar zonas en tiempo real.
///
/// Cada zona expone además una `question` — una pregunta guiada en
/// primera persona que se presenta al usuario sordo como prompt. Las
/// tarjetas (entrada visual-táctil definida en el perfil de proyecto)
/// son las que responden esa pregunta; el motor semántico encadena las
/// respuestas para construir el relato.
final availableContexts = <SemanticContext>[
  // ─── 1. ROBO ──────────────────────────────────────────
  SemanticContext(
    id: 'denuncia_robo',
    name: 'Denunciar robo',
    icon: 'warning_amber',
    emoji: '🚨',
    description: 'Me robaron / Hurto / Asalto',
    entryZoneId: 'situacion',
    baseUrgency: UrgencyLevel.medium,
    zones: const [
      SemanticZone(
        id: 'situacion',
        label: 'Situación',
        hint: 'Qué pasó',
        question: '¿Qué pasó?',
        emoji: '⚡',
        semanticWeight: 0.9,
        cardCategories: ['Agresión'],
        contextTags: [EmotionalTag.amenaza],
        relatedZones: ['personas', 'objetos', 'emergencia'],
      ),
      // Quién — sólo género / edad / relación / cantidad.
      SemanticZone(
        id: 'personas',
        label: 'Quién',
        hint: 'Tipo de persona',
        question: '¿Quién te robó?',
        emoji: '👤',
        semanticWeight: 0.85,
        cardCategories: ['Descripción'],
        cardSubcategories: ['Género', 'Edad', 'Relación', 'Cantidad'],
        strictContext: true,
        relatedZones: ['apariencia', 'vestimenta', 'situacion'],
      ),
      // Cómo era físicamente — altura, contextura, piel, cabello, marcas.
      // Acepta 2 cards: ej. ALTO + DELGADO, BARBA + LENTES.
      SemanticZone(
        id: 'apariencia',
        label: 'Apariencia',
        hint: 'Cómo era físicamente',
        question: '¿Cómo era físicamente?',
        emoji: '🧍',
        semanticWeight: 0.75,
        optional: true,
        cardCategories: ['Descripción'],
        cardSubcategories: ['Físico', 'Cabello', 'Marca'],
        strictContext: true,
        maxPicks: 3,
        relatedZones: ['vestimenta', 'personas'],
      ),
      SemanticZone(
        id: 'vestimenta',
        label: 'Vestimenta',
        hint: 'Qué llevaba puesto',
        question: '¿Qué ropa llevaba?',
        emoji: '👕',
        semanticWeight: 0.7,
        optional: true,
        cardCategories: ['Descripción'],
        cardSubcategories: ['Vestimenta', 'Color'],
        strictContext: true,
        maxPicks: 3,
        relatedZones: ['apariencia', 'personas'],
      ),
      SemanticZone(
        id: 'objetos',
        label: 'Objetos',
        hint: 'Qué se llevaron',
        question: '¿Qué se llevaron?',
        emoji: '📱',
        semanticWeight: 0.8,
        cardCategories: ['Objetos', 'Documentos'],
        strictContext: true,
        maxPicks: 3,
        relatedZones: ['situacion', 'lugar'],
      ),
      SemanticZone(
        id: 'lugar',
        label: 'Lugar',
        hint: 'Dónde fue',
        question: '¿Dónde ocurrió?',
        emoji: '📍',
        semanticWeight: 0.6,
        cardCategories: ['Lugares'],
        strictContext: true,
        relatedZones: ['tiempo'],
      ),
      SemanticZone(
        id: 'emergencia',
        label: 'Emergencia',
        hint: 'Estoy en peligro',
        question: '¿Necesitas ayuda urgente?',
        emoji: '🆘',
        semanticWeight: 0.3,
        urgencyLevel: UrgencyLevel.high,
        cardCategories: ['Estado/Urgencia', 'Servicios'],
        contextTags: [EmotionalTag.urgente, EmotionalTag.ayuda, EmotionalTag.peligro],
        relatedZones: ['situacion'],
      ),
      SemanticZone(
        id: 'tiempo',
        label: 'Tiempo',
        hint: 'Cuándo',
        question: '¿Cuándo pasó?',
        emoji: '🕐',
        semanticWeight: 0.4,
        optional: true,
        cardCategories: ['Tiempo'],
      ),
    ],
  ),

  // ─── 2. VIOLENCIA ─────────────────────────────────────
  SemanticContext(
    id: 'violencia',
    name: 'Denunciar violencia',
    icon: 'shield',
    emoji: '🛡️',
    description: 'Me agredieron / Me amenazaron / Abuso',
    entryZoneId: 'situacion',
    baseUrgency: UrgencyLevel.high,
    zones: const [
      SemanticZone(
        id: 'situacion',
        label: 'Situación',
        hint: 'Qué pasó',
        question: '¿Qué te hicieron?',
        emoji: '⚡',
        semanticWeight: 0.95,
        urgencyLevel: UrgencyLevel.medium,
        cardCategories: ['Agresión'],
        contextTags: [EmotionalTag.amenaza, EmotionalTag.peligro],
        relatedZones: ['emocion', 'personas', 'emergencia'],
      ),
      // Quién — tipo de persona / relación. Incluye pareja y familia para
      // cubrir violencia doméstica. Sólo identidad: los detalles físicos
      // viven en 'apariencia'/'vestimenta' para no inundar esta pregunta con
      // descriptores sueltos (gorra, negro, tatuaje…).
      SemanticZone(
        id: 'personas',
        label: 'Quién',
        hint: 'Tipo de persona',
        question: '¿Quién te agredió?',
        emoji: '👤',
        semanticWeight: 0.85,
        cardCategories: ['Identificación', 'Descripción'],
        cardSubcategories: ['Género', 'Edad', 'Relación', 'Cantidad', 'Familia'],
        strictContext: true,
        relatedZones: ['apariencia', 'vestimenta', 'situacion'],
      ),
      // Cómo era físicamente — altura, contextura, piel, cabello, marcas.
      SemanticZone(
        id: 'apariencia',
        label: 'Apariencia',
        hint: 'Cómo era físicamente',
        question: '¿Cómo era físicamente?',
        emoji: '🧍',
        semanticWeight: 0.6,
        optional: true,
        cardCategories: ['Descripción'],
        cardSubcategories: ['Físico', 'Cabello', 'Marca'],
        strictContext: true,
        maxPicks: 3,
        relatedZones: ['vestimenta', 'personas'],
      ),
      SemanticZone(
        id: 'vestimenta',
        label: 'Vestimenta',
        hint: 'Qué llevaba puesto',
        question: '¿Qué ropa llevaba?',
        emoji: '👕',
        semanticWeight: 0.55,
        optional: true,
        cardCategories: ['Descripción'],
        cardSubcategories: ['Vestimenta', 'Color'],
        strictContext: true,
        maxPicks: 3,
        relatedZones: ['apariencia', 'personas'],
      ),
      SemanticZone(
        id: 'emocion',
        label: 'Cómo me siento',
        hint: 'Estado emocional',
        question: '¿Cómo te sientes?',
        emoji: '💔',
        semanticWeight: 0.7,
        cardCategories: ['Emociones', 'Estado/Urgencia'],
        cardSubcategories: ['Negativa', 'Estado'],
        contextTags: [EmotionalTag.miedo, EmotionalTag.dolor],
        relatedZones: ['emergencia'],
      ),
      SemanticZone(
        id: 'emergencia',
        label: 'Necesito ayuda',
        hint: 'Estoy en peligro',
        question: '¿Necesitas ayuda urgente?',
        emoji: '🆘',
        semanticWeight: 0.5,
        urgencyLevel: UrgencyLevel.critical,
        cardCategories: ['Estado/Urgencia', 'Servicios'],
        contextTags: [EmotionalTag.urgente, EmotionalTag.ayuda],
      ),
      SemanticZone(
        id: 'lugar',
        label: 'Lugar',
        hint: 'Dónde fue',
        question: '¿Dónde ocurrió?',
        emoji: '📍',
        semanticWeight: 0.55,
        cardCategories: ['Lugares', 'Instituciones'],
      ),
      SemanticZone(
        id: 'tiempo',
        label: 'Tiempo',
        hint: 'Cuándo',
        question: '¿Cuándo pasó?',
        emoji: '🕐',
        semanticWeight: 0.35,
        optional: true,
        cardCategories: ['Tiempo'],
      ),
    ],
  ),

  // ─── 3. ACCIDENTE ─────────────────────────────────────
  SemanticContext(
    id: 'accidente',
    name: 'Reportar accidente',
    icon: 'car_crash',
    emoji: '🚗',
    description: 'Tránsito / Caída / Lesión / Emergencia médica',
    entryZoneId: 'situacion',
    baseUrgency: UrgencyLevel.high,
    zones: const [
      SemanticZone(
        id: 'situacion',
        label: 'Situación',
        hint: 'Qué pasó',
        question: '¿Qué pasó?',
        emoji: '⚡',
        semanticWeight: 0.9,
        cardCategories: ['Agresión'],
        relatedZones: ['estado', 'ayuda'],
      ),
      SemanticZone(
        id: 'estado',
        label: 'Cómo estoy',
        hint: 'Estado físico',
        question: '¿Cómo te encuentras?',
        emoji: '💔',
        semanticWeight: 0.85,
        urgencyLevel: UrgencyLevel.high,
        cardCategories: ['Emociones', 'Estado/Urgencia'],
        cardSubcategories: ['Negativa', 'Estado'],
        contextTags: [EmotionalTag.dolor, EmotionalTag.urgente],
        relatedZones: ['ayuda'],
      ),
      SemanticZone(
        id: 'ayuda',
        label: 'Ayuda',
        hint: 'Qué necesito',
        question: '¿Qué ayuda necesitas?',
        emoji: '🚑',
        semanticWeight: 0.7,
        urgencyLevel: UrgencyLevel.high,
        cardCategories: ['Servicios'],
        contextTags: [EmotionalTag.urgente, EmotionalTag.ayuda],
      ),
      SemanticZone(
        id: 'personas',
        label: 'Personas',
        hint: 'Quién estuvo',
        question: '¿Quién más estuvo involucrado?',
        emoji: '👤',
        semanticWeight: 0.5,
        cardCategories: ['Identificación', 'Descripción'],
      ),
      SemanticZone(
        id: 'lugar',
        label: 'Lugar',
        hint: 'Dónde fue',
        question: '¿Dónde ocurrió?',
        emoji: '📍',
        semanticWeight: 0.5,
        cardCategories: ['Lugares', 'Instituciones'],
      ),
    ],
  ),

  // NOTA: el contexto 'emergencia' se retiró de la selección (era demasiado
  // genérico; sus casos los cubren violencia/robo/accidente/orientación). Su
  // id sigue existiendo en datasource y motor; 'accidente' mantiene vivo el
  // compositor _composeEmergency.

  // ─── 4. DECLARAR COMO TESTIGO ─────────────────────────
  // (id 'otro' conservado por compatibilidad con datasource/motor)
  SemanticContext(
    id: 'otro',
    name: 'Declarar como testigo',
    icon: 'visibility',
    emoji: '👁️',
    description: 'Presencié un robo, violencia o accidente',
    entryZoneId: 'que',
    baseUrgency: UrgencyLevel.medium,
    zones: const [
      SemanticZone(
        id: 'que',
        label: 'Hecho',
        hint: 'Qué presencié',
        question: '¿Qué hecho presenciaste?',
        emoji: '⚡',
        semanticWeight: 0.85,
        cardCategories: ['Agresión'],
        relatedZones: ['personas', 'lugar'],
      ),
      SemanticZone(
        id: 'personas',
        label: 'Personas',
        hint: 'Quién estuvo involucrado',
        question: '¿Quién estuvo involucrado?',
        emoji: '👤',
        semanticWeight: 0.7,
        cardCategories: ['Identificación', 'Descripción'],
        relatedZones: ['lugar'],
      ),
      SemanticZone(
        id: 'lugar',
        label: 'Lugar',
        hint: 'Dónde ocurrió',
        question: '¿Dónde ocurrió?',
        emoji: '📍',
        semanticWeight: 0.6,
        cardCategories: ['Lugares', 'Instituciones'],
        relatedZones: ['tiempo'],
      ),
      SemanticZone(
        id: 'tiempo',
        label: 'Tiempo',
        hint: 'Cuándo',
        question: '¿Cuándo ocurrió?',
        emoji: '🕐',
        semanticWeight: 0.45,
        optional: true,
        cardCategories: ['Tiempo'],
      ),
    ],
  ),

  // ─── 5. ORIENTACIÓN Y TRÁMITES LEGALES ────────────────
  // Fusión de los antiguos contextos 'orientacion' + 'tramite_id' +
  // 'perdida'. Conserva el id 'orientacion'; las tarjetas de los tres
  // dominios se reúnen vía [kContextCardSources] y el ensamblador se enruta
  // por intención vía [resolveAssemblerContext] (motor y datasource intactos).
  SemanticContext(
    id: 'orientacion',
    name: 'Orientación y trámites legales',
    icon: 'balance',
    emoji: '⚖️',
    description: 'Documentos, pérdidas, antecedentes, consultas y derechos',
    entryZoneId: 'accion',
    zones: const [
      SemanticZone(
        id: 'accion',
        label: 'Acción',
        hint: 'Qué necesito hacer',
        question: '¿Qué necesitas hacer?',
        emoji: '📋',
        semanticWeight: 0.9,
        cardCategories: ['Acciones', 'Trámites'],
        relatedZones: ['documento', 'motivo'],
      ),
      SemanticZone(
        id: 'documento',
        label: 'Documento',
        hint: 'Qué documento',
        question: '¿Qué documento necesitas?',
        emoji: '📄',
        semanticWeight: 0.85,
        cardCategories: ['Documentos'],
        maxPicks: 2,
        relatedZones: ['motivo', 'donde'],
      ),
      SemanticZone(
        id: 'motivo',
        label: 'Motivo',
        hint: 'Para qué lo necesito',
        question: '¿Para qué lo necesitas?',
        emoji: '🎯',
        semanticWeight: 0.65,
        optional: true,
        cardCategories: ['Consultas'],
        relatedZones: ['donde'],
      ),
      SemanticZone(
        id: 'donde',
        label: 'Institución',
        hint: 'Ante qué institución',
        question: '¿Ante qué institución?',
        emoji: '🏛️',
        semanticWeight: 0.6,
        cardCategories: ['Instituciones'],
        relatedZones: ['apoyo'],
      ),
      SemanticZone(
        id: 'apoyo',
        label: 'Apoyo',
        hint: 'Qué apoyo necesito',
        question: '¿Necesitas apoyo?',
        emoji: '🤝',
        semanticWeight: 0.5,
        optional: true,
        cardCategories: ['Servicios'],
        cardSubcategories: ['Accesibilidad', 'Legal', 'Atención', 'Información'],
      ),
      SemanticZone(
        id: 'lugar',
        label: 'Lugar',
        hint: 'Dónde ocurrió',
        question: '¿Dónde ocurrió?',
        emoji: '📍',
        semanticWeight: 0.45,
        optional: true,
        cardCategories: ['Lugares'],
      ),
      SemanticZone(
        id: 'quien',
        label: 'Personas',
        hint: 'Para quién',
        question: '¿Para quién es el trámite?',
        emoji: '👤',
        semanticWeight: 0.4,
        optional: true,
        cardCategories: ['Identificación'],
      ),
      SemanticZone(
        id: 'tiempo',
        label: 'Plazo',
        hint: 'Cuándo / para cuándo',
        question: '¿Para cuándo lo necesitas?',
        emoji: '🕐',
        semanticWeight: 0.35,
        optional: true,
        cardCategories: ['Tiempo'],
      ),
    ],
  ),
];

/// Para contextos fusionados: ids de contexto de tarjeta que abarca cada
/// contexto de la UI. El contexto 'orientacion' reúne las tarjetas de los
/// antiguos 'orientacion', 'tramite_id' y 'perdida' sin tocar el datasource.
/// El resto de contextos usan su propio id.
const Map<String, List<String>> kContextCardSources = {
  'orientacion': ['orientacion', 'tramite_id', 'perdida'],
};

/// Ids de contexto de tarjeta que cubre [contextId] (para el filtro de
/// tarjetas). Por defecto, su propio id.
List<String> cardSourceContexts(String contextId) =>
    kContextCardSources[contextId] ?? [contextId];

/// Resuelve el `contextId` que se envía al ensamblador (motor de traducción
/// intacto) según las glosas seleccionadas. Solo el contexto fusionado
/// 'orientacion' se reenruta a su sub-dominio más fiel para preservar la
/// coherencia del compositor:
///   - objeto perdido / PERDER  → 'perdida'   (_composeLoss)
///   - documento / trámite      → 'tramite_id' (_composeProcedure)
///   - resto (consulta/derechos)→ 'orientacion' (_composeGuidance)
///
/// `cardCategoryOf` mapea una glosa a su categoría (vía catálogo) para no
/// duplicar conocimiento del léxico. Como el motor garantiza cobertura
/// (`_ensureCoverage`), un reenrutado imperfecto nunca pierde glosas.
String resolveAssemblerContext(
  String contextId,
  List<String> glosses,
  String? Function(String gloss) cardCategoryOf,
) {
  if (contextId != 'orientacion') return contextId;
  var hasObject = false;
  var hasDocOrProcedure = false;
  for (final g in glosses) {
    if (g.toUpperCase() == 'PERDER') hasObject = true;
    final cat = cardCategoryOf(g);
    if (cat == 'Objetos') hasObject = true;
    if (cat == 'Documentos' || cat == 'Trámites') hasDocOrProcedure = true;
  }
  if (hasObject) return 'perdida';
  if (hasDocOrProcedure) return 'tramite_id';
  return 'orientacion';
}

class ContextNotifier extends Notifier<SemanticContext?> {
  @override
  SemanticContext? build() => null;

  void setContext(SemanticContext context) {
    state = context;
  }

  void clearContext() {
    state = null;
  }
}

final contextProvider =
    NotifierProvider<ContextNotifier, SemanticContext?>(ContextNotifier.new);
