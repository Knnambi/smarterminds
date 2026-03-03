import 'package:flutter/material.dart';

import 'constants.dart';
import 'screens/syllabus_loader_screen.dart';

void main() {
  // Fail fast with a clear message if no API key was provided at build time
  assert(
    GEMINI_API_KEY.isNotEmpty,
    '\n\n⚠️  GEMINI_API_KEY is not set!\n'
    'Run with: flutter run --dart-define=GEMINI_API_KEY=YOUR_KEY_HERE\n',
  );
  runApp(const TamilAITutorApp());
}

class TamilAITutorApp extends StatelessWidget {
  const TamilAITutorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tamil AI Tutor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const SyllabusLoaderScreen(),
    );
  }
}
