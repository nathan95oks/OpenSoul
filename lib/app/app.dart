import 'package:flutter/material.dart';
import 'router.dart';
import 'theme.dart';

class AppScope extends StatelessWidget {
  const AppScope({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'LSB Legal App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: appRouter,
    );
  }
}
