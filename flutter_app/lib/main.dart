import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/app_provider.dart';
import 'theme/app_theme.dart';
import 'screens/onboarding_screen.dart';
import 'screens/library_screen.dart';
import 'screens/game_screen.dart';
import 'screens/tuner_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/results_screen.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppProvider()..init(),
      child: const KuyshimApp(),
    ),
  );
}

class KuyshimApp extends StatelessWidget {
  const KuyshimApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kuyshim — Master the Dombra',
      theme: appTheme(),
      debugShowCheckedModeBanner: false,
      home: const AppShell(),
    );
  }
}

class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    final screen = context.watch<AppProvider>().currentScreen;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: _buildScreen(screen),
    );
  }

  Widget _buildScreen(AppScreen screen) {
    switch (screen) {
      case AppScreen.onboarding:
        return const OnboardingScreen(key: ValueKey('onboarding'));
      case AppScreen.library:
        return const LibraryScreen(key: ValueKey('library'));
      case AppScreen.game:
        return const GameScreen(key: ValueKey('game'));
      case AppScreen.tuner:
        return const TunerScreen(key: ValueKey('tuner'));
      case AppScreen.profile:
        return const ProfileScreen(key: ValueKey('profile'));
      case AppScreen.results:
        return const ResultsScreen(key: ValueKey('results'));
    }
  }
}
