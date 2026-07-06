import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/ngrok_setup_screen.dart';

void main() {
  runApp(const RealEstateApp());
}

class RealEstateApp extends StatelessWidget {
  const RealEstateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ESTAT·IQ',
      theme: AppTheme.theme,
      // Start on setup screen so ngrok URL is always configured at runtime
      home: const NgrokSetupScreen(isFirstRun: true),
    );
  }
}
