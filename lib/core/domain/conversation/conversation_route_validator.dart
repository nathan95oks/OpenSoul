import 'package:lsb_legal_app/core/domain/conversation/conversation_graph_catalog.dart';
import 'package:lsb_legal_app/core/domain/conversation/conversation_route.dart';
import 'package:lsb_legal_app/core/domain/guided/guided_session.dart';

/// Resultado de validar una ruta: la ruta ejecutable o el motivo del
/// rechazo (interno, nunca se muestra).
class RouteValidation {
  final ConversationRoute? route;
  final String? rejection;

  const RouteValidation.accepted(ConversationRoute this.route)
    : rejection = null;

  const RouteValidation.rejected(String this.rejection) : route = null;

  bool get isValid => route != null;
}

/// Comprueba una ruta contra el catálogo antes de ejecutarla.
///
/// Vale para cualquier ruta, pero existe por las del modelo: el modelo puede
/// rankear, no crear. Una ruta solo pasa si:
///   * cada familia, contexto y pregunta existe;
///   * la pregunta pertenece al recorrido del contexto (o el oyente la hizo
///     tal cual, y entonces se antepone como paso propio);
///   * las ranuras son ranuras del grafo;
///   * su confianza alcanza el mínimo.
/// Las dependencias obligatorias no se negocian: el recorrido se recalcula
/// con [GuidedFlow.minimalPath], así que una ruta que salta a una pregunta
/// dependiente sin su pregunta padre vuelve con la padre incluida.
class ConversationRouteValidator {
  final ConversationGraphCatalog catalog;
  final double minConfidence;

  const ConversationRouteValidator(this.catalog, {this.minConfidence = 0.6});

  GuidedFlow get _flow => GuidedFlow(catalog.bank);

  RouteValidation validate(
    ConversationRoute proposed, {
    Set<String> presupposed = const {},
  }) {
    // No abrir nada guiado siempre es seguro.
    if (proposed.type == ConversationRouteType.noSafeRoute) {
      return RouteValidation.accepted(proposed);
    }
    if (proposed.confidence < minConfidence) {
      return RouteValidation.rejected(
        'confianza ${proposed.confidence} por debajo de $minConfidence',
      );
    }
    for (final slot in proposed.requestedSlots) {
      if (!catalog.knownSlots.contains(slot)) {
        return RouteValidation.rejected('ranura inexistente: $slot');
      }
    }
    final family = proposed.targetFamilyId;
    if (family != null && !catalog.hasFamily(family)) {
      return RouteValidation.rejected('familia inexistente: $family');
    }
    final context = proposed.targetContextId;
    if (context != null && !catalog.hasContext(context)) {
      return RouteValidation.rejected('contexto inexistente: $context');
    }
    if (family != null &&
        context != null &&
        !catalog.contextsOfFamily(family).contains(context)) {
      return RouteValidation.rejected('$context no es de la familia $family');
    }

    switch (proposed.type) {
      case ConversationRouteType.contextSelector:
      case ConversationRouteType.noSafeRoute:
        if (proposed.targetQuestionIds.isNotEmpty || context != null) {
          return const RouteValidation.rejected(
            'una ruta sin contexto no abre preguntas',
          );
        }
        return RouteValidation.accepted(
          proposed.copyWith(pathQuestionIds: const []),
        );
      case ConversationRouteType.directContext:
        if (family == null && context == null) {
          return const RouteValidation.rejected(
            'DIRECT_CONTEXT sin contexto ni familia',
          );
        }
        if (proposed.targetQuestionIds.isNotEmpty) {
          return const RouteValidation.rejected(
            'DIRECT_CONTEXT no abre preguntas sueltas',
          );
        }
        return RouteValidation.accepted(proposed);
      case ConversationRouteType.directQuestion:
      case ConversationRouteType.minimalGraphPath:
        return _validateQuestions(proposed, presupposed);
    }
  }

  RouteValidation _validateQuestions(
    ConversationRoute proposed,
    Set<String> presupposed,
  ) {
    final context = proposed.targetContextId;
    if (context == null) {
      return const RouteValidation.rejected('pregunta sin contexto');
    }
    final targets = proposed.targetQuestionIds;
    if (targets.isEmpty) {
      return const RouteValidation.rejected('ruta de preguntas vacía');
    }
    if (proposed.type == ConversationRouteType.directQuestion &&
        targets.length != 1) {
      return const RouteValidation.rejected(
        'DIRECT_QUESTION abre una sola pregunta',
      );
    }
    for (final id in targets) {
      if (!catalog.hasQuestion(id)) {
        return RouteValidation.rejected('pregunta inexistente: $id');
      }
      if (!catalog.isStepOf(context, id) && !presupposed.contains(id)) {
        return RouteValidation.rejected('$id no pertenece a $context');
      }
    }

    final asked = {
      for (final id in targets)
        if (presupposed.contains(id)) id,
    };
    final path = _flow.minimalPath(context, targets, presupposed: asked);
    if (!targets.every(path.contains)) {
      return const RouteValidation.rejected('recorrido incompleto');
    }
    final added = [
      for (final id in targets)
        if (!asked.contains(id))
          for (final dep in _flow.dependenciesOf(context, id))
            if (!targets.contains(dep)) dep,
    ];
    return RouteValidation.accepted(
      proposed.copyWith(
        presupposedQuestionIds: asked.toList(),
        pathQuestionIds: path,
        reason: added.isEmpty
            ? proposed.reason
            : '${proposed.reason} (dependencias añadidas: ${added.toSet().join(', ')})'
                  .trim(),
      ),
    );
  }
}
