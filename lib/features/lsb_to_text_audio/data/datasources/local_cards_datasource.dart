import '../../domain/entities/lsb_card.dart';

/// Fuente de datos local con el catálogo de tarjetas LSB
/// especializadas en el dominio jurídico/administrativo.
///
/// 9 categorías: Identificación, Agresores, Acciones, Objetos,
/// Delitos, Tiempo, Lugares, Servicios, Urgencia.
class LocalCardsDataSource {
  // Video placeholder — reemplazar con videos reales de corpus LSB
  static const _vp = 'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4';

  final List<LsbCard> _cards = [
    // ═══════════════════════════════════════════════════════════
    // IDENTIFICACIÓN — Sujetos y familiares
    // ═══════════════════════════════════════════════════════════
    LsbCard(id: 'id01', gloss: 'YO', displayText: 'YO', iconUrl: '', videoUrl: _vp,
      categoryId: 'Identificación', subcategoryId: 'Persona', contexts: ['general'],
      priority: 1, suggestedNextCardIds: ['ac01','ac03'], isFrequent: true, isEmergency: false, semanticIcon: 'person'),
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
    // AGRESORES — Personas externas
    // ═══════════════════════════════════════════════════════════
    LsbCard(id: 'ag01', gloss: 'HOMBRE', displayText: 'HOMBRE', iconUrl: '', videoUrl: _vp,
      categoryId: 'Agresores', subcategoryId: 'Persona', contexts: ['policia'],
      priority: 1, suggestedNextCardIds: ['ac02','ac04'], isFrequent: true, isEmergency: true, semanticIcon: 'person_outline'),
    LsbCard(id: 'ag02', gloss: 'MUJER', displayText: 'MUJER', iconUrl: '', videoUrl: _vp,
      categoryId: 'Agresores', subcategoryId: 'Persona', contexts: ['policia'],
      priority: 2, suggestedNextCardIds: [], isFrequent: true, isEmergency: false, semanticIcon: 'person_outline'),
    LsbCard(id: 'ag03', gloss: 'DESCONOCIDO', displayText: 'DESCONOCIDO', iconUrl: '', videoUrl: _vp,
      categoryId: 'Agresores', subcategoryId: 'Persona', contexts: ['policia'],
      priority: 3, suggestedNextCardIds: [], isFrequent: true, isEmergency: true, semanticIcon: 'help_outline'),
    LsbCard(id: 'ag04', gloss: 'LADRON', displayText: 'LADRÓN', iconUrl: '', videoUrl: _vp,
      categoryId: 'Agresores', subcategoryId: 'Crimen', contexts: ['policia'],
      priority: 4, suggestedNextCardIds: [], isFrequent: true, isEmergency: true, semanticIcon: 'warning'),
    LsbCard(id: 'ag05', gloss: 'AGRESOR', displayText: 'AGRESOR', iconUrl: '', videoUrl: _vp,
      categoryId: 'Agresores', subcategoryId: 'Crimen', contexts: ['policia','juzgado'],
      priority: 5, suggestedNextCardIds: [], isFrequent: true, isEmergency: true, semanticIcon: 'dangerous'),
    LsbCard(id: 'ag06', gloss: 'GRUPO', displayText: 'GRUPO', iconUrl: '', videoUrl: _vp,
      categoryId: 'Agresores', subcategoryId: 'Persona', contexts: ['policia'],
      priority: 6, suggestedNextCardIds: [], isFrequent: false, isEmergency: true, semanticIcon: 'groups'),

    // ═══════════════════════════════════════════════════════════
    // ACCIONES — Verbos principales
    // ═══════════════════════════════════════════════════════════
    LsbCard(id: 'ac01', gloss: 'DENUNCIAR', displayText: 'DENUNCIAR', iconUrl: '', videoUrl: _vp,
      categoryId: 'Acciones', subcategoryId: 'Legal', contexts: ['policia','juzgado'],
      priority: 1, suggestedNextCardIds: ['de01','de02'], isFrequent: true, isEmergency: false, semanticIcon: 'gavel'),
    LsbCard(id: 'ac02', gloss: 'ROBAR', displayText: 'ROBAR', iconUrl: '', videoUrl: _vp,
      categoryId: 'Acciones', subcategoryId: 'Crimen', contexts: ['policia'],
      priority: 2, suggestedNextCardIds: ['ob01','ob03'], isFrequent: true, isEmergency: true, semanticIcon: 'report'),
    LsbCard(id: 'ac03', gloss: 'NECESITAR', displayText: 'NECESITAR', iconUrl: '', videoUrl: _vp,
      categoryId: 'Acciones', subcategoryId: 'Solicitud', contexts: ['general'],
      priority: 3, suggestedNextCardIds: ['sv01','sv02'], isFrequent: true, isEmergency: false, semanticIcon: 'front_hand'),
    LsbCard(id: 'ac04', gloss: 'QUITAR', displayText: 'QUITAR', iconUrl: '', videoUrl: _vp,
      categoryId: 'Acciones', subcategoryId: 'Crimen', contexts: ['policia'],
      priority: 4, suggestedNextCardIds: [], isFrequent: true, isEmergency: true, semanticIcon: 'swipe_left'),
    LsbCard(id: 'ac05', gloss: 'GOLPEAR', displayText: 'GOLPEAR', iconUrl: '', videoUrl: _vp,
      categoryId: 'Acciones', subcategoryId: 'Crimen', contexts: ['policia'],
      priority: 5, suggestedNextCardIds: [], isFrequent: true, isEmergency: true, semanticIcon: 'sports_mma'),
    LsbCard(id: 'ac06', gloss: 'AMENAZAR', displayText: 'AMENAZAR', iconUrl: '', videoUrl: _vp,
      categoryId: 'Acciones', subcategoryId: 'Crimen', contexts: ['policia','juzgado'],
      priority: 6, suggestedNextCardIds: [], isFrequent: true, isEmergency: true, semanticIcon: 'warning_amber'),
    LsbCard(id: 'ac07', gloss: 'PERDER', displayText: 'PERDER', iconUrl: '', videoUrl: _vp,
      categoryId: 'Acciones', subcategoryId: 'General', contexts: ['general'],
      priority: 7, suggestedNextCardIds: ['ob04','ob06'], isFrequent: true, isEmergency: false, semanticIcon: 'search_off'),
    LsbCard(id: 'ac08', gloss: 'DESCRIBIR', displayText: 'DESCRIBIR', iconUrl: '', videoUrl: _vp,
      categoryId: 'Acciones', subcategoryId: 'Legal', contexts: ['policia'],
      priority: 8, suggestedNextCardIds: ['ag01','ag02'], isFrequent: true, isEmergency: false, semanticIcon: 'description'),
    LsbCard(id: 'ac09', gloss: 'SEGUIR', displayText: 'SEGUIR', iconUrl: '', videoUrl: _vp,
      categoryId: 'Acciones', subcategoryId: 'Crimen', contexts: ['policia'],
      priority: 9, suggestedNextCardIds: [], isFrequent: false, isEmergency: true, semanticIcon: 'directions_walk'),
    LsbCard(id: 'ac10', gloss: 'PEDIR', displayText: 'PEDIR', iconUrl: '', videoUrl: _vp,
      categoryId: 'Acciones', subcategoryId: 'Solicitud', contexts: ['general'],
      priority: 10, suggestedNextCardIds: ['sv01'], isFrequent: true, isEmergency: false, semanticIcon: 'record_voice_over'),
    LsbCard(id: 'ac11', gloss: 'CORRER', displayText: 'CORRER', iconUrl: '', videoUrl: _vp,
      categoryId: 'Acciones', subcategoryId: 'Movimiento', contexts: ['policia'],
      priority: 11, suggestedNextCardIds: [], isFrequent: true, isEmergency: false, semanticIcon: 'directions_run'),
    LsbCard(id: 'ac12', gloss: 'HUIR', displayText: 'HUIR', iconUrl: '', videoUrl: _vp,
      categoryId: 'Acciones', subcategoryId: 'Movimiento', contexts: ['policia'],
      priority: 12, suggestedNextCardIds: [], isFrequent: true, isEmergency: false, semanticIcon: 'exit_to_app'),

    // ═══════════════════════════════════════════════════════════
    // OBJETOS — Cosas afectadas
    // ═══════════════════════════════════════════════════════════
    LsbCard(id: 'ob01', gloss: 'MOCHILA', displayText: 'MOCHILA', iconUrl: '', videoUrl: _vp,
      categoryId: 'Objetos', subcategoryId: 'Personal', contexts: ['policia'],
      priority: 1, suggestedNextCardIds: [], isFrequent: true, isEmergency: false, semanticIcon: 'backpack'),
    LsbCard(id: 'ob02', gloss: 'CELULAR', displayText: 'CELULAR', iconUrl: '', videoUrl: _vp,
      categoryId: 'Objetos', subcategoryId: 'Electrónico', contexts: ['policia'],
      priority: 2, suggestedNextCardIds: [], isFrequent: true, isEmergency: false, semanticIcon: 'smartphone'),
    LsbCard(id: 'ob03', gloss: 'DINERO', displayText: 'DINERO', iconUrl: '', videoUrl: _vp,
      categoryId: 'Objetos', subcategoryId: 'Valor', contexts: ['policia'],
      priority: 3, suggestedNextCardIds: [], isFrequent: true, isEmergency: false, semanticIcon: 'payments'),
    LsbCard(id: 'ob04', gloss: 'DOCUMENTO', displayText: 'DOCUMENTO', iconUrl: '', videoUrl: _vp,
      categoryId: 'Objetos', subcategoryId: 'Legal', contexts: ['policia','juzgado'],
      priority: 4, suggestedNextCardIds: [], isFrequent: true, isEmergency: false, semanticIcon: 'article'),
    LsbCard(id: 'ob05', gloss: 'BILLETERA', displayText: 'BILLETERA', iconUrl: '', videoUrl: _vp,
      categoryId: 'Objetos', subcategoryId: 'Personal', contexts: ['policia'],
      priority: 5, suggestedNextCardIds: [], isFrequent: true, isEmergency: false, semanticIcon: 'account_balance_wallet'),
    LsbCard(id: 'ob06', gloss: 'CARNET', displayText: 'CARNET', iconUrl: '', videoUrl: _vp,
      categoryId: 'Objetos', subcategoryId: 'Legal', contexts: ['policia','juzgado'],
      priority: 6, suggestedNextCardIds: [], isFrequent: true, isEmergency: false, semanticIcon: 'badge'),
    LsbCard(id: 'ob07', gloss: 'LLAVES', displayText: 'LLAVES', iconUrl: '', videoUrl: _vp,
      categoryId: 'Objetos', subcategoryId: 'Personal', contexts: ['policia'],
      priority: 7, suggestedNextCardIds: [], isFrequent: false, isEmergency: false, semanticIcon: 'vpn_key'),
    LsbCard(id: 'ob08', gloss: 'AUTO', displayText: 'AUTO', iconUrl: '', videoUrl: _vp,
      categoryId: 'Objetos', subcategoryId: 'Vehículo', contexts: ['policia'],
      priority: 8, suggestedNextCardIds: [], isFrequent: false, isEmergency: false, semanticIcon: 'directions_car'),

    // ═══════════════════════════════════════════════════════════
    // DELITOS — Tipos de evento
    // ═══════════════════════════════════════════════════════════
    LsbCard(id: 'de01', gloss: 'ROBO', displayText: 'ROBO', iconUrl: '', videoUrl: _vp,
      categoryId: 'Delitos', subcategoryId: 'Crimen', contexts: ['policia','juzgado'],
      priority: 1, suggestedNextCardIds: ['ti01','lu01'], isFrequent: true, isEmergency: true, semanticIcon: 'local_police'),
    LsbCard(id: 'de02', gloss: 'GOLPE', displayText: 'AGRESIÓN', iconUrl: '', videoUrl: _vp,
      categoryId: 'Delitos', subcategoryId: 'Crimen', contexts: ['policia','juzgado'],
      priority: 2, suggestedNextCardIds: [], isFrequent: true, isEmergency: true, semanticIcon: 'personal_injury'),
    LsbCard(id: 'de03', gloss: 'DENUNCIA', displayText: 'DENUNCIA', iconUrl: '', videoUrl: _vp,
      categoryId: 'Delitos', subcategoryId: 'Legal', contexts: ['policia','juzgado'],
      priority: 3, suggestedNextCardIds: [], isFrequent: true, isEmergency: false, semanticIcon: 'gavel'),

    // ═══════════════════════════════════════════════════════════
    // TIEMPO — Cuándo ocurrió
    // ═══════════════════════════════════════════════════════════
    LsbCard(id: 'ti01', gloss: 'NOCHE', displayText: 'NOCHE', iconUrl: '', videoUrl: _vp,
      categoryId: 'Tiempo', subcategoryId: 'Horario', contexts: ['general'],
      priority: 1, suggestedNextCardIds: [], isFrequent: true, isEmergency: false, semanticIcon: 'dark_mode'),
    LsbCard(id: 'ti02', gloss: 'DIA', displayText: 'DÍA', iconUrl: '', videoUrl: _vp,
      categoryId: 'Tiempo', subcategoryId: 'Horario', contexts: ['general'],
      priority: 2, suggestedNextCardIds: [], isFrequent: true, isEmergency: false, semanticIcon: 'light_mode'),
    LsbCard(id: 'ti03', gloss: 'AYER', displayText: 'AYER', iconUrl: '', videoUrl: _vp,
      categoryId: 'Tiempo', subcategoryId: 'Pasado', contexts: ['general'],
      priority: 3, suggestedNextCardIds: [], isFrequent: true, isEmergency: false, semanticIcon: 'history'),
    LsbCard(id: 'ti04', gloss: 'HOY', displayText: 'HOY', iconUrl: '', videoUrl: _vp,
      categoryId: 'Tiempo', subcategoryId: 'Presente', contexts: ['general'],
      priority: 4, suggestedNextCardIds: [], isFrequent: true, isEmergency: false, semanticIcon: 'today'),
    LsbCard(id: 'ti05', gloss: 'AHORA', displayText: 'AHORA', iconUrl: '', videoUrl: _vp,
      categoryId: 'Tiempo', subcategoryId: 'Presente', contexts: ['general'],
      priority: 5, suggestedNextCardIds: [], isFrequent: true, isEmergency: true, semanticIcon: 'access_time'),
    LsbCard(id: 'ti06', gloss: 'MAÑANA', displayText: 'MAÑANA', iconUrl: '', videoUrl: _vp,
      categoryId: 'Tiempo', subcategoryId: 'Horario', contexts: ['general'],
      priority: 6, suggestedNextCardIds: [], isFrequent: false, isEmergency: false, semanticIcon: 'wb_sunny'),
    LsbCard(id: 'ti07', gloss: 'TARDE', displayText: 'TARDE', iconUrl: '', videoUrl: _vp,
      categoryId: 'Tiempo', subcategoryId: 'Horario', contexts: ['general'],
      priority: 7, suggestedNextCardIds: [], isFrequent: false, isEmergency: false, semanticIcon: 'wb_twilight'),

    // ═══════════════════════════════════════════════════════════
    // LUGARES — Dónde ocurrió
    // ═══════════════════════════════════════════════════════════
    LsbCard(id: 'lu01', gloss: 'CALLE', displayText: 'CALLE', iconUrl: '', videoUrl: _vp,
      categoryId: 'Lugares', subcategoryId: 'Exterior', contexts: ['policia'],
      priority: 1, suggestedNextCardIds: [], isFrequent: true, isEmergency: false, semanticIcon: 'add_road'),
    LsbCard(id: 'lu02', gloss: 'PARADA', displayText: 'PARADA', iconUrl: '', videoUrl: _vp,
      categoryId: 'Lugares', subcategoryId: 'Transporte', contexts: ['policia'],
      priority: 2, suggestedNextCardIds: ['lu03'], isFrequent: true, isEmergency: false, semanticIcon: 'directions_bus'),
    LsbCard(id: 'lu03', gloss: 'MICRO', displayText: 'MICRO', iconUrl: '', videoUrl: _vp,
      categoryId: 'Lugares', subcategoryId: 'Transporte', contexts: ['policia'],
      priority: 3, suggestedNextCardIds: [], isFrequent: true, isEmergency: false, semanticIcon: 'directions_bus'),
    LsbCard(id: 'lu04', gloss: 'CASA', displayText: 'CASA', iconUrl: '', videoUrl: _vp,
      categoryId: 'Lugares', subcategoryId: 'Residencia', contexts: ['general'],
      priority: 4, suggestedNextCardIds: [], isFrequent: true, isEmergency: false, semanticIcon: 'home'),
    LsbCard(id: 'lu05', gloss: 'PLAZA', displayText: 'PLAZA', iconUrl: '', videoUrl: _vp,
      categoryId: 'Lugares', subcategoryId: 'Exterior', contexts: ['policia'],
      priority: 5, suggestedNextCardIds: [], isFrequent: false, isEmergency: false, semanticIcon: 'park'),
    LsbCard(id: 'lu06', gloss: 'MERCADO', displayText: 'MERCADO', iconUrl: '', videoUrl: _vp,
      categoryId: 'Lugares', subcategoryId: 'Comercio', contexts: ['policia'],
      priority: 6, suggestedNextCardIds: [], isFrequent: false, isEmergency: false, semanticIcon: 'storefront'),
    LsbCard(id: 'lu07', gloss: 'HOSPITAL', displayText: 'HOSPITAL', iconUrl: '', videoUrl: _vp,
      categoryId: 'Lugares', subcategoryId: 'Institución', contexts: ['general'],
      priority: 7, suggestedNextCardIds: [], isFrequent: true, isEmergency: true, semanticIcon: 'local_hospital'),
    LsbCard(id: 'lu08', gloss: 'TRABAJO', displayText: 'TRABAJO', iconUrl: '', videoUrl: _vp,
      categoryId: 'Lugares', subcategoryId: 'Laboral', contexts: ['general'],
      priority: 8, suggestedNextCardIds: [], isFrequent: false, isEmergency: false, semanticIcon: 'work'),

    // ═══════════════════════════════════════════════════════════
    // SERVICIOS — Instituciones y ayuda
    // ═══════════════════════════════════════════════════════════
    LsbCard(id: 'sv01', gloss: 'POLICIA', displayText: 'POLICÍA', iconUrl: '', videoUrl: _vp,
      categoryId: 'Servicios', subcategoryId: 'Seguridad', contexts: ['policia'],
      priority: 1, suggestedNextCardIds: [], isFrequent: true, isEmergency: true, semanticIcon: 'local_police'),
    LsbCard(id: 'sv02', gloss: 'ABOGADO', displayText: 'ABOGADO', iconUrl: '', videoUrl: _vp,
      categoryId: 'Servicios', subcategoryId: 'Legal', contexts: ['juzgado'],
      priority: 2, suggestedNextCardIds: [], isFrequent: true, isEmergency: false, semanticIcon: 'balance'),
    LsbCard(id: 'sv03', gloss: 'DOCTOR', displayText: 'DOCTOR', iconUrl: '', videoUrl: _vp,
      categoryId: 'Servicios', subcategoryId: 'Salud', contexts: ['general'],
      priority: 3, suggestedNextCardIds: [], isFrequent: true, isEmergency: true, semanticIcon: 'medical_services'),
    LsbCard(id: 'sv04', gloss: 'AMBULANCIA', displayText: 'AMBULANCIA', iconUrl: '', videoUrl: _vp,
      categoryId: 'Servicios', subcategoryId: 'Emergencia', contexts: ['general'],
      priority: 4, suggestedNextCardIds: [], isFrequent: true, isEmergency: true, semanticIcon: 'emergency'),
    LsbCard(id: 'sv05', gloss: 'JUEZ', displayText: 'JUEZ', iconUrl: '', videoUrl: _vp,
      categoryId: 'Servicios', subcategoryId: 'Legal', contexts: ['juzgado'],
      priority: 5, suggestedNextCardIds: [], isFrequent: false, isEmergency: false, semanticIcon: 'gavel'),
    LsbCard(id: 'sv06', gloss: 'FISCAL', displayText: 'FISCAL', iconUrl: '', videoUrl: _vp,
      categoryId: 'Servicios', subcategoryId: 'Legal', contexts: ['juzgado'],
      priority: 6, suggestedNextCardIds: [], isFrequent: false, isEmergency: false, semanticIcon: 'account_balance'),
    LsbCard(id: 'sv07', gloss: 'INTERPRETE', displayText: 'INTÉRPRETE', iconUrl: '', videoUrl: _vp,
      categoryId: 'Servicios', subcategoryId: 'Accesibilidad', contexts: ['general'],
      priority: 7, suggestedNextCardIds: [], isFrequent: true, isEmergency: false, semanticIcon: 'sign_language'),
    LsbCard(id: 'sv08', gloss: 'BOMBERO', displayText: 'BOMBERO', iconUrl: '', videoUrl: _vp,
      categoryId: 'Servicios', subcategoryId: 'Emergencia', contexts: ['general'],
      priority: 8, suggestedNextCardIds: [], isFrequent: false, isEmergency: true, semanticIcon: 'fire_truck'),

    // ═══════════════════════════════════════════════════════════
    // URGENCIA — Marcadores de prioridad
    // ═══════════════════════════════════════════════════════════
    LsbCard(id: 'ur01', gloss: 'URGENTE', displayText: 'URGENTE', iconUrl: '', videoUrl: _vp,
      categoryId: 'Urgencia', subcategoryId: 'Prioridad', contexts: ['general'],
      priority: 1, suggestedNextCardIds: [], isFrequent: true, isEmergency: true, semanticIcon: 'priority_high'),
    LsbCard(id: 'ur02', gloss: 'AYUDA', displayText: 'AYUDA', iconUrl: '', videoUrl: _vp,
      categoryId: 'Urgencia', subcategoryId: 'Solicitud', contexts: ['general'],
      priority: 2, suggestedNextCardIds: ['sv01','sv03'], isFrequent: true, isEmergency: true, semanticIcon: 'sos'),
    LsbCard(id: 'ur03', gloss: 'EMERGENCIA', displayText: 'EMERGENCIA', iconUrl: '', videoUrl: _vp,
      categoryId: 'Urgencia', subcategoryId: 'Crítico', contexts: ['general'],
      priority: 3, suggestedNextCardIds: ['sv04'], isFrequent: true, isEmergency: true, semanticIcon: 'crisis_alert'),
    LsbCard(id: 'ur04', gloss: 'PELIGRO', displayText: 'PELIGRO', iconUrl: '', videoUrl: _vp,
      categoryId: 'Urgencia', subcategoryId: 'Crítico', contexts: ['general'],
      priority: 4, suggestedNextCardIds: ['sv01'], isFrequent: true, isEmergency: true, semanticIcon: 'report_problem'),
    LsbCard(id: 'ur05', gloss: 'MIEDO', displayText: 'MIEDO', iconUrl: '', videoUrl: _vp,
      categoryId: 'Urgencia', subcategoryId: 'Estado', contexts: ['general'],
      priority: 5, suggestedNextCardIds: ['sv01'], isFrequent: true, isEmergency: true, semanticIcon: 'mood_bad'),
    LsbCard(id: 'ur06', gloss: 'DOLOR', displayText: 'DOLOR', iconUrl: '', videoUrl: _vp,
      categoryId: 'Urgencia', subcategoryId: 'Estado', contexts: ['general'],
      priority: 6, suggestedNextCardIds: ['sv03','sv04'], isFrequent: true, isEmergency: true, semanticIcon: 'healing'),
    LsbCard(id: 'ur07', gloss: 'HERIDO', displayText: 'HERIDO', iconUrl: '', videoUrl: _vp,
      categoryId: 'Urgencia', subcategoryId: 'Estado', contexts: ['general'],
      priority: 7, suggestedNextCardIds: ['sv03','sv04'], isFrequent: true, isEmergency: true, semanticIcon: 'personal_injury'),
  ];

  /// Orden predefinido de las categorías jurídicas.
  static const _categoryOrder = [
    'Identificación', 'Agresores', 'Acciones', 'Objetos',
    'Delitos', 'Tiempo', 'Lugares', 'Servicios', 'Urgencia',
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
