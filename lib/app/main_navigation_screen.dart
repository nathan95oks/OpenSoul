import 'package:flutter/material.dart';
import '../features/conversation/presentation/screens/conversation_screen.dart';
import '../features/lsb_to_text_audio/presentation/screens/home_screen.dart';
import '../features/audio_to_lsb/presentation/screens/audio_to_lsb_screen.dart';

/// Navegación raíz. La Conversación es el centro de la aplicación; los
/// flujos de tarjetas y de voz siguen accesibles como herramientas
/// directas mientras se completa la transición al modelo conversacional
/// (Fase 1 de la arquitectura unificada).
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const ConversationScreen(),
    const HomeScreen(),
    const AudioToLsbScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.forum),
            label: 'Conversación',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.sign_language),
            label: 'Tarjetas LSB',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.mic),
            label: 'Voz a LSB',
          ),
        ],
      ),
    );
  }
}
