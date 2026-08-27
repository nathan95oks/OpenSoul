class GeneratedStep {
  final String question;
  final List<String> options;

  const GeneratedStep({required this.question, required this.options});

  static const vacio = GeneratedStep(question: '', options: []);

  bool get isEmpty => options.isEmpty;
}
