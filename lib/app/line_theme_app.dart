import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../features/theme_workbench/presentation/theme_workbench_page.dart';

class LineThemeTesterApp extends StatelessWidget {
  const LineThemeTesterApp({super.key});

  @override
  Widget build(BuildContext context) {
    final baseTextTheme = GoogleFonts.notoSansTcTextTheme();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'LINE Theme Tester',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E6B5B),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF6F1E8),
        textTheme: baseTextTheme,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: Color(0xFF2E6B5B), width: 1.5),
          ),
        ),
      ),
      home: const ThemeWorkbenchPage(),
    );
  }
}
