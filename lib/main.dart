import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:bio_track/startScreen.dart';
import 'package:bio_track/stillStart.dart';
import 'package:bio_track/LandingPage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:bio_track/logInPage.dart';
import 'package:bio_track/register.dart';
import 'package:bio_track/theme_provider.dart';
import 'package:bio_track/theme_config.dart';

bool ignoreAuthChanges = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'BioTrack',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(context),
          darkTheme: AppTheme.dark(context),
          themeMode:
              themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          home: StartScreen(), // Set StartScreen as the initial screen
        );
      },
    );
  }
}

class AuthenticationWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Disable auto-navigation based on auth state
    return HomePage();
  }
}
