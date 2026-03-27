import 'package:flutter/material.dart';
import '../features/lsb_to_text_audio/presentation/screens/home_screen.dart';
import '../features/audio_to_lsb/presentation/screens/audio_to_lsb_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({Key? key}) : super(key: key);

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
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
            icon: Icon(Icons.sign_language),
            label: 'LSB -> Audio',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.mic),
            label: 'Audio -> LSB',
          ),
        ],
      ),
    );
  }
}
