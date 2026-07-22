import 'package:lsb_legal_app/core/dictionary/domain/lexicon_repository.dart';
import 'package:lsb_legal_app/core/domain/entities/lsb_card.dart';
import 'package:lsb_legal_app/features/lsb_to_text_audio/domain/repositories/cards_repository.dart';

/// Fachada del flujo de tarjetas sobre el diccionario evolutivo.
///
/// El catálogo ya no vive hardcodeado aquí: proviene del [LexiconRepository]
/// del núcleo (asset empaquetado + caché + sincronización remota), la misma
/// fuente que alimenta al avatar. Este repositorio solo conserva la vista
/// por categorías que necesita el flujo guiado.
class CardsRepositoryImpl implements CardsRepository {
  final LexiconRepository lexicon;

  CardsRepositoryImpl(this.lexicon);

  @override
  Future<List<LsbCard>> getCardsByCategory(String category) async {
    final entries = await lexicon.getEntries();
    return entries.where((c) => c.categoryId == category).toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));
  }

  @override
  Future<List<String>> getCategories() => lexicon.getCategories();
}
