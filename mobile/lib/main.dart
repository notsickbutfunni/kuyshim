/// main.dart — Entry point with Firebase, ThemeData, and GoRouter setup.
library;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';



import 'services/app_state.dart';
import 'services/language_service.dart';
import 'services/connectivity_service.dart';
import 'screens/onboarding_screen.dart';
import 'screens/onboarding_selection_screen.dart';
import 'screens/library_screen.dart';
import 'screens/game_screen.dart';
import 'screens/tuner_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/results_screen.dart';
import 'screens/story_screen.dart';
import 'screens/learn_screen.dart';
import 'screens/video_lesson_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const KuyshimApp());
}

// ── Color Palette ───────────────────────────────────────────
class KColors {
  static const Color background = Color(0xFF0F1115);
  static const Color surface = Color(0xFF1A1C23);
  static const Color emerald = Color(0xFF10B981);
  static const Color emeraldDark = Color(0xFF059669);
  static const Color amber = Color(0xFFD4A843);
  static const Color amberLight = Color(0xFFF0C850);
  static const Color violet = Color(0xFF8B5CF6);
  static const Color violetDark = Color(0xFF7C3AED);
  static const Color red = Color(0xFFEF4444);
  static const Color blue = Color(0xFF3B82F6);
  static const Color yellow = Color(0xFFEAB308);
}

class KuyshimApp extends StatelessWidget {
  const KuyshimApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) {
          final connectivity = ConnectivityService();
          connectivity.init();
          return connectivity;
        }),
        ChangeNotifierProvider(create: (_) {
          final lang = LanguageService();
          lang.loadSavedLanguage();
          return lang;
        }),
        ChangeNotifierProxyProvider<ConnectivityService, AppState>(
          create: (_) {
            final state = AppState();
            state.init();
            return state;
          },
          update: (_, connectivity, appState) {
            appState!.setConnectivity(connectivity);
            return appState;
          },
        ),
      ],
      child: MaterialApp.router(
        title: 'Kuyshim',
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(),
        routerConfig: _buildRouter(),
      ),
    );
  }

  static ThemeData _buildTheme() {
    final base = ThemeData.dark();
    return base.copyWith(
      scaffoldBackgroundColor: KColors.background,
      colorScheme: const ColorScheme.dark(
        primary: KColors.emerald,
        secondary: KColors.amber,
        surface: KColors.surface,
        error: KColors.red,
      ),
      textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: BorderSide(color: Colors.white.withOpacity(0.1)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: KColors.emerald.withOpacity(0.5)),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 16,
        ),
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
      ),
      cardTheme: CardThemeData(
        color: KColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(32),
        ),
        elevation: 0,
      ),
    );
  }

  static GoRouter _buildRouter() {
    return GoRouter(
      initialLocation: '/welcome',
      routes: [
        GoRoute(
          path: '/welcome',
          builder: (context, state) => const OnboardingSelectionScreen(),
        ),
        GoRoute(
          path: '/onboarding',
          builder: (context, state) => const OnboardingScreen(),
        ),
        GoRoute(
          path: '/library',
          builder: (context, state) => const LibraryScreen(),
        ),
        GoRoute(
          path: '/game',
          builder: (context, state) => const GameScreen(),
        ),
        GoRoute(
          path: '/learn',
          builder: (context, state) => const LearnScreen(),
        ),
        GoRoute(
          path: '/game-tutorial',
          builder: (context, state) => const GameScreen(isTutorialMode: true),
        ),
        GoRoute(
          path: '/tuner',
          builder: (context, state) => const TunerScreen(),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const ProfileScreen(),
        ),
        GoRoute(
          path: '/results',
          builder: (context, state) => const ResultsScreen(),
        ),
        GoRoute(
          path: '/story',
          builder: (context, state) {
            final lessonId = state.uri.queryParameters['id'];
            return StoryScreen(initialLessonId: lessonId);
          },
        ),
        GoRoute(
          path: '/video-lesson',
          builder: (context, state) => const VideoLessonScreen(),
        ),
      ],
    );
  }
}
