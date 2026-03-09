import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../features/theme_workbench/presentation/theme_workbench_page.dart';

class LineThemeApp extends StatelessWidget {
  const LineThemeApp({super.key});

  @override
  Widget build(BuildContext context) {
    final baseTextTheme = GoogleFonts.notoSansTcTextTheme().apply(bodyColor: const Color(0xFF201E1C), displayColor: const Color(0xFF201E1C));
    final displayStyle = GoogleFonts.spaceGrotesk(color: const Color(0xFF201E1C), fontWeight: FontWeight.w700);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'LINE Theme',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: const ColorScheme.light(primary: Color(0xFF22252B), secondary: Color(0xFFC88D5B), tertiary: Color(0xFF6F7C8D), surface: Color(0xFFFFFCF7), surfaceContainerHighest: Color(0xFFE9E1D5), onSurface: Color(0xFF201E1C), error: Color(0xFFB4503C)),
        scaffoldBackgroundColor: const Color(0xFFF5F0E8),
        textTheme: baseTextTheme.copyWith(
          headlineLarge: displayStyle.copyWith(fontSize: 36, height: 1.02),
          headlineMedium: displayStyle.copyWith(fontSize: 30, height: 1.08),
          headlineSmall: displayStyle.copyWith(fontSize: 24),
          titleLarge: displayStyle.copyWith(fontSize: 22),
          titleMedium: displayStyle.copyWith(fontSize: 18),
          titleSmall: GoogleFonts.spaceGrotesk(color: const Color(0xFF201E1C), fontWeight: FontWeight.w700, fontSize: 15),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.92),
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          hintStyle: baseTextTheme.bodyLarge?.copyWith(color: const Color(0xFF7B756D)),
          labelStyle: baseTextTheme.bodyLarge?.copyWith(color: const Color(0xFF5E5954)),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: const BorderSide(color: Color(0xFFC88D5B), width: 1.5),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF22252B),
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 56),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            textStyle: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF22252B),
            minimumSize: const Size(0, 56),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            side: const BorderSide(color: Color(0x3322252B)),
            textStyle: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
        ),
      ),
      home: const ThemeWorkbenchPage(),
    );
  }
}
