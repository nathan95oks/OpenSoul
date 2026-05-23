import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/semantic_context.dart';

final availableContexts = [
  SemanticContext(
    id: 'robo',
    name: 'Robo o Asalto',
    icon: 'warning_amber',
    description: 'Reportar un robo, hurto o asalto',
    defaultSteps: [
      GuidedStep(id: 'que', title: '¿Qué ocurrió?', description: 'Indica la situación', targetCategories: ['Estado/Urgencia', 'Acciones']),
      GuidedStep(id: 'objeto', title: '¿Qué perdiste?', description: 'Objetos o documentos', targetCategories: ['Documentos', 'Identificación']),
      GuidedStep(id: 'quien', title: '¿Quién fue?', description: 'Personas involucradas', targetCategories: ['Identificación']),
      GuidedStep(id: 'donde', title: '¿Dónde?', description: 'Lugar de los hechos', targetCategories: ['Instituciones']),
      GuidedStep(id: 'cuando', title: '¿Cuándo?', description: 'Momento del suceso', targetCategories: ['Tiempo']),
    ],
  ),
  SemanticContext(
    id: 'tramite',
    name: 'Trámite Oficial',
    icon: 'assignment',
    description: 'Realizar un trámite o solicitud',
    defaultSteps: [
      GuidedStep(id: 'que', title: '¿Qué trámite?', description: 'Selecciona la acción', targetCategories: ['Trámites', 'Acciones']),
      GuidedStep(id: 'documento', title: '¿Qué documento?', description: 'Documento relacionado', targetCategories: ['Documentos']),
      GuidedStep(id: 'donde', title: '¿En qué institución?', description: 'Entidad pública', targetCategories: ['Instituciones']),
      GuidedStep(id: 'quien', title: '¿Para quién?', description: 'Persona que hace el trámite', targetCategories: ['Identificación']),
    ],
  ),
  SemanticContext(
    id: 'emergencia_salud',
    name: 'Emergencia Médica',
    icon: 'local_hospital',
    description: 'Atención de salud o accidente',
    defaultSteps: [
      GuidedStep(id: 'estado', title: '¿Cómo te sientes?', description: 'Estado o urgencia', targetCategories: ['Estado/Urgencia']),
      GuidedStep(id: 'quien', title: '¿Quién necesita ayuda?', description: 'Paciente', targetCategories: ['Identificación']),
      GuidedStep(id: 'servicio', title: '¿Qué necesitas?', description: 'Personal o servicio', targetCategories: ['Servicios']),
      GuidedStep(id: 'donde', title: '¿Dónde estás?', description: 'Lugar actual', targetCategories: ['Instituciones']),
    ],
  ),
  SemanticContext(
    id: 'general',
    name: 'Consulta General',
    icon: 'chat',
    description: 'Preguntas, orientación o ayuda general',
    defaultSteps: [
      GuidedStep(id: 'que', title: '¿Qué buscas?', description: 'Acción principal', targetCategories: ['Acciones', 'Servicios', 'Trámites']),
      GuidedStep(id: 'detalle', title: '¿Más detalles?', description: 'Agrega más contexto', targetCategories: ['Documentos', 'Instituciones', 'Identificación', 'Tiempo']),
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
