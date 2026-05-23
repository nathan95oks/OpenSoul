import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/semantic_context.dart';
import '../../domain/entities/semantic_zone.dart';

/// Catálogo de contextos situacionales — labels en primera persona,
/// IDs preservados porque el datasource de tarjetas los referencia.
///
/// Cada contexto declara zonas semánticas con peso base, urgencia
/// intrínseca y relaciones cruzadas. El [SemanticNavigationEngine]
/// usa esa información para ordenar y resaltar zonas en tiempo real.
final availableContexts = <SemanticContext>[
  // ─── 1. ROBO ──────────────────────────────────────────
  SemanticContext(
    id: 'denuncia_robo',
    name: 'Me robaron',
    icon: 'warning_amber',
    emoji: '🚨',
    description: 'Me quitaron algo / Hurto',
    entryZoneId: 'situacion',
    baseUrgency: UrgencyLevel.medium,
    zones: const [
      SemanticZone(
        id: 'situacion',
        label: 'Situación',
        hint: 'Qué pasó',
        emoji: '⚡',
        semanticWeight: 0.9,
        cardCategories: ['Agresión', 'Acciones', 'Estado/Urgencia'],
        contextTags: [EmotionalTag.amenaza],
        relatedZones: ['personas', 'objetos', 'emergencia'],
      ),
      SemanticZone(
        id: 'personas',
        label: 'Personas',
        hint: 'Quién estuvo',
        emoji: '👤',
        semanticWeight: 0.8,
        cardCategories: ['Identificación', 'Descripción'],
        relatedZones: ['situacion', 'lugar'],
      ),
      SemanticZone(
        id: 'objetos',
        label: 'Objetos',
        hint: 'Qué se llevaron',
        emoji: '📱',
        semanticWeight: 0.8,
        cardCategories: ['Objetos', 'Documentos'],
        relatedZones: ['situacion', 'lugar'],
      ),
      SemanticZone(
        id: 'lugar',
        label: 'Lugar',
        hint: 'Dónde fue',
        emoji: '📍',
        semanticWeight: 0.6,
        cardCategories: ['Lugares', 'Instituciones'],
        relatedZones: ['tiempo'],
      ),
      SemanticZone(
        id: 'emergencia',
        label: 'Emergencia',
        hint: 'Estoy en peligro',
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
    name: 'Sufrí violencia',
    icon: 'shield',
    emoji: '🛡️',
    description: 'Me golpearon / Me amenazaron',
    entryZoneId: 'situacion',
    baseUrgency: UrgencyLevel.high,
    zones: const [
      SemanticZone(
        id: 'situacion',
        label: 'Situación',
        hint: 'Qué pasó',
        emoji: '⚡',
        semanticWeight: 0.95,
        urgencyLevel: UrgencyLevel.medium,
        cardCategories: ['Agresión', 'Acciones', 'Estado/Urgencia'],
        contextTags: [EmotionalTag.amenaza, EmotionalTag.peligro],
        relatedZones: ['emocion', 'personas', 'emergencia'],
      ),
      SemanticZone(
        id: 'personas',
        label: 'Personas',
        hint: 'Quién fue',
        emoji: '👤',
        semanticWeight: 0.85,
        cardCategories: ['Identificación', 'Descripción'],
        relatedZones: ['situacion', 'lugar'],
      ),
      SemanticZone(
        id: 'emocion',
        label: 'Cómo me siento',
        hint: 'Estado emocional',
        emoji: '💔',
        semanticWeight: 0.7,
        cardCategories: ['Emociones', 'Estado/Urgencia'],
        contextTags: [EmotionalTag.miedo, EmotionalTag.dolor],
        relatedZones: ['emergencia'],
      ),
      SemanticZone(
        id: 'emergencia',
        label: 'Necesito ayuda',
        hint: 'Estoy en peligro',
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
        emoji: '📍',
        semanticWeight: 0.55,
        cardCategories: ['Lugares', 'Instituciones'],
      ),
      SemanticZone(
        id: 'tiempo',
        label: 'Tiempo',
        hint: 'Cuándo',
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
    name: 'Tuve un accidente',
    icon: 'car_crash',
    emoji: '🚗',
    description: 'Tránsito / Caída / Golpe',
    entryZoneId: 'situacion',
    baseUrgency: UrgencyLevel.high,
    zones: const [
      SemanticZone(
        id: 'situacion',
        label: 'Situación',
        hint: 'Qué pasó',
        emoji: '⚡',
        semanticWeight: 0.9,
        cardCategories: ['Acciones', 'Agresión', 'Estado/Urgencia'],
        relatedZones: ['estado', 'ayuda'],
      ),
      SemanticZone(
        id: 'estado',
        label: 'Cómo estoy',
        hint: 'Estado físico',
        emoji: '💔',
        semanticWeight: 0.85,
        urgencyLevel: UrgencyLevel.high,
        cardCategories: ['Emociones', 'Estado/Urgencia'],
        contextTags: [EmotionalTag.dolor, EmotionalTag.urgente],
        relatedZones: ['ayuda'],
      ),
      SemanticZone(
        id: 'ayuda',
        label: 'Ayuda',
        hint: 'Qué necesito',
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
        emoji: '👤',
        semanticWeight: 0.5,
        cardCategories: ['Identificación', 'Descripción'],
      ),
      SemanticZone(
        id: 'lugar',
        label: 'Lugar',
        hint: 'Dónde fue',
        emoji: '📍',
        semanticWeight: 0.5,
        cardCategories: ['Lugares', 'Instituciones'],
      ),
    ],
  ),

  // ─── 4. EMERGENCIA ────────────────────────────────────
  SemanticContext(
    id: 'emergencia',
    name: 'Es una emergencia',
    icon: 'local_hospital',
    emoji: '🏥',
    description: 'Necesito ayuda urgente',
    entryZoneId: 'estado',
    baseUrgency: UrgencyLevel.critical,
    zones: const [
      SemanticZone(
        id: 'estado',
        label: 'Cómo estoy',
        hint: 'Mi condición',
        emoji: '🆘',
        semanticWeight: 0.95,
        urgencyLevel: UrgencyLevel.critical,
        cardCategories: ['Estado/Urgencia', 'Emociones'],
        contextTags: [EmotionalTag.dolor, EmotionalTag.urgente, EmotionalTag.peligro],
        relatedZones: ['ayuda'],
      ),
      SemanticZone(
        id: 'ayuda',
        label: 'Ayuda',
        hint: 'Qué necesito',
        emoji: '🚑',
        semanticWeight: 0.9,
        urgencyLevel: UrgencyLevel.critical,
        cardCategories: ['Servicios'],
        contextTags: [EmotionalTag.urgente, EmotionalTag.ayuda],
      ),
      SemanticZone(
        id: 'personas',
        label: 'Personas',
        hint: 'Quién necesita ayuda',
        emoji: '👤',
        semanticWeight: 0.65,
        cardCategories: ['Identificación', 'Descripción'],
      ),
      SemanticZone(
        id: 'lugar',
        label: 'Lugar',
        hint: 'Dónde estoy',
        emoji: '📍',
        semanticWeight: 0.6,
        cardCategories: ['Lugares', 'Instituciones'],
      ),
    ],
  ),

  // ─── 5. DOCUMENTOS / CARNET ───────────────────────────
  SemanticContext(
    id: 'tramite_id',
    name: 'Quiero un documento',
    icon: 'badge',
    emoji: '🪪',
    description: 'Carnet / Certificado / Trámite',
    entryZoneId: 'accion',
    zones: const [
      SemanticZone(
        id: 'accion',
        label: 'Acción',
        hint: 'Qué quiero hacer',
        emoji: '📋',
        semanticWeight: 0.9,
        cardCategories: ['Acciones', 'Trámites'],
        relatedZones: ['documento'],
      ),
      SemanticZone(
        id: 'documento',
        label: 'Documento',
        hint: 'Qué documento',
        emoji: '📄',
        semanticWeight: 0.85,
        cardCategories: ['Documentos'],
        relatedZones: ['donde'],
      ),
      SemanticZone(
        id: 'donde',
        label: 'Lugar',
        hint: 'En qué institución',
        emoji: '🏛️',
        semanticWeight: 0.6,
        cardCategories: ['Instituciones'],
      ),
      SemanticZone(
        id: 'quien',
        label: 'Personas',
        hint: 'Para quién',
        emoji: '👤',
        semanticWeight: 0.4,
        optional: true,
        cardCategories: ['Identificación'],
      ),
    ],
  ),

  // ─── 6. ORIENTACIÓN / DERECHOS ────────────────────────
  SemanticContext(
    id: 'orientacion',
    name: 'Necesito orientación',
    icon: 'balance',
    emoji: '⚖️',
    description: 'Intérprete / Derechos / Consulta',
    entryZoneId: 'necesidad',
    zones: const [
      SemanticZone(
        id: 'necesidad',
        label: 'Necesidad',
        hint: 'Qué busco',
        emoji: '🔎',
        semanticWeight: 0.9,
        cardCategories: ['Servicios', 'Acciones', 'Consultas'],
        relatedZones: ['donde'],
      ),
      SemanticZone(
        id: 'donde',
        label: 'Lugar',
        hint: 'Dónde ir',
        emoji: '🏛️',
        semanticWeight: 0.6,
        cardCategories: ['Instituciones'],
      ),
      SemanticZone(
        id: 'quien',
        label: 'Personas',
        hint: 'Para quién',
        emoji: '👤',
        semanticWeight: 0.4,
        optional: true,
        cardCategories: ['Identificación'],
      ),
    ],
  ),

  // ─── 7. PERDÍ ALGO ────────────────────────────────────
  SemanticContext(
    id: 'perdida',
    name: 'Perdí algo',
    icon: 'search_off',
    emoji: '📋',
    description: 'Documento / Celular / Objeto',
    entryZoneId: 'objetos',
    baseUrgency: UrgencyLevel.low,
    zones: const [
      SemanticZone(
        id: 'objetos',
        label: 'Objetos',
        hint: 'Qué perdí',
        emoji: '📱',
        semanticWeight: 0.9,
        cardCategories: ['Objetos', 'Documentos'],
        relatedZones: ['lugar'],
      ),
      SemanticZone(
        id: 'lugar',
        label: 'Lugar',
        hint: 'Dónde lo perdí',
        emoji: '📍',
        semanticWeight: 0.7,
        cardCategories: ['Lugares', 'Instituciones'],
      ),
      SemanticZone(
        id: 'tiempo',
        label: 'Tiempo',
        hint: 'Cuándo',
        emoji: '🕐',
        semanticWeight: 0.5,
        optional: true,
        cardCategories: ['Tiempo'],
      ),
      SemanticZone(
        id: 'ayuda',
        label: 'Ayuda',
        hint: 'Qué necesito',
        emoji: '🆘',
        semanticWeight: 0.45,
        optional: true,
        cardCategories: ['Servicios', 'Acciones'],
        contextTags: [EmotionalTag.ayuda],
      ),
    ],
  ),

  // ─── 8. OTRA SITUACIÓN ────────────────────────────────
  SemanticContext(
    id: 'otro',
    name: 'Otra situación',
    icon: 'chat',
    emoji: '💬',
    description: 'Quiero comunicar otra cosa',
    entryZoneId: 'que',
    zones: const [
      SemanticZone(
        id: 'que',
        label: 'Acción',
        hint: 'Qué necesito',
        emoji: '⚡',
        semanticWeight: 0.85,
        cardCategories: ['Acciones', 'Servicios', 'Trámites', 'Consultas'],
        relatedZones: ['detalle'],
      ),
      SemanticZone(
        id: 'detalle',
        label: 'Detalle',
        hint: 'Más contexto',
        emoji: '📌',
        semanticWeight: 0.5,
        optional: true,
        cardCategories: [
          'Documentos',
          'Instituciones',
          'Identificación',
          'Lugares',
          'Objetos',
          'Tiempo',
        ],
      ),
    ],
  ),
];

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
