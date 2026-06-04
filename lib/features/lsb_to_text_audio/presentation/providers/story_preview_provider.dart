import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/services/local_sentence_assembler.dart';
import 'context_provider.dart';
import 'sentence_provider.dart';

/// Construye en tiempo real la oración base a medida que el usuario
/// selecciona glosas. Usa LocalSentenceAssembler (capa de dominio) sin
/// pasar por el backend — retroalimentación instantánea sin latencia.
///
/// El usuario sordo ve simultáneamente:
///   • La construcción LSB: ROBAR • CELULAR • AYER • PLAZA
///   • La interpretación en español: "Me robaron mi celular ayer en la plaza."
final storyPreviewProvider = Provider<String>((ref) {
  final glosses = ref.watch(sentenceProvider);
  final context = ref.watch(contextProvider);
  if (glosses.isEmpty || context == null) return '';
  const assembler = LocalSentenceAssembler();
  return assembler.assemble(contextId: context.id, glosses: glosses);
});
