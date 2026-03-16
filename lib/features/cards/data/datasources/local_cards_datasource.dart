import '../../domain/entities/lsb_card.dart';

class LocalCardsDataSource {
  final List<LsbCard> _cards = [
    LsbCard(
      id: 's1', gloss: 'YO', displayText: 'YO', iconUrl: '',
      videoUrl: 'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
      categoryId: 'Sujetos', subcategoryId: 'Persona', contexts: ['general'], priority: 1, suggestedNextCardIds: [], isFrequent: true, isEmergency: false,
    ),
    LsbCard(
      id: 's2', gloss: 'ÉL/ELLA', displayText: 'ÉL/ELLA', iconUrl: '',
      videoUrl: 'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
      categoryId: 'Sujetos', subcategoryId: 'Persona', contexts: ['general'], priority: 2, suggestedNextCardIds: [], isFrequent: true, isEmergency: false,
    ),
    LsbCard(
      id: 's3', gloss: 'POLICÍA', displayText: 'POLICÍA', iconUrl: '',
      videoUrl: 'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
      categoryId: 'Sujetos', subcategoryId: 'Seguridad', contexts: ['policia'], priority: 3, suggestedNextCardIds: [], isFrequent: true, isEmergency: true,
    ),
    LsbCard(
      id: 's4', gloss: 'ABOGADO', displayText: 'ABOGADO', iconUrl: '',
      videoUrl: 'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
      categoryId: 'Sujetos', subcategoryId: 'Legal', contexts: ['juzgado'], priority: 4, suggestedNextCardIds: [], isFrequent: true, isEmergency: false,
    ),

    LsbCard(
      id: 'v1', gloss: 'VER', displayText: 'VER', iconUrl: '',
      videoUrl: 'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
      categoryId: 'Verbos', subcategoryId: 'Accion', contexts: ['general'], priority: 1, suggestedNextCardIds: [], isFrequent: true, isEmergency: false,
    ),
    LsbCard(
      id: 'v2', gloss: 'NECESITAR', displayText: 'NECESITAR', iconUrl: '',
      videoUrl: 'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
      categoryId: 'Verbos', subcategoryId: 'Accion', contexts: ['general'], priority: 2, suggestedNextCardIds: [], isFrequent: true, isEmergency: false,
    ),
    LsbCard(
      id: 'v3', gloss: 'SUFRIR', displayText: 'SUFRIR', iconUrl: '',
      videoUrl: 'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
      categoryId: 'Verbos', subcategoryId: 'Accion', contexts: ['general'], priority: 3, suggestedNextCardIds: [], isFrequent: true, isEmergency: true,
    ),
    LsbCard(
      id: 'v4', gloss: 'ROBAR', displayText: 'ROBAR', iconUrl: '',
      videoUrl: 'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
      categoryId: 'Verbos', subcategoryId: 'Accion', contexts: ['policia'], priority: 4, suggestedNextCardIds: [], isFrequent: true, isEmergency: true,
    ),

    LsbCard(
      id: 'c1', gloss: 'ROBO', displayText: 'ROBO', iconUrl: '',
      videoUrl: 'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
      categoryId: 'Delitos', subcategoryId: 'Crimen', contexts: ['policia', 'juzgado'], priority: 1, suggestedNextCardIds: [], isFrequent: true, isEmergency: true,
    ),
    LsbCard(
      id: 'c2', gloss: 'GOLPE', displayText: 'GOLPE', iconUrl: '',
      videoUrl: 'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
      categoryId: 'Delitos', subcategoryId: 'Crimen', contexts: ['policia', 'juzgado'], priority: 2, suggestedNextCardIds: [], isFrequent: true, isEmergency: true,
    ),
    LsbCard(
      id: 'c3', gloss: 'DENUNCIA', displayText: 'DENUNCIA', iconUrl: '',
      videoUrl: 'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
      categoryId: 'Delitos', subcategoryId: 'Legal', contexts: ['policia', 'juzgado'], priority: 3, suggestedNextCardIds: [], isFrequent: true, isEmergency: false,
    ),

    LsbCard(
      id: 't1', gloss: 'AYER', displayText: 'AYER', iconUrl: '',
      videoUrl: 'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
      categoryId: 'Tiempo', subcategoryId: 'Pasado', contexts: ['general'], priority: 1, suggestedNextCardIds: [], isFrequent: true, isEmergency: false,
    ),
    LsbCard(
      id: 't2', gloss: 'HOY', displayText: 'HOY', iconUrl: '',
      videoUrl: 'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
      categoryId: 'Tiempo', subcategoryId: 'Presente', contexts: ['general'], priority: 2, suggestedNextCardIds: [], isFrequent: true, isEmergency: false,
    ),
  ];

  Future<List<LsbCard>> getCardsByCategory(String category) async {
    return _cards.where((c) => c.categoryId == category).toList();
  }

  Future<List<String>> getCategories() async {
    return _cards.map((c) => c.categoryId).toSet().toList();
  }
}
