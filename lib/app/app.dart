import 'package:flutter/material.dart';
import 'package:lsb_legal_app/app/app_router.dart';
import 'package:lsb_legal_app/app/app_theme.dart';

class AppScope extends StatelessWidget {
  const AppScope({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'OpenSoul - Asistente Ciudadano LSB',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: appRouter,
    );
  }
}
