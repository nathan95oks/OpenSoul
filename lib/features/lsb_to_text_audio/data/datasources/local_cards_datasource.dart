import '../../domain/entities/lsb_card.dart';

/// Fuente de datos local con el catálogo de tarjetas LSB
/// especializadas en contextos reales: judiciales, policiales,
/// defensorías y administrativos en Bolivia.
///
/// Categorías: Identificación, Descripción, Agresión, Acciones, 
/// Emociones, Estado/Urgencia, Objetos, Documentos, Lugares, 
/// Instituciones, Servicios, Consultas, Tiempo, Trámites.
class LocalCardsDataSource {
  final List<LsbCard> _cards = [
    // ═══════════════════════════════════════════════════════════
    // IDENTIFICACIÓN — Personas
    // ═══════════════════════════════════════════════════════════
    LsbCard(id: 'id01', gloss: 'YO', displayText: 'YO', iconUrl: '',
      categoryId: 'Identificación', subcategoryId: 'Persona', contexts: ['general'],
      priority: 1, suggestedNextCardIds: ['ac01','ac02'], isFrequent: true, isEmergency: false, semanticIcon: 'person'),
    LsbCard(id: 'id02', gloss: 'FAMILIA', displayText: 'FAMILIA', iconUrl: '',
      categoryId: 'Identificación', subcategoryId: 'Familia', contexts: ['general'],
      priority: 2, suggestedNextCardIds: [], isFrequent: true, isEmergency: false, semanticIcon: 'family_restroom'),
    LsbCard(id: 'id03', gloss: 'HIJO', displayText: 'HIJO/A', iconUrl: '',
      categoryId: 'Identificación', subcategoryId: 'Familia', contexts: ['general'],
      priority: 3, suggestedNextCardIds: [], isFrequent: true, isEmergency: false, semanticIcon: 'child_care'),
    LsbCard(id: 'id04', gloss: 'ESPOSO', displayText: 'ESPOSO/A', iconUrl: '',
      categoryId: 'Identificación', subcategoryId: 'Familia', contexts: ['general', 'violencia'],
      priority: 4, suggestedNextCardIds: [], isFrequent: true, isEmergency: false, semanticIcon: 'people'),
    LsbCard(id: 'id05', gloss: 'MAMA', displayText: 'MAMÁ', iconUrl: '',
      categoryId: 'Identificación', subcategoryId: 'Familia', contexts: ['general'],
      priority: 5, suggestedNextCardIds: [], isFrequent: false, isEmergency: false, semanticIcon: 'woman'),
    LsbCard(id: 'id06', gloss: 'PAPA', displayText: 'PAPÁ', iconUrl: '',
      categoryId: 'Identificación', subcategoryId: 'Familia', contexts: ['general'],
      priority: 6, suggestedNextCardIds: [], isFrequent: false, isEmergency: false, semanticIcon: 'man'),
    LsbCard(id: 'id07', gloss: 'HERMANO', displayText: 'HERMANO/A', iconUrl: '',
      categoryId: 'Identificación', subcategoryId: 'Familia', contexts: ['general'],
      priority: 7, suggestedNextCardIds: [], isFrequent: false, isEmergency: false, semanticIcon: 'people'),

    // ═══════════════════════════════════════════════════════════
    // DESCRIPCIÓN — Tipos de personas (NUEVO)
    // ═══════════════════════════════════════════════════════════
    LsbCard(id: 'de01', gloss: 'HOMBRE', displayText: 'HOMBRE', iconUrl: '',
      categoryId: 'Descripción', subcategoryId: 'Género', contexts: ['denuncia_robo', 'violencia', 'accidente'],
      priority: 1, suggestedNextCardIds: ['de05'], isFrequent: true, isEmergency: false, semanticIcon: 'man'),
    LsbCard(id: 'de02', gloss: 'MUJER', displayText: 'MUJER', iconUrl: '',
      categoryId: 'Descripción', subcategoryId: 'Género', contexts: ['denuncia_robo', 'violencia', 'accidente'],
      priority: 2, suggestedNextCardIds: ['de05'], isFrequent: true, isEmergency: false, semanticIcon: 'woman'),
    LsbCard(id: 'de03', gloss: 'JOVEN', displayText: 'JOVEN', iconUrl: '',
      categoryId: 'Descripción', subcategoryId: 'Edad', contexts: ['denuncia_robo', 'violencia', 'accidente'],
      priority: 3, suggestedNextCardIds: [], isFrequent: true, isEmergency: false, semanticIcon: 'person'),
    LsbCard(id: 'de04', gloss: 'NIÑO', displayText: 'NIÑO', iconUrl: '',
      categoryId: 'Descripción', subcategoryId: 'Edad', contexts: ['emergencia', 'accidente'],
      priority: 4, suggestedNextCardIds: [], isFrequent: true, isEmergency: false, semanticIcon: 'child_care'),
    LsbCard(id: 'de05', gloss: 'DESCONOCIDO', displayText: 'DESCONOCIDO', iconUrl: '',
      categoryId: 'Descripción', subcategoryId: 'Relación', contexts: ['denuncia_robo', 'violencia'],
      priority: 5, suggestedNextCardIds: [], isFrequent: true, isEmergency: false, semanticIcon: 'person_off'),
    LsbCard(id: 'de06', gloss: 'VECINO', displayText: 'VECINO', iconUrl: '',
      categoryId: 'Descripción', subcategoryId: 'Relación', contexts: ['violencia', 'general'],
      priority: 6, suggestedNextCardIds: [], isFrequent: false, isEmergency: false, semanticIcon: 'nature_people'),
    LsbCard(id: 'de07', gloss: 'GRUPO', displayText: 'GRUPO', iconUrl: '',
      categoryId: 'Descripción', subcategoryId: 'Cantidad', contexts: ['denuncia_robo', 'violencia'],
      priority: 7, suggestedNextCardIds: [], isFrequent: true, isEmergency: false, semanticIcon: 'groups'),

    // ═══════════════════════════════════════════════════════════
    // AGRESIÓN — Acciones violentas (NUEVO)
    // ═══════════════════════════════════════════════════════════
    LsbCard(id: 'ag01', gloss: 'ROBAR', displayText: 'ROBAR', iconUrl: '',
      categoryId: 'Agresión', subcategoryId: 'Delito', contexts: ['denuncia_robo'],
      priority: 1, suggestedNextCardIds: ['ob01', 'ob02', 'ob03'], isFrequent: true, isEmergency: true, semanticIcon: 'front_hand'),
    LsbCard(id: 'ag02', gloss: 'GOLPEAR', displayText: 'GOLPEAR', iconUrl: '',
      categoryId: 'Agresión', subcategoryId: 'Física', contexts: ['violencia'],
      priority: 2, suggestedNextCardIds: ['em01', 'em02'], isFrequent: true, isEmergency: true, semanticIcon: 'sports_mma'),
    LsbCard(id: 'ag03', gloss: 'AMENAZAR', displayText: 'AMENAZAR', iconUrl: '',
      categoryId: 'Agresión', subcategoryId: 'Psicológica', contexts: ['violencia', 'denuncia_robo'],
      priority: 3, suggestedNextCardIds: ['em01', 'ob06'], isFrequent: true, isEmergency: true, semanticIcon: 'warning'),
    LsbCard(id: 'ag04', gloss: 'EMPUJAR', displayText: 'EMPUJAR', iconUrl: '',
      categoryId: 'Agresión', subcategoryId: 'Física', contexts: ['violencia'],
      priority: 4, suggestedNextCardIds: ['eu05'], isFrequent: true, isEmergency: true, semanticIcon: 'back_hand'),
    LsbCard(id: 'ag05', gloss: 'GRITAR', displayText: 'GRITAR', iconUrl: '',
      categoryId: 'Agresión', subcategoryId: 'Psicológica', contexts: ['violencia'],
      priority: 5, suggestedNextCardIds: ['em01'], isFrequent: true, isEmergency: false, semanticIcon: 'record_voice_over'),
    LsbCard(id: 'ag06', gloss: 'QUITAR', displayText: 'QUITAR', iconUrl: '',
      categoryId: 'Agresión', subcategoryId: 'Delito', contexts: ['denuncia_robo'],
      priority: 6, suggestedNextCardIds: ['ob01', 'ob02'], isFrequent: true, isEmergency: false, semanticIcon: 'waving_hand'),
    LsbCard(id: 'ag07', gloss: 'PERSEGUIR', displayText: 'PERSEGUIR', iconUrl: '',
      categoryId: 'Agresión', subcategoryId: 'Acoso', contexts: ['violencia', 'denuncia_robo'],
      priority: 7, suggestedNextCardIds: ['em01'], isFrequent: false, isEmergency: true, semanticIcon: 'directions_run'),

    // ═══════════════════════════════════════════════════════════
    // ACCIONES — Verbos generales y trámites
    // ═══════════════════════════════════════════════════════════
    LsbCard(id: 'ac01', gloss: 'TRAMITAR', displayText: 'TRAMITAR', iconUrl: '',
      categoryId: 'Acciones', subcategoryId: 'Gestión', contexts: ['tramite_id'],
      priority: 1, suggestedNextCardIds: ['do01','do04'], isFrequent: true, isEmergency: false, semanticIcon: 'assignment'),
    LsbCard(id: 'ac02', gloss: 'SOLICITAR', displayText: 'SOLICITAR', iconUrl: '',
      categoryId: 'Acciones', subcategoryId: 'Gestión', contexts: ['general', 'orientacion'],
      priority: 2, suggestedNextCardIds: ['do01','sv01'], isFrequent: true, isEmergency: false, semanticIcon: 'send'),
    LsbCard(id: 'ac03', gloss: 'CONSULTAR', displayText: 'CONSULTAR', iconUrl: '',
      categoryId: 'Acciones', subcategoryId: 'Información', contexts: ['orientacion'],
      priority: 3, suggestedNextCardIds: ['co01','co02'], isFrequent: true, isEmergency: false, semanticIcon: 'help'),
    LsbCard(id: 'ac04', gloss: 'NECESITAR', displayText: 'NECESITAR', iconUrl: '',
      categoryId: 'Acciones', subcategoryId: 'Solicitud', contexts: ['general', 'emergencia', 'accidente'],
      priority: 4, suggestedNextCardIds: ['sv01','sv07', 'sv03'], isFrequent: true, isEmergency: false, semanticIcon: 'front_hand'),
    LsbCard(id: 'ac05', gloss: 'PAGAR', displayText: 'PAGAR', iconUrl: '',
      categoryId: 'Acciones', subcategoryId: 'Gestión', contexts: ['tramite_id'],
      priority: 5, suggestedNextCardIds: ['do09'], isFrequent: false, isEmergency: false, semanticIcon: 'payments'),
    LsbCard(id: 'ac06', gloss: 'RENOVAR', displayText: 'RENOVAR', iconUrl: '',
      categoryId: 'Acciones', subcategoryId: 'Gestión', contexts: ['tramite_id'],
      priority: 6, suggestedNextCardIds: ['do04'], isFrequent: true, isEmergency: false, semanticIcon: 'autorenew'),
    LsbCard(id: 'ac07', gloss: 'RECOGER', displayText: 'RECOGER', iconUrl: '',
      categoryId: 'Acciones', subcategoryId: 'Entrega', contexts: ['tramite_id'],
      priority: 7, suggestedNextCardIds: ['do01','do04'], isFrequent: true, isEmergency: false, semanticIcon: 'download'),
    LsbCard(id: 'ac08', gloss: 'ENTREGAR', displayText: 'ENTREGAR', iconUrl: '',
      categoryId: 'Acciones', subcategoryId: 'Entrega', contexts: ['tramite_id'],
      priority: 8, suggestedNextCardIds: ['do01','do05'], isFrequent: true, isEmergency: false, semanticIcon: 'upload'),
    LsbCard(id: 'ac09', gloss: 'PERDER', displayText: 'PERDER', iconUrl: '',
      categoryId: 'Acciones', subcategoryId: 'Pérdida', contexts: ['perdida'],
      priority: 9, suggestedNextCardIds: ['ob01', 'do04'], isFrequent: true, isEmergency: false, semanticIcon: 'search_off'),

    // ═══════════════════════════════════════════════════════════
    // EMOCIONES — Estados psicológicos (NUEVO)
    // ═══════════════════════════════════════════════════════════
    LsbCard(id: 'em01', gloss: 'MIEDO', displayText: 'MIEDO', iconUrl: '',
      categoryId: 'Emociones', subcategoryId: 'Negativa', contexts: ['violencia', 'denuncia_robo', 'accidente'],
      priority: 1, suggestedNextCardIds: ['eu02'], isFrequent: true, isEmergency: true, semanticIcon: 'mood_bad'),
    LsbCard(id: 'em02', gloss: 'ENOJO', displayText: 'ENOJO', iconUrl: '',
      categoryId: 'Emociones', subcategoryId: 'Negativa', contexts: ['violencia', 'denuncia_robo'],
      priority: 2, suggestedNextCardIds: [], isFrequent: true, isEmergency: false, semanticIcon: 'sentiment_dissatisfied'),
    LsbCard(id: 'em03', gloss: 'TRISTE', displayText: 'TRISTE', iconUrl: '',
      categoryId: 'Emociones', subcategoryId: 'Negativa', contexts: ['violencia', 'perdida'],
      priority: 3, suggestedNextCardIds: [], isFrequent: true, isEmergency: false, semanticIcon: 'sentiment_very_dissatisfied'),
    LsbCard(id: 'em04', gloss: 'ASUSTADO', displayText: 'ASUSTADO', iconUrl: '',
      categoryId: 'Emociones', subcategoryId: 'Negativa', contexts: ['violencia', 'denuncia_robo', 'accidente'],
      priority: 4, suggestedNextCardIds: [], isFrequent: true, isEmergency: true, semanticIcon: 'mood_bad'),
    LsbCard(id: 'em05', gloss: 'NERVIOSO', displayText: 'NERVIOSO', iconUrl: '',
      categoryId: 'Emociones', subcategoryId: 'Negativa', contexts: ['general', 'accidente'],
      priority: 5, suggestedNextCardIds: [], isFrequent: true, isEmergency: false, semanticIcon: 'sick'),

    // ═══════════════════════════════════════════════════════════
    // ESTADO / URGENCIA — Marcadores de prioridad
    // ═══════════════════════════════════════════════════════════
    LsbCard(id: 'eu01', gloss: 'URGENTE', displayText: 'URGENTE', iconUrl: '',
      categoryId: 'Estado/Urgencia', subcategoryId: 'Prioridad', contexts: ['emergencia', 'accidente', 'denuncia_robo', 'violencia'],
      priority: 1, suggestedNextCardIds: [], isFrequent: true, isEmergency: true, semanticIcon: 'priority_high'),
    LsbCard(id: 'eu02', gloss: 'AYUDA', displayText: 'AYUDA', iconUrl: '',
      categoryId: 'Estado/Urgencia', subcategoryId: 'Solicitud', contexts: ['emergencia', 'accidente', 'violencia'],
      priority: 2, suggestedNextCardIds: ['sv01','sv03', 'in10'], isFrequent: true, isEmergency: true, semanticIcon: 'sos'),
    LsbCard(id: 'eu03', gloss: 'EMERGENCIA', displayText: 'EMERGENCIA', iconUrl: '',
      categoryId: 'Estado/Urgencia', subcategoryId: 'Crítico', contexts: ['emergencia', 'accidente'],
      priority: 3, suggestedNextCardIds: ['sv07'], isFrequent: true, isEmergency: true, semanticIcon: 'crisis_alert'),
    LsbCard(id: 'eu04', gloss: 'ENFERMO', displayText: 'ENFERMO', iconUrl: '',
      categoryId: 'Estado/Urgencia', subcategoryId: 'Estado', contexts: ['emergencia'],
      priority: 4, suggestedNextCardIds: ['sv03','in07'], isFrequent: true, isEmergency: true, semanticIcon: 'sick'),
    LsbCard(id: 'eu05', gloss: 'DOLOR', displayText: 'DOLOR', iconUrl: '',
      categoryId: 'Estado/Urgencia', subcategoryId: 'Estado', contexts: ['emergencia', 'accidente', 'violencia'],
      priority: 5, suggestedNextCardIds: ['sv03','sv07'], isFrequent: true, isEmergency: true, semanticIcon: 'healing'),
    LsbCard(id: 'eu06', gloss: 'CONFUNDIDO', displayText: 'CONFUNDIDO', iconUrl: '',
      categoryId: 'Estado/Urgencia', subcategoryId: 'Estado', contexts: ['orientacion'],
      priority: 6, suggestedNextCardIds: ['sv02','sv06'], isFrequent: true, isEmergency: false, semanticIcon: 'help_outline'),

    // ═══════════════════════════════════════════════════════════
    // OBJETOS — Cosas personales (NUEVO)
    // ═══════════════════════════════════════════════════════════
    LsbCard(id: 'ob01', gloss: 'CELULAR', displayText: 'CELULAR', iconUrl: '',
      categoryId: 'Objetos', subcategoryId: 'Personal', contexts: ['denuncia_robo', 'perdida'],
      priority: 1, suggestedNextCardIds: [], isFrequent: true, isEmergency: false, semanticIcon: 'smartphone'),
    LsbCard(id: 'ob02', gloss: 'DINERO', displayText: 'DINERO', iconUrl: '',
      categoryId: 'Objetos', subcategoryId: 'Personal', contexts: ['denuncia_robo', 'perdida'],
      priority: 2, suggestedNextCardIds: [], isFrequent: true, isEmergency: false, semanticIcon: 'attach_money'),
    LsbCard(id: 'ob03', gloss: 'MOCHILA', displayText: 'MOCHILA', iconUrl: '',
      categoryId: 'Objetos', subcategoryId: 'Personal', contexts: ['denuncia_robo', 'perdida'],
      priority: 3, suggestedNextCardIds: [], isFrequent: true, isEmergency: false, semanticIcon: 'backpack'),
    LsbCard(id: 'ob04', gloss: 'BOLSA', displayText: 'BOLSA', iconUrl: '',
      categoryId: 'Objetos', subcategoryId: 'Personal', contexts: ['denuncia_robo', 'perdida'],
      priority: 4, suggestedNextCardIds: [], isFrequent: true, isEmergency: false, semanticIcon: 'shopping_bag'),
    LsbCard(id: 'ob05', gloss: 'LLAVE', displayText: 'LLAVE', iconUrl: '',
      categoryId: 'Objetos', subcategoryId: 'Personal', contexts: ['perdida'],
      priority: 5, suggestedNextCardIds: [], isFrequent: false, isEmergency: false, semanticIcon: 'vpn_key'),
    LsbCard(id: 'ob06', gloss: 'CUCHILLO', displayText: 'CUCHILLO / ARMA', iconUrl: '',
      categoryId: 'Objetos', subcategoryId: 'Peligro', contexts: ['denuncia_robo', 'violencia'],
      priority: 6, suggestedNextCardIds: ['em01'], isFrequent: true, isEmergency: true, semanticIcon: 'hardware'),
    LsbCard(id: 'ob07', gloss: 'AUTO', displayText: 'AUTO', iconUrl: '',
      categoryId: 'Objetos', subcategoryId: 'Vehículo', contexts: ['accidente', 'denuncia_robo'],
      priority: 7, suggestedNextCardIds: [], isFrequent: true, isEmergency: false, semanticIcon: 'directions_car'),
    LsbCard(id: 'ob08', gloss: 'MOTO', displayText: 'MOTO', iconUrl: '',
      categoryId: 'Objetos', subcategoryId: 'Vehículo', contexts: ['accidente', 'denuncia_robo'],
      priority: 8, suggestedNextCardIds: [], isFrequent: true, isEmergency: false, semanticIcon: 'two_wheeler'),

    // ═══════════════════════════════════════════════════════════
    // DOCUMENTOS — Papeles y certificados
    // ═══════════════════════════════════════════════════════════
    LsbCard(id: 'do04', gloss: 'CARNET', displayText: 'CARNET', iconUrl: '',
      categoryId: 'Documentos', subcategoryId: 'Identificación', contexts: ['tramite_id', 'perdida', 'denuncia_robo'],
      priority: 1, suggestedNextCardIds: ['in04'], isFrequent: true, isEmergency: false, semanticIcon: 'badge'),
    LsbCard(id: 'do01', gloss: 'DOCUMENTO', displayText: 'DOCUMENTO', iconUrl: '',
      categoryId: 'Documentos', subcategoryId: 'General', contexts: ['tramite_id', 'perdida'],
      priority: 2, suggestedNextCardIds: [], isFrequent: true, isEmergency: false, semanticIcon: 'article'),
    LsbCard(id: 'do02', gloss: 'CERTIFICADO', displayText: 'CERTIFICADO', iconUrl: '',
      categoryId: 'Documentos', subcategoryId: 'Oficial', contexts: ['tramite_id'],
      priority: 3, suggestedNextCardIds: [], isFrequent: true, isEmergency: false, semanticIcon: 'workspace_premium'),
    LsbCard(id: 'do05', gloss: 'PARTIDA_NACIMIENTO', displayText: 'PARTIDA NAC.', iconUrl: '',
      categoryId: 'Documentos', subcategoryId: 'Civil', contexts: ['tramite_id'],
      priority: 4, suggestedNextCardIds: ['in03'], isFrequent: true, isEmergency: false, semanticIcon: 'child_friendly'),
    LsbCard(id: 'do08', gloss: 'LICENCIA', displayText: 'LICENCIA', iconUrl: '',
      categoryId: 'Documentos', subcategoryId: 'Oficial', contexts: ['tramite_id', 'perdida', 'accidente'],
      priority: 5, suggestedNextCardIds: [], isFrequent: true, isEmergency: false, semanticIcon: 'directions_car'),
    LsbCard(id: 'do09', gloss: 'FACTURA', displayText: 'FACTURA', iconUrl: '',
      categoryId: 'Documentos', subcategoryId: 'Pago', contexts: ['tramite_id'],
      priority: 6, suggestedNextCardIds: ['in05'], isFrequent: false, isEmergency: false, semanticIcon: 'receipt_long'),

    // ═══════════════════════════════════════════════════════════
    // LUGARES — Cotidianos (NUEVO)
    // ═══════════════════════════════════════════════════════════
    LsbCard(id: 'lu01', gloss: 'CALLE', displayText: 'CALLE', iconUrl: '',
      categoryId: 'Lugares', subcategoryId: 'Público', contexts: ['denuncia_robo', 'accidente', 'violencia', 'perdida'],
      priority: 1, suggestedNextCardIds: [], isFrequent: true, isEmergency: false, semanticIcon: 'add_road'),
    LsbCard(id: 'lu02', gloss: 'CASA', displayText: 'CASA', iconUrl: '',
      categoryId: 'Lugares', subcategoryId: 'Privado', contexts: ['violencia', 'denuncia_robo'],
      priority: 2, suggestedNextCardIds: [], isFrequent: true, isEmergency: false, semanticIcon: 'home'),
    LsbCard(id: 'lu03', gloss: 'MERCADO', displayText: 'MERCADO', iconUrl: '',
      categoryId: 'Lugares', subcategoryId: 'Público', contexts: ['denuncia_robo', 'perdida'],
      priority: 3, suggestedNextCardIds: [], isFrequent: true, isEmergency: false, semanticIcon: 'storefront'),
    LsbCard(id: 'lu04', gloss: 'PARADA', displayText: 'PARADA', iconUrl: '',
      categoryId: 'Lugares', subcategoryId: 'Público', contexts: ['denuncia_robo', 'accidente'],
      priority: 4, suggestedNextCardIds: [], isFrequent: true, isEmergency: false, semanticIcon: 'departure_board'),
    LsbCard(id: 'lu05', gloss: 'MICRO', displayText: 'MICRO/BUS', iconUrl: '',
      categoryId: 'Lugares', subcategoryId: 'Transporte', contexts: ['denuncia_robo', 'accidente', 'perdida'],
      priority: 5, suggestedNextCardIds: [], isFrequent: true, isEmergency: false, semanticIcon: 'directions_bus'),
    LsbCard(id: 'lu06', gloss: 'PARQUE', displayText: 'PARQUE', iconUrl: '',
      categoryId: 'Lugares', subcategoryId: 'Público', contexts: ['denuncia_robo', 'violencia'],
      priority: 6, suggestedNextCardIds: [], isFrequent: false, isEmergency: false, semanticIcon: 'park'),
    LsbCard(id: 'lu07', gloss: 'TRABAJO', displayText: 'TRABAJO', iconUrl: '',
      categoryId: 'Lugares', subcategoryId: 'Privado', contexts: ['general'],
      priority: 7, suggestedNextCardIds: [], isFrequent: false, isEmergency: false, semanticIcon: 'work'),

    // ═══════════════════════════════════════════════════════════
    // INSTITUCIONES — Entidades públicas
    // ═══════════════════════════════════════════════════════════
    LsbCard(id: 'in10', gloss: 'POLICIA', displayText: 'POLICÍA', iconUrl: '',
      categoryId: 'Instituciones', subcategoryId: 'Seguridad', contexts: ['denuncia_robo', 'violencia', 'accidente', 'emergencia'],
      priority: 1, suggestedNextCardIds: ['co06'], isFrequent: true, isEmergency: true, semanticIcon: 'local_police'),
    LsbCard(id: 'in11', gloss: 'DEFENSORIA', displayText: 'DEFENSORÍA', iconUrl: '',
      categoryId: 'Instituciones', subcategoryId: 'Social', contexts: ['violencia', 'orientacion'],
      priority: 2, suggestedNextCardIds: ['sv06'], isFrequent: true, isEmergency: false, semanticIcon: 'shield'),
    LsbCard(id: 'in04', gloss: 'SEGIP', displayText: 'SEGIP', iconUrl: '',
      categoryId: 'Instituciones', subcategoryId: 'Identificación', contexts: ['tramite_id'],
      priority: 3, suggestedNextCardIds: ['do04'], isFrequent: true, isEmergency: false, semanticIcon: 'badge'),
    LsbCard(id: 'in07', gloss: 'HOSPITAL', displayText: 'HOSPITAL / CLÍNICA', iconUrl: '',
      categoryId: 'Instituciones', subcategoryId: 'Salud', contexts: ['emergencia', 'accidente'],
      priority: 4, suggestedNextCardIds: ['sv03'], isFrequent: true, isEmergency: true, semanticIcon: 'local_hospital'),
    LsbCard(id: 'in01', gloss: 'ALCALDIA', displayText: 'ALCALDÍA', iconUrl: '',
      categoryId: 'Instituciones', subcategoryId: 'Gobierno', contexts: ['tramite_id', 'orientacion'],
      priority: 5, suggestedNextCardIds: [], isFrequent: true, isEmergency: false, semanticIcon: 'account_balance'),
    LsbCard(id: 'in03', gloss: 'REGISTRO_CIVIL', displayText: 'REG. CIVIL', iconUrl: '',
      categoryId: 'Instituciones', subcategoryId: 'Civil', contexts: ['tramite_id'],
      priority: 6, suggestedNextCardIds: ['do05'], isFrequent: false, isEmergency: false, semanticIcon: 'menu_book'),

    // ═══════════════════════════════════════════════════════════
    // SERVICIOS — Ayuda y atención
    // ═══════════════════════════════════════════════════════════
    LsbCard(id: 'sv01', gloss: 'INTERPRETE', displayText: 'INTÉRPRETE', iconUrl: '',
      categoryId: 'Servicios', subcategoryId: 'Accesibilidad', contexts: ['orientacion', 'denuncia_robo', 'violencia'],
      priority: 1, suggestedNextCardIds: [], isFrequent: true, isEmergency: false, semanticIcon: 'sign_language'),
    LsbCard(id: 'sv07', gloss: 'AMBULANCIA', displayText: 'AMBULANCIA', iconUrl: '',
      categoryId: 'Servicios', subcategoryId: 'Emergencia', contexts: ['emergencia', 'accidente'],
      priority: 2, suggestedNextCardIds: [], isFrequent: true, isEmergency: true, semanticIcon: 'emergency'),
    LsbCard(id: 'sv03', gloss: 'DOCTOR', displayText: 'DOCTOR', iconUrl: '',
      categoryId: 'Servicios', subcategoryId: 'Salud', contexts: ['emergencia', 'accidente'],
      priority: 3, suggestedNextCardIds: [], isFrequent: true, isEmergency: true, semanticIcon: 'medical_services'),
    LsbCard(id: 'sv04', gloss: 'ABOGADO', displayText: 'ABOGADO', iconUrl: '',
      categoryId: 'Servicios', subcategoryId: 'Legal', contexts: ['violencia', 'orientacion'],
      priority: 4, suggestedNextCardIds: [], isFrequent: true, isEmergency: false, semanticIcon: 'balance'),
    LsbCard(id: 'sv02', gloss: 'INFORMACION', displayText: 'INFORMACIÓN', iconUrl: '',
      categoryId: 'Servicios', subcategoryId: 'Atención', contexts: ['orientacion'],
      priority: 5, suggestedNextCardIds: [], isFrequent: true, isEmergency: false, semanticIcon: 'info'),
    LsbCard(id: 'sv06', gloss: 'ORIENTACION', displayText: 'ORIENTACIÓN', iconUrl: '',
      categoryId: 'Servicios', subcategoryId: 'Información', contexts: ['orientacion'],
      priority: 6, suggestedNextCardIds: [], isFrequent: false, isEmergency: false, semanticIcon: 'explore'),

    // ═══════════════════════════════════════════════════════════
    // CONSULTAS / TRÁMITES — Tipos de gestiones ciudadanas
    // ═══════════════════════════════════════════════════════════
    LsbCard(id: 'co06', gloss: 'DENUNCIA', displayText: 'DENUNCIA', iconUrl: '',
      categoryId: 'Consultas', subcategoryId: 'Queja', contexts: ['denuncia_robo', 'violencia'],
      priority: 1, suggestedNextCardIds: ['in10','in11'], isFrequent: true, isEmergency: true, semanticIcon: 'report'),
    LsbCard(id: 'co01', gloss: 'CONSULTA', displayText: 'CONSULTA', iconUrl: '',
      categoryId: 'Consultas', subcategoryId: 'Información', contexts: ['orientacion'],
      priority: 2, suggestedNextCardIds: ['sv06','in01'], isFrequent: true, isEmergency: false, semanticIcon: 'question_answer'),
    LsbCard(id: 'co02', gloss: 'RECLAMO', displayText: 'RECLAMO', iconUrl: '',
      categoryId: 'Consultas', subcategoryId: 'Queja', contexts: ['orientacion'],
      priority: 3, suggestedNextCardIds: ['sv06','in01'], isFrequent: true, isEmergency: false, semanticIcon: 'feedback'),
    LsbCard(id: 'tr01', gloss: 'RENOVACION', displayText: 'RENOVACIÓN', iconUrl: '',
      categoryId: 'Trámites', subcategoryId: 'Gestión', contexts: ['tramite_id'],
      priority: 4, suggestedNextCardIds: ['do04','in04'], isFrequent: true, isEmergency: false, semanticIcon: 'autorenew'),
    LsbCard(id: 'tr04', gloss: 'PAGO', displayText: 'PAGO', iconUrl: '',
      categoryId: 'Trámites', subcategoryId: 'Gestión', contexts: ['tramite_id'],
      priority: 5, suggestedNextCardIds: ['do09'], isFrequent: false, isEmergency: false, semanticIcon: 'payments'),

    // ═══════════════════════════════════════════════════════════
    // TIEMPO — Cuándo
    // ═══════════════════════════════════════════════════════════
    LsbCard(id: 'ti01', gloss: 'HOY', displayText: 'HOY', iconUrl: '',
      categoryId: 'Tiempo', subcategoryId: 'Presente', contexts: ['general', 'denuncia_robo', 'violencia', 'accidente', 'perdida'],
      priority: 1, suggestedNextCardIds: [], isFrequent: true, isEmergency: false, semanticIcon: 'today'),
    LsbCard(id: 'ti02', gloss: 'AHORA', displayText: 'AHORA', iconUrl: '',
      categoryId: 'Tiempo', subcategoryId: 'Presente', contexts: ['emergencia', 'accidente', 'denuncia_robo'],
      priority: 2, suggestedNextCardIds: [], isFrequent: true, isEmergency: true, semanticIcon: 'access_time'),
    LsbCard(id: 'ti03', gloss: 'AYER', displayText: 'AYER', iconUrl: '',
      categoryId: 'Tiempo', subcategoryId: 'Pasado', contexts: ['denuncia_robo', 'violencia', 'perdida'],
      priority: 3, suggestedNextCardIds: [], isFrequent: true, isEmergency: false, semanticIcon: 'history'),
    LsbCard(id: 'ti04', gloss: 'MAÑANA', displayText: 'DÍA / MAÑANA', iconUrl: '',
      categoryId: 'Tiempo', subcategoryId: 'Horario', contexts: ['general'],
      priority: 4, suggestedNextCardIds: [], isFrequent: true, isEmergency: false, semanticIcon: 'wb_sunny'),
    LsbCard(id: 'ti05', gloss: 'TARDE', displayText: 'TARDE', iconUrl: '',
      categoryId: 'Tiempo', subcategoryId: 'Horario', contexts: ['general'],
      priority: 5, suggestedNextCardIds: [], isFrequent: true, isEmergency: false, semanticIcon: 'wb_twilight'),
    LsbCard(id: 'ti07', gloss: 'NOCHE', displayText: 'NOCHE', iconUrl: '',
      categoryId: 'Tiempo', subcategoryId: 'Horario', contexts: ['denuncia_robo', 'violencia'],
      priority: 6, suggestedNextCardIds: [], isFrequent: true, isEmergency: false, semanticIcon: 'nights_stay'),
  ];

  /// Orden predefinido de las categorías semánticas para exploración libre.
  static const _categoryOrder = [
    'Identificación', 'Descripción', 'Agresión', 'Acciones', 
    'Emociones', 'Estado/Urgencia', 'Objetos', 'Documentos', 
    'Lugares', 'Instituciones', 'Servicios', 'Consultas', 
    'Trámites', 'Tiempo'
  ];

  Future<List<LsbCard>> getCardsByCategory(String category) async {
    return _cards.where((c) => c.categoryId == category).toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));
  }

  Future<List<String>> getCategories() async {
    final available = _cards.map((c) => c.categoryId).toSet();
    return _categoryOrder.where((cat) => available.contains(cat)).toList();
  }
}
