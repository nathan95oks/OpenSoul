// lib/data/mock_cards.dart

import 'package:flutter/material.dart';

// Definimos la estructura de nuestra tarjeta
class LsbCard {
  final String id;
  final String word;
  final IconData icon; // En el futuro será una URL de imagen de S3
  final String category;
  final String videoUrl;

  LsbCard({
    required this.id,
    required this.word,
    required this.icon,
    required this.category,
    required this.videoUrl,
  });
}

// Simulamos lo que nos devolvería DynamoDB
final List<LsbCard> baseDeDatosTarjetas =[
  // CATEGORÍA: SUJETOS
  LsbCard(id: 's1', word: 'YO', icon: Icons.person, category: 'Sujetos', videoUrl: 'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4'),
  LsbCard(id: 's2', word: 'ÉL/ELLA', icon: Icons.person_outline, category: 'Sujetos', videoUrl: 'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4'),
  LsbCard(id: 's3', word: 'POLICÍA', icon: Icons.local_police, category: 'Sujetos', videoUrl: 'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4'),
  LsbCard(id: 's4', word: 'ABOGADO', icon: Icons.gavel, category: 'Sujetos', videoUrl: 'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4'),

  // CATEGORÍA: VERBOS
  LsbCard(id: 'v1', word: 'VER', icon: Icons.visibility, category: 'Verbos', videoUrl: 'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4'),
  LsbCard(id: 'v2', word: 'NECESITAR', icon: Icons.pan_tool, category: 'Verbos', videoUrl: 'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4'),
  LsbCard(id: 'v3', word: 'SUFRIR', icon: Icons.mood_bad, category: 'Verbos', videoUrl: 'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4'),
  LsbCard(id: 'v4', word: 'ROBAR', icon: Icons.back_hand, category: 'Verbos', videoUrl: 'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4'),

  // CATEGORÍA: DELITOS / CONTEXTO LEGAL
  LsbCard(id: 'c1', word: 'ROBO', icon: Icons.warning, category: 'Delitos', videoUrl: 'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4'),
  LsbCard(id: 'c2', word: 'GOLPE', icon: Icons.sick, category: 'Delitos', videoUrl: 'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4'),
  LsbCard(id: 'c3', word: 'DENUNCIA', icon: Icons.description, category: 'Delitos', videoUrl: 'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4'),

  // CATEGORÍA: TIEMPO
  LsbCard(id: 't1', word: 'AYER', icon: Icons.history, category: 'Tiempo', videoUrl: 'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4'),
  LsbCard(id: 't2', word: 'HOY', icon: Icons.calendar_today, category: 'Tiempo', videoUrl: 'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4'),
];