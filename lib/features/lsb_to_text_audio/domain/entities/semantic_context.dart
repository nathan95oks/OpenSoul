class SemanticContext {
  final String id;
  final String name;
  final String icon;
  final String description;
  final List<GuidedStep> defaultSteps;

  const SemanticContext({
    required this.id,
    required this.name,
    required this.icon,
    required this.description,
    required this.defaultSteps,
  });
}

class GuidedStep {
  final String id;
  final String title;
  final String description;
  final List<String> targetCategories;
  final bool isOptional;

  const GuidedStep({
    required this.id,
    required this.title,
    required this.description,
    required this.targetCategories,
    this.isOptional = false,
  });
}
