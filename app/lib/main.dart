import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'translator_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // The camera overlay assumes a portrait 3:4 image.
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const SignLanguageApp());
}

class SignLanguageApp extends StatelessWidget {
  const SignLanguageApp({super.key});

  @override
  Widget build(BuildContext context) {
    final seed = Colors.teal;
    return MaterialApp(
      title: 'ASL Translator',
      theme: ThemeData(colorSchemeSeed: seed),
      darkTheme: ThemeData(colorSchemeSeed: seed, brightness: Brightness.dark),
      home: const TranslatorScreen(),
    );
  }
}
