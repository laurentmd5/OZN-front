// lib/src/app.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ozn/src/core/navigation/app_router.dart';

class OZNApp extends ConsumerWidget {
  const OZNApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'OZN - Solidarité Locale',
      theme: _buildTheme(),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }

  ThemeData _buildTheme() {
    return ThemeData(
      primaryColor: const Color(0xFF27AE60),
      colorScheme: const ColorScheme.light(primary: Color(0xFF27AE60), secondary: Color(0xFF2D9CDB)),
      useMaterial3: true,
    );
  }
}
