import '../../domain/entities/lsb_card.dart';

/// Fuente de datos local con el catálogo de tarjetas LSB
/// especializadas en trámites y consultas ciudadanas
/// en entidades públicas bolivianas.
///
/// 9 categorías: Identificación, Acciones, Trámites, Documentos,
/// Consultas, Tiempo, Instituciones, Servicios, Estado/Urgencia.
class LocalCardsDataSource {
  // Video placeholder — reemplazar con videos reales de corpus LSB
  static const _vp = 'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4';

  final List<LsbCard> _cards = [
    // ═══════════════════════════════════════════════════════════
    // IDENTIFICACIÓN — Sujetos y familiares
    // ═══════════════════════════════════════════════════════════
    LsbCard(id: 'id01', gloss: 'YO', displayText: 'YO', iconUrl: '', videoUrl: _vp,
      categoryId: 'Identificación', subcategoryId: 'Persona', contexts: ['general'],
      priority: 1, suggestedNextCardIds: ['ac01','ac02'], isFrequent: true, isEmergency: false, semanticIcon: 'person'),
    LsbCard(id: 'id02', gloss: 'HIJO', displayText: 'HIJO', iconUrl: '', videoUrl: _vp,
      categoryId: 'Identificación', subcategoryId: 'Familia', contexts: ['general'],
      priority: 2, suggestedNextCardIds: [], isFrequent: true, isEmergency: false, semanticIcon: 'child_care'),
    LsbCard(id: 'id03', gloss: 'HIJA', displayText: 'HIJA', iconUrl: '', videoUrl: _vp,
      categoryId: 'Identificación', subcategoryId: 'Familia', contexts: ['general'],
      priority: 3, suggestedNextCardIds: [], isFrequent: true, isEmergency: false, semanticIcon: 'child_care'),
    LsbCard(id: 'id04', gloss: 'MAMA', displayText: 'MAMÁ', iconUrl: '', videoUrl: _vp,
      categoryId: 'Identificación', subcategoryId: 'Familia', contexts: ['general'],
      priority: 4, suggestedNextCardIds: [], isFrequent: true, isEmergency: false, semanticIcon: 'woman'),
    LsbCard(id: 'id05', gloss: 'PAPA', displayText: 'PAPÁ', iconUrl: '', videoUrl: _vp,
      categoryId: 'Identificación', subcategoryId: 'Familia', contexts: ['general'],
      priority: 5, suggestedNextCardIds: [], isFrequent: true, isEmergency: false, semanticIcon: 'man'),
    LsbCard(id: 'id06', gloss: 'HERMANO', displayText: 'HERMANO', iconUrl: '', videoUrl: _vp,
      categoryId: 'Identificación', subcategoryId: 'Familia', contexts: ['general'],
      priority: 6, suggestedNextCardIds: [], isFrequent: false, isEmergency: false, semanticIcon: 'people'),
    LsbCard(id: 'id07', gloss: 'ESPOSO', displayText: 'ESPOSO', iconUrl: '', videoUrl: _vp,
      categoryId: 'Identificación', subcategoryId: 'Familia', contexts: ['general'],
      priority: 7, suggestedNextCardIds: [], isFrequent: false, isEmergency: false, semanticIcon: 'people'),
    LsbCard(id: 'id08', gloss: 'FAMILIA', displayText: 'FAMILIA', iconUrl: '', videoUrl: _vp,
      categoryId: 'Identificación', subcategoryId: 'Familia', contexts: ['general'],
      priority: 8, suggestedNextCardIds: [], isFrequent: false, isEmergency: false, semanticIcon: 'family_restroom'),

    // ═══════════════════════════════════════════════════════════
    // ACCIONES — Verbos para gestiones ciudadanas
    // ═══════════════════════════════════════════════════════════
    LsbCard(id: 'ac01', gloss: 'TRAMITAR', displayText: 'TRAMITAR', iconUrl: '', videoUrl: _vp,
      categoryId: 'Acciones', subcategoryId: 'Gestión', contexts: ['municipio'],
      priority: 1, suggestedNextCardIds: ['do01','do04'], isFrequent: true, isEmergency: false, semanticIcon: 'assignment'),
    LsbCard(id: 'ac02', gloss: 'SOLICITAR', displayText: 'SOLICITAR', iconUrl: '', videoUrl: _vp,
      categoryId: 'Acciones', subcategoryId: 'Gestión', contexts: ['general'],
      priority: 2, suggestedNextCardIds: ['do01','sv01'], isFrequent: true, isEmergency: false, semanticIcon: 'send'),
    LsbCard(id: 'ac03', gloss: 'CONSULTAR', displayText: 'CONSULTAR', iconUrl: '', videoUrl: _vp,
      categoryId: 'Acciones', subcategoryId: 'Información', contexts: ['general'],
      priority: 3, suggestedNextCardIds: ['co01','co02'], isFrequent: true, isEmergency: false, semanticIcon: 'help'),
    LsbCard(id: 'ac04', gloss: 'NECESITAR', displayText: 'NECESITAR', iconUrl: '', videoUrl: _vp,
      categoryId: 'Acciones', subcategoryId: 'Solicitud', contexts: ['general'],
      priority: 4, suggestedNextCardIds: ['sv01','do01'], isFrequent: true, isEmergency: false, semanticIcon: 'front_hand'),
    LsbCard(id: 'ac05', gloss: 'PAGAR', displayText: 'PAGAR', iconUrl: '', videoUrl: _vp,
      categoryId: 'Acciones', subcategoryId: 'Gestión', contexts: ['municipio'],
      priority: 5, suggestedNextCardIds: ['do09','do10'], isFrequent: true, isEmergency: false, semanticIcon: 'payments'),
    LsbCard(id: 'ac06', gloss: 'RENOVAR', displayText: 'RENOVAR', iconUrl: '', videoUrl: _vp,
      categoryId: 'Acciones', subcategoryId: 'Gestión', contexts: ['municipio'],
      priority: 6, suggestedNextCardIds: ['do04','do08'], isFrequent: true, isEmergency: false, semanticIcon: 'autorenew'),
    LsbCard(id: 'ac07', gloss: 'INSCRIBIR', displayText: 'INSCRIBIR', iconUrl: '', videoUrl: _vp,
      categoryId: 'Acciones', subcategoryId: 'Gestión', contexts: ['educacion','municipio'],
      priority: 7, suggestedNextCardIds: ['do01','in08'], isFrequent: true, isEmergency: false, semanticIcon: 'app_registration'),
    LsbCard(id: 'ac08', gloss: 'REGISTRAR', displayText: 'REGISTRAR', iconUrl: '', videoUrl: _vp,
      categoryId: 'Acciones', subcategoryId: 'Gestión', contexts: ['municipio'],
      priority: 8, suggestedNextCardIds: ['in03','do01'], isFrequent: true, isEmergency: false, semanticIcon: 'how_to_reg'),
    LsbCard(id: 'ac09', gloss: 'RECOGER', displayText: 'RECOGER', iconUrl: '', videoUrl: _vp,
      categoryId: 'Acciones', subcategoryId: 'Entrega', contexts: ['general'],
      priority: 9, suggestedNextCardIds: ['do01','do02'], isFrequent: true, isEmergency: false, semanticIcon: 'download'),
    LsbCard(id: 'ac10', gloss: 'ENTREGAR', displayText: 'ENTREGAR', iconUrl: '', videoUrl: _vp,
      categoryId: 'Acciones', subcategoryId: 'Entrega', contexts: ['general'],
      priority: 10, suggestedNextCardIds: ['do01','do05'], isFrequent: true, isEmergency: false, semanticIcon: 'upload'),
    LsbCard(id: 'ac11', gloss: 'FIRMAR', displayText: 'FIRMAR', iconUrl: '', videoUrl: _vp,
      categoryId: 'Acciones', subcategoryId: 'Gestión', contexts: ['municipio'],
      priority: 11, suggestedNextCardIds: ['do01','do05'], isFrequent: true, isEmergency: false, semanticIcon: 'draw'),
    LsbCard(id: 'ac12', gloss: 'PEDIR', displayText: 'PEDIR', iconUrl: '', videoUrl: _vp,
      categoryId: 'Acciones', subcategoryId: 'Solicitud', contexts: ['general'],
      priority: 12, suggestedNextCardIds: ['sv01','sv02'], isFrequent: true, isEmergency: false, semanticIcon: 'record_voice_over'),

    // ═══════════════════════════════════════════════════════════
    // TRÁMITES — Tipos de gestiones ciudadanas
    // ═══════════════════════════════════════════════════════════
    LsbCard(id: 'tr01', gloss: 'RENOVACION', displayText: 'RENOVACIÓN', iconUrl: '', videoUrl: _vp,
      categoryId: 'Trámites', subcategoryId: 'Gestión', contexts: ['municipio'],
      priority: 1, suggestedNextCardIds: ['do04','in04'], isFrequent: true, isEmergency: false, semanticIcon: 'autorenew'),
    LsbCard(id: 'tr02', gloss: 'INSCRIPCION', displayText: 'INSCRIPCIÓN', iconUrl: '', videoUrl: _vp,
      categoryId: 'Trámites', subcategoryId: 'Gestión', contexts: ['educacion','municipio'],
      priority: 2, suggestedNextCardIds: ['in08','do01'], isFrequent: true, isEmergency: false, semanticIcon: 'app_registration'),
    LsbCard(id: 'tr03', gloss: 'REGISTRO', displayText: 'REGISTRO', iconUrl: '', videoUrl: _vp,
      categoryId: 'Trámites', subcategoryId: 'Gestión', contexts: ['municipio'],
      priority: 3, suggestedNextCardIds: ['in03','do01'], isFrequent: true, isEmergency: false, semanticIcon: 'how_to_reg'),
    LsbCard(id: 'tr04', gloss: 'PAGO', displayText: 'PAGO', iconUrl: '', videoUrl: _vp,
      categoryId: 'Trámites', subcategoryId: 'Gestión', contexts: ['municipio'],
      priority: 4, suggestedNextCardIds: ['in05','do09'], isFrequent: true, isEmergency: false, semanticIcon: 'payments'),
    LsbCard(id: 'tr05', gloss: 'CONSULTA', displayText: 'CONSULTA', iconUrl: '', videoUrl: _vp,
      categoryId: 'Trámites', subcategoryId: 'Información', contexts: ['general'],
      priority: 5, suggestedNextCardIds: ['sv06','in01'], isFrequent: true, isEmergency: false, semanticIcon: 'question_answer'),
    LsbCard(id: 'tr06', gloss: 'RECLAMO', displayText: 'RECLAMO', iconUrl: '', videoUrl: _vp,
      categoryId: 'Trámites', subcategoryId: 'Queja', contexts: ['general'],
      priority: 6, suggestedNextCardIds: ['sv06','in01'], isFrequent: true, isEmergency: false, semanticIcon: 'feedback'),
    LsbCard(id: 'tr07', gloss: 'CITA', displayText: 'CITA', iconUrl: '', videoUrl: _vp,
      categoryId: 'Trámites', subcategoryId: 'Programación', contexts: ['salud','general'],
      priority: 7, suggestedNextCardIds: ['in07','ti01'], isFrequent: true, isEmergency: false, semanticIcon: 'event'),
    LsbCard(id: 'tr08', gloss: 'TURNO', displayText: 'TURNO', iconUrl: '', videoUrl: _vp,
      categoryId: 'Trámites', subcategoryId: 'Programación', contexts: ['general'],
      priority: 8, suggestedNextCardIds: [], isFrequent: true, isEmergency: false, semanticIcon: 'confirmation_number'),
    LsbCard(id: 'tr09', gloss: 'DUPLICADO', displayText: 'DUPLICADO', iconUrl: '', videoUrl: _vp,
      categoryId: 'Trámites', subcategoryId: 'Gestión', contexts: ['municipio'],
      priority: 9, suggestedNextCardIds: ['do04','do01'], isFrequent: true, isEmergency: false, semanticIcon: 'content_copy'),

    // ═══════════════════════════════════════════════════════════
    // DOCUMENTOS — Papeles y certificados
    // ═══════════════════════════════════════════════════════════
    LsbCard(id: 'do01', gloss: 'DOCUMENTO', displayText: 'DOCUMENTO', iconUrl: '', videoUrl: _vp,
      categoryId: 'Documentos', subcategoryId: 'General', contexts: ['general'],
      priority: 1, suggestedNextCardIds: [], isFrequent: true, isEmergency: false, semanticIcon: 'article'),
    LsbCard(id: 'do02', gloss: 'CERTIFICADO', displayText: 'CERTIFICADO', iconUrl: '', videoUrl: _vp,
      categoryId: 'Documentos', subcategoryId: 'Oficial', contexts: ['municipio'],
      priority: 2, suggestedNextCardIds: [], isFrequent: true, isEmergency: false, semanticIcon: 'workspace_premium'),
    LsbCard(id: 'do03', gloss: 'FORMULARIO', displayText: 'FORMULARIO', iconUrl: '', videoUrl: _vp,
      categoryId: 'Documentos', subcategoryId: 'Oficial', contexts: ['municipio'],
      priority: 3, suggestedNextCardIds: [], isFrequent: true, isEmergency: false, semanticIcon: 'description'),
    LsbCard(id: 'do04', gloss: 'CARNET', displayText: 'CARNET', iconUrl: '', videoUrl: _vp,
      categoryId: 'Documentos', subcategoryId: 'Identificación', contexts: ['municipio'],
      priority: 4, suggestedNextCardIds: ['in04'], isFrequent: true, isEmergency: false, semanticIcon: 'badge'),
    LsbCard(id: 'do05', gloss: 'PARTIDA_NACIMIENTO', displayText: 'PARTIDA NAC.', iconUrl: '', videoUrl: _vp,
      categoryId: 'Documentos', subcategoryId: 'Civil', contexts: ['municipio'],
      priority: 5, suggestedNextCardIds: ['in03'], isFrequent: true, isEmergency: false, semanticIcon: 'child_friendly'),
    LsbCard(id: 'do06', gloss: 'CERTIFICADO_MATRIMONIO', displayText: 'CERT. MATRIM.', iconUrl: '', videoUrl: _vp,
      categoryId: 'Documentos', subcategoryId: 'Civil', contexts: ['municipio'],
      priority: 6, suggestedNextCardIds: ['in03'], isFrequent: true, isEmergency: false, semanticIcon: 'favorite'),
    LsbCard(id: 'do07', gloss: 'CERTIFICADO_DEFUNCION', displayText: 'CERT. DEFUNC.', iconUrl: '', videoUrl: _vp,
      categoryId: 'Documentos', subcategoryId: 'Civil', contexts: ['municipio'],
      priority: 7, suggestedNextCardIds: ['in03'], isFrequent: false, isEmergency: false, semanticIcon: 'sentiment_very_dissatisfied'),
    LsbCard(id: 'do08', gloss: 'LICENCIA', displayText: 'LICENCIA', iconUrl: '', videoUrl: _vp,
      categoryId: 'Documentos', subcategoryId: 'Oficial', contexts: ['municipio'],
      priority: 8, suggestedNextCardIds: [], isFrequent: true, isEmergency: false, semanticIcon: 'directions_car'),
    LsbCard(id: 'do09', gloss: 'FACTURA', displayText: 'FACTURA', iconUrl: '', videoUrl: _vp,
      categoryId: 'Documentos', subcategoryId: 'Pago', contexts: ['municipio'],
      priority: 9, suggestedNextCardIds: ['in05'], isFrequent: true, isEmergency: false, semanticIcon: 'receipt_long'),
    LsbCard(id: 'do10', gloss: 'FOTOCOPIA', displayText: 'FOTOCOPIA', iconUrl: '', videoUrl: _vp,
      categoryId: 'Documentos', subcategoryId: 'General', contexts: ['general'],
      priority: 10, suggestedNextCardIds: [], isFrequent: true, isEmergency: false, semanticIcon: 'content_copy'),
    LsbCard(id: 'do11', gloss: 'PASAPORTE', displayText: 'PASAPORTE', iconUrl: '', videoUrl: _vp,
      categoryId: 'Documentos', subcategoryId: 'Identificación', contexts: ['municipio'],
      priority: 11, suggestedNextCardIds: [], isFrequent: true, isEmergency: false, semanticIcon: 'flight'),
    LsbCard(id: 'do12', gloss: 'ANTECEDENTES', displayText: 'ANTECEDENTES', iconUrl: '', videoUrl: _vp,
      categoryId: 'Documentos', subcategoryId: 'Oficial', contexts: ['municipio'],
      priority: 12, suggestedNextCardIds: [], isFrequent: true, isEmergency: false, semanticIcon: 'verified_user'),

    // ═══════════════════════════════════════════════════════════
    // TIEMPO — Cuándo
    // ═══════════════════════════════════════════════════════════
    LsbCard(id: 'ti01', gloss: 'HOY', displayText: 'HOY', iconUrl: '', videoUrl: _vp,
      categoryId: 'Tiempo', subcategoryId: 'Presente', contexts: ['general'],
      priority: 1, suggestedNextCardIds: [], isFrequent: true, isEmergency: false, semanticIcon: 'today'),
    LsbCard(id: 'ti02', gloss: 'AHORA', displayText: 'AHORA', iconUrl: '', videoUrl: _vp,
      categoryId: 'Tiempo', subcategoryId: 'Presente', contexts: ['general'],
      priority: 2, suggestedNextCardIds: [], isFrequent: true, isEmergency: false, semanticIcon: 'access_time'),
    LsbCard(id: 'ti03', gloss: 'AYER', displayText: 'AYER', iconUrl: '', videoUrl: _vp,
      categoryId: 'Tiempo', subcategoryId: 'Pasado', contexts: ['general'],
      priority: 3, suggestedNextCardIds: [], isFrequent: true, isEmergency: false, semanticIcon: 'history'),
    LsbCard(id: 'ti04', gloss: 'MAÑANA', displayText: 'MAÑANA', iconUrl: '', videoUrl: _vp,
      categoryId: 'Tiempo', subcategoryId: 'Horario', contexts: ['general'],
      priority: 4, suggestedNextCardIds: [], isFrequent: true, isEmergency: false, semanticIcon: 'wb_sunny'),
    LsbCard(id: 'ti05', gloss: 'TARDE', displayText: 'TARDE', iconUrl: '', videoUrl: _vp,
      categoryId: 'Tiempo', subcategoryId: 'Horario', contexts: ['general'],
      priority: 5, suggestedNextCardIds: [], isFrequent: false, isEmergency: false, semanticIcon: 'wb_twilight'),
    LsbCard(id: 'ti06', gloss: 'SEMANA', displayText: 'SEMANA', iconUrl: '', videoUrl: _vp,
      categoryId: 'Tiempo', subcategoryId: 'Periodo', contexts: ['general'],
      priority: 6, suggestedNextCardIds: [], isFrequent: false, isEmergency: false, semanticIcon: 'date_range'),

    // ═══════════════════════════════════════════════════════════
    // INSTITUCIONES — Entidades públicas
    // ═══════════════════════════════════════════════════════════
    LsbCard(id: 'in01', gloss: 'ALCALDIA', displayText: 'ALCALDÍA', iconUrl: '', videoUrl: _vp,
      categoryId: 'Instituciones', subcategoryId: 'Gobierno', contexts: ['municipio'],
      priority: 1, suggestedNextCardIds: [], isFrequent: true, isEmergency: false, semanticIcon: 'account_balance'),
    LsbCard(id: 'in02', gloss: 'GOBERNACION', displayText: 'GOBERNACIÓN', iconUrl: '', videoUrl: _vp,
      categoryId: 'Instituciones', subcategoryId: 'Gobierno', contexts: ['municipio'],
      priority: 2, suggestedNextCardIds: [], isFrequent: true, isEmergency: false, semanticIcon: 'domain'),
    LsbCard(id: 'in03', gloss: 'REGISTRO_CIVIL', displayText: 'REG. CIVIL', iconUrl: '', videoUrl: _vp,
      categoryId: 'Instituciones', subcategoryId: 'Civil', contexts: ['municipio'],
      priority: 3, suggestedNextCardIds: ['do05','do06'], isFrequent: true, isEmergency: false, semanticIcon: 'menu_book'),
    LsbCard(id: 'in04', gloss: 'SEGIP', displayText: 'SEGIP', iconUrl: '', videoUrl: _vp,
      categoryId: 'Instituciones', subcategoryId: 'Identificación', contexts: ['municipio'],
      priority: 4, suggestedNextCardIds: ['do04'], isFrequent: true, isEmergency: false, semanticIcon: 'badge'),
    LsbCard(id: 'in05', gloss: 'IMPUESTOS', displayText: 'IMPUESTOS', iconUrl: '', videoUrl: _vp,
      categoryId: 'Instituciones', subcategoryId: 'Fiscal', contexts: ['municipio'],
      priority: 5, suggestedNextCardIds: ['do09','ac05'], isFrequent: true, isEmergency: false, semanticIcon: 'request_quote'),
    LsbCard(id: 'in06', gloss: 'BANCO', displayText: 'BANCO', iconUrl: '', videoUrl: _vp,
      categoryId: 'Instituciones', subcategoryId: 'Financiero', contexts: ['municipio'],
      priority: 6, suggestedNextCardIds: ['ac05'], isFrequent: true, isEmergency: false, semanticIcon: 'account_balance_wallet'),
    LsbCard(id: 'in07', gloss: 'HOSPITAL', displayText: 'HOSPITAL', iconUrl: '', videoUrl: _vp,
      categoryId: 'Instituciones', subcategoryId: 'Salud', contexts: ['salud'],
      priority: 7, suggestedNextCardIds: ['sv03','tr07'], isFrequent: true, isEmergency: true, semanticIcon: 'local_hospital'),
    LsbCard(id: 'in08', gloss: 'ESCUELA', displayText: 'ESCUELA', iconUrl: '', videoUrl: _vp,
      categoryId: 'Instituciones', subcategoryId: 'Educación', contexts: ['educacion'],
      priority: 8, suggestedNextCardIds: ['ac07','tr02'], isFrequent: true, isEmergency: false, semanticIcon: 'school'),
    LsbCard(id: 'in09', gloss: 'NOTARIA', displayText: 'NOTARÍA', iconUrl: '', videoUrl: _vp,
      categoryId: 'Instituciones', subcategoryId: 'Legal', contexts: ['municipio'],
      priority: 9, suggestedNextCardIds: ['ac11','do01'], isFrequent: true, isEmergency: false, semanticIcon: 'gavel'),
    LsbCard(id: 'in10', gloss: 'POLICIA', displayText: 'POLICÍA', iconUrl: '', videoUrl: _vp,
      categoryId: 'Instituciones', subcategoryId: 'Seguridad', contexts: ['general'],
      priority: 10, suggestedNextCardIds: ['tr06'], isFrequent: true, isEmergency: true, semanticIcon: 'local_police'),
    LsbCard(id: 'in11', gloss: 'DEFENSORIA', displayText: 'DEFENSORÍA', iconUrl: '', videoUrl: _vp,
      categoryId: 'Instituciones', subcategoryId: 'Social', contexts: ['general'],
      priority: 11, suggestedNextCardIds: ['sv06','tr06'], isFrequent: false, isEmergency: false, semanticIcon: 'shield'),
    LsbCard(id: 'in12', gloss: 'OFICINA', displayText: 'OFICINA', iconUrl: '', videoUrl: _vp,
      categoryId: 'Instituciones', subcategoryId: 'General', contexts: ['general'],
      priority: 12, suggestedNextCardIds: [], isFrequent: false, isEmergency: false, semanticIcon: 'business'),

    // ═══════════════════════════════════════════════════════════
    // SERVICIOS — Ayuda y atención
    // ═══════════════════════════════════════════════════════════
    LsbCard(id: 'sv01', gloss: 'INTERPRETE', displayText: 'INTÉRPRETE', iconUrl: '', videoUrl: _vp,
      categoryId: 'Servicios', subcategoryId: 'Accesibilidad', contexts: ['general'],
      priority: 1, suggestedNextCardIds: [], isFrequent: true, isEmergency: false, semanticIcon: 'sign_language'),
    LsbCard(id: 'sv02', gloss: 'INFORMACION', displayText: 'INFORMACIÓN', iconUrl: '', videoUrl: _vp,
      categoryId: 'Servicios', subcategoryId: 'Atención', contexts: ['general'],
      priority: 2, suggestedNextCardIds: [], isFrequent: true, isEmergency: false, semanticIcon: 'info'),
    LsbCard(id: 'sv03', gloss: 'DOCTOR', displayText: 'DOCTOR', iconUrl: '', videoUrl: _vp,
      categoryId: 'Servicios', subcategoryId: 'Salud', contexts: ['salud'],
      priority: 3, suggestedNextCardIds: [], isFrequent: true, isEmergency: true, semanticIcon: 'medical_services'),
    LsbCard(id: 'sv04', gloss: 'ABOGADO', displayText: 'ABOGADO', iconUrl: '', videoUrl: _vp,
      categoryId: 'Servicios', subcategoryId: 'Legal', contexts: ['municipio'],
      priority: 4, suggestedNextCardIds: [], isFrequent: true, isEmergency: false, semanticIcon: 'balance'),
    LsbCard(id: 'sv05', gloss: 'ATENCION', displayText: 'ATENCIÓN', iconUrl: '', videoUrl: _vp,
      categoryId: 'Servicios', subcategoryId: 'Atención', contexts: ['general'],
      priority: 5, suggestedNextCardIds: [], isFrequent: true, isEmergency: false, semanticIcon: 'support_agent'),
    LsbCard(id: 'sv06', gloss: 'ORIENTACION', displayText: 'ORIENTACIÓN', iconUrl: '', videoUrl: _vp,
      categoryId: 'Servicios', subcategoryId: 'Información', contexts: ['general'],
      priority: 6, suggestedNextCardIds: [], isFrequent: true, isEmergency: false, semanticIcon: 'explore'),
    LsbCard(id: 'sv07', gloss: 'AMBULANCIA', displayText: 'AMBULANCIA', iconUrl: '', videoUrl: _vp,
      categoryId: 'Servicios', subcategoryId: 'Emergencia', contexts: ['general'],
      priority: 7, suggestedNextCardIds: [], isFrequent: true, isEmergency: true, semanticIcon: 'emergency'),

    // ═══════════════════════════════════════════════════════════
    // ESTADO / URGENCIA — Marcadores de prioridad y estado
    // ═══════════════════════════════════════════════════════════
    LsbCard(id: 'eu01', gloss: 'URGENTE', displayText: 'URGENTE', iconUrl: '', videoUrl: _vp,
      categoryId: 'Estado/Urgencia', subcategoryId: 'Prioridad', contexts: ['general'],
      priority: 1, suggestedNextCardIds: [], isFrequent: true, isEmergency: true, semanticIcon: 'priority_high'),
    LsbCard(id: 'eu02', gloss: 'AYUDA', displayText: 'AYUDA', iconUrl: '', videoUrl: _vp,
      categoryId: 'Estado/Urgencia', subcategoryId: 'Solicitud', contexts: ['general'],
      priority: 2, suggestedNextCardIds: ['sv01','sv03'], isFrequent: true, isEmergency: true, semanticIcon: 'sos'),
    LsbCard(id: 'eu03', gloss: 'EMERGENCIA', displayText: 'EMERGENCIA', iconUrl: '', videoUrl: _vp,
      categoryId: 'Estado/Urgencia', subcategoryId: 'Crítico', contexts: ['general'],
      priority: 3, suggestedNextCardIds: ['sv07'], isFrequent: true, isEmergency: true, semanticIcon: 'crisis_alert'),
    LsbCard(id: 'eu04', gloss: 'ENFERMO', displayText: 'ENFERMO', iconUrl: '', videoUrl: _vp,
      categoryId: 'Estado/Urgencia', subcategoryId: 'Estado', contexts: ['salud'],
      priority: 4, suggestedNextCardIds: ['sv03','in07'], isFrequent: true, isEmergency: true, semanticIcon: 'sick'),
    LsbCard(id: 'eu05', gloss: 'DOLOR', displayText: 'DOLOR', iconUrl: '', videoUrl: _vp,
      categoryId: 'Estado/Urgencia', subcategoryId: 'Estado', contexts: ['salud'],
      priority: 5, suggestedNextCardIds: ['sv03','sv07'], isFrequent: true, isEmergency: true, semanticIcon: 'healing'),
    LsbCard(id: 'eu06', gloss: 'CONFUNDIDO', displayText: 'CONFUNDIDO', iconUrl: '', videoUrl: _vp,
      categoryId: 'Estado/Urgencia', subcategoryId: 'Estado', contexts: ['general'],
      priority: 6, suggestedNextCardIds: ['sv02','sv06'], isFrequent: true, isEmergency: false, semanticIcon: 'help_outline'),
    LsbCard(id: 'eu07', gloss: 'PERDIDO', displayText: 'PERDIDO', iconUrl: '', videoUrl: _vp,
      categoryId: 'Estado/Urgencia', subcategoryId: 'Estado', contexts: ['general'],
      priority: 7, suggestedNextCardIds: ['sv02'], isFrequent: true, isEmergency: false, semanticIcon: 'location_off'),
  ];

  /// Orden predefinido de las categorías ciudadanas.
  static const _categoryOrder = [
    'Identificación', 'Acciones', 'Trámites', 'Documentos',
    'Tiempo', 'Instituciones', 'Servicios', 'Estado/Urgencia',
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
