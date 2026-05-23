import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/semantic_context.dart';

/// 8 contextos situacionales basados en escenarios reales de
/// defensorías, comisarías y oficinas administrativas en Bolivia.
final availableContexts = [
  // ─────────────────────────────────────────────
  // 1. ROBO O HURTO
  // ─────────────────────────────────────────────
  SemanticContext(
    id: 'denuncia_robo',
    name: 'Robo o Hurto',
    icon: 'warning_amber',
    emoji: '🚨',
    description: 'Me quitaron algo / Me robaron',
    defaultSteps: [
      GuidedStep(id: 'situacion', label: 'Situación', hint: 'Qué pasó', emoji: '⚡', targetCategories: ['Agresión', 'Acciones', 'Estado/Urgencia']),
      GuidedStep(id: 'personas', label: 'Personas', hint: 'Quién estuvo', emoji: '👤', targetCategories: ['Identificación', 'Descripción']),
      GuidedStep(id: 'objetos', label: 'Objetos', hint: 'Qué cosas', emoji: '📱', targetCategories: ['Objetos', 'Documentos']),
      GuidedStep(id: 'lugar', label: 'Lugar', hint: 'Dónde fue', emoji: '📍', targetCategories: ['Lugares', 'Instituciones']),
      GuidedStep(id: 'tiempo', label: 'Tiempo', hint: 'Cuándo', emoji: '🕐', targetCategories: ['Tiempo'], isOptional: true),
    ],
  ),

  // ─────────────────────────────────────────────
  // 2. VIOLENCIA O AGRESIÓN
  // ─────────────────────────────────────────────
  SemanticContext(
    id: 'violencia',
    name: 'Violencia o Agresión',
    icon: 'shield',
    emoji: '🛡️',
    description: 'Me golpearon / Me amenazaron',
    defaultSteps: [
      GuidedStep(id: 'situacion', label: 'Situación', hint: 'Qué pasó', emoji: '⚡', targetCategories: ['Agresión', 'Acciones', 'Estado/Urgencia']),
      GuidedStep(id: 'personas', label: 'Personas', hint: 'Quién fue', emoji: '👤', targetCategories: ['Identificación', 'Descripción']),
      GuidedStep(id: 'emociones', label: 'Estado', hint: 'Cómo estás', emoji: '💔', targetCategories: ['Emociones', 'Estado/Urgencia']),
      GuidedStep(id: 'lugar', label: 'Lugar', hint: 'Dónde fue', emoji: '📍', targetCategories: ['Lugares', 'Instituciones']),
      GuidedStep(id: 'tiempo', label: 'Tiempo', hint: 'Cuándo', emoji: '🕐', targetCategories: ['Tiempo'], isOptional: true),
    ],
  ),

  // ─────────────────────────────────────────────
  // 3. ACCIDENTE
  // ─────────────────────────────────────────────
  SemanticContext(
    id: 'accidente',
    name: 'Accidente',
    icon: 'car_crash',
    emoji: '🚗',
    description: 'Accidente de tránsito / Caída / Golpe',
    defaultSteps: [
      GuidedStep(id: 'situacion', label: 'Situación', hint: 'Qué pasó', emoji: '⚡', targetCategories: ['Acciones', 'Agresión', 'Estado/Urgencia']),
      GuidedStep(id: 'estado', label: 'Estado', hint: 'Cómo estás', emoji: '💔', targetCategories: ['Emociones', 'Estado/Urgencia']),
      GuidedStep(id: 'personas', label: 'Personas', hint: 'Quién estuvo', emoji: '👤', targetCategories: ['Identificación', 'Descripción']),
      GuidedStep(id: 'lugar', label: 'Lugar', hint: 'Dónde fue', emoji: '📍', targetCategories: ['Lugares', 'Instituciones']),
      GuidedStep(id: 'ayuda', label: 'Ayuda', hint: 'Qué necesitas', emoji: '🆘', targetCategories: ['Servicios'], isOptional: true),
    ],
  ),

  // ─────────────────────────────────────────────
  // 4. EMERGENCIA
  // ─────────────────────────────────────────────
  SemanticContext(
    id: 'emergencia',
    name: 'Emergencia',
    icon: 'local_hospital',
    emoji: '🏥',
    description: 'Necesito ayuda urgente / Ambulancia',
    defaultSteps: [
      GuidedStep(id: 'estado', label: 'Estado', hint: 'Cómo estás', emoji: '🆘', targetCategories: ['Estado/Urgencia', 'Emociones']),
      GuidedStep(id: 'personas', label: 'Personas', hint: 'Quién necesita ayuda', emoji: '👤', targetCategories: ['Identificación', 'Descripción']),
      GuidedStep(id: 'ayuda', label: 'Ayuda', hint: 'Qué necesitas', emoji: '🚑', targetCategories: ['Servicios']),
      GuidedStep(id: 'lugar', label: 'Lugar', hint: 'Dónde estás', emoji: '📍', targetCategories: ['Lugares', 'Instituciones']),
    ],
  ),

  // ─────────────────────────────────────────────
  // 5. DOCUMENTO / CARNET (Trámite específico)
  // ─────────────────────────────────────────────
  SemanticContext(
    id: 'tramite_id',
    name: 'Documento / Carnet',
    icon: 'badge',
    emoji: '🪪',
    description: 'Trámite de carnet / Certificado / Documento',
    defaultSteps: [
      GuidedStep(id: 'accion', label: 'Acción', hint: 'Qué necesitas hacer', emoji: '📋', targetCategories: ['Acciones', 'Trámites']),
      GuidedStep(id: 'documento', label: 'Documento', hint: 'Qué documento', emoji: '📄', targetCategories: ['Documentos']),
      GuidedStep(id: 'donde', label: 'Lugar', hint: 'En qué institución', emoji: '🏛️', targetCategories: ['Instituciones']),
      GuidedStep(id: 'quien', label: 'Personas', hint: 'Para quién', emoji: '👤', targetCategories: ['Identificación'], isOptional: true),
    ],
  ),

  // ─────────────────────────────────────────────
  // 6. ORIENTACIÓN / DERECHOS
  // ─────────────────────────────────────────────
  SemanticContext(
    id: 'orientacion',
    name: 'Orientación / Derechos',
    icon: 'balance',
    emoji: '⚖️',
    description: 'Necesito intérprete / Mis derechos / Información',
    defaultSteps: [
      GuidedStep(id: 'necesidad', label: 'Necesidad', hint: 'Qué buscas', emoji: '🔎', targetCategories: ['Servicios', 'Acciones', 'Consultas']),
      GuidedStep(id: 'donde', label: 'Lugar', hint: 'Dónde ir', emoji: '🏛️', targetCategories: ['Instituciones']),
      GuidedStep(id: 'quien', label: 'Personas', hint: 'Para quién', emoji: '👤', targetCategories: ['Identificación'], isOptional: true),
    ],
  ),

  // ─────────────────────────────────────────────
  // 7. PERDÍ ALGO
  // ─────────────────────────────────────────────
  SemanticContext(
    id: 'perdida',
    name: 'Perdí algo',
    icon: 'search_off',
    emoji: '📋',
    description: 'Perdí mi documento / celular / objeto',
    defaultSteps: [
      GuidedStep(id: 'objetos', label: 'Objetos', hint: 'Qué perdiste', emoji: '📱', targetCategories: ['Objetos', 'Documentos']),
      GuidedStep(id: 'lugar', label: 'Lugar', hint: 'Dónde lo perdiste', emoji: '📍', targetCategories: ['Lugares', 'Instituciones']),
      GuidedStep(id: 'tiempo', label: 'Tiempo', hint: 'Cuándo', emoji: '🕐', targetCategories: ['Tiempo'], isOptional: true),
      GuidedStep(id: 'ayuda', label: 'Ayuda', hint: 'Qué necesitas', emoji: '🆘', targetCategories: ['Servicios', 'Acciones'], isOptional: true),
    ],
  ),

  // ─────────────────────────────────────────────
  // 8. OTRA SITUACIÓN
  // ─────────────────────────────────────────────
  SemanticContext(
    id: 'otro',
    name: 'Otra situación',
    icon: 'chat',
    emoji: '💬',
    description: 'Quiero comunicar otra cosa',
    defaultSteps: [
      GuidedStep(id: 'que', label: 'Acción', hint: 'Qué necesitas', emoji: '⚡', targetCategories: ['Acciones', 'Servicios', 'Trámites', 'Consultas']),
      GuidedStep(id: 'detalle', label: 'Detalle', hint: 'Más contexto', emoji: '📌', targetCategories: ['Documentos', 'Instituciones', 'Identificación', 'Lugares', 'Objetos', 'Tiempo'], isOptional: true),
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

final contextProvider = NotifierProvider<ContextNotifier, SemanticContext?>(ContextNotifier.new);
