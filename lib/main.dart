
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/cards/presentation/screens/home_screen.dart';

void main() {
  runApp(const ProviderScope(child: LsbLegalApp()));
}

class LsbLegalApp extends StatelessWidget {
  const LsbLegalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LSB Inclusivo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212), // Fondo casi negro
        primaryColor: const Color(0xFFFFD700), // Amarillo fuerte para destacar
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFFD700),
          secondary: Color(0xFF00ADB5), // Azul cyan para botones secundarios
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1F1F1F),
          elevation: 2,
          centerTitle: true,
        ),
        fontFamily: 'Roboto', // Fuente clara y legible
      ),
      home: const HomeScreen(),
    );
  }
}
