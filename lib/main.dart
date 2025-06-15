import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:bio_track/LandingPage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:bio_track/logInPage.dart';
import 'package:bio_track/register.dart';
import 'package:bio_track/theme_provider.dart';
import 'package:bio_track/theme_config.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:bio_track/l10n/app_localizations.dart';
import 'package:bio_track/l10n/language_provider.dart';
import 'package:bio_track/Auth/auth_wrapper.dart';
import 'firebase_options.dart';

bool ignoreAuthChanges = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with proper error handling
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('🔥 Firebase initialized successfully');
  } catch (e) {
    // If Firebase is already initialized, this will throw an exception
    // but we can safely ignore it and continue
    if (e.toString().contains('duplicate-app')) {
      print('🔥 Firebase already initialized, using existing instance');
    } else {
      print('🔥 Firebase initialization error: $e');
      rethrow;
    }
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Access providers for theme and language
    final themeProvider = Provider.of<ThemeProvider>(context);
    final languageProvider = Provider.of<LanguageProvider>(context);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'BioTrack', // Your app title
      theme: ThemeConfig.lightTheme, // Your light theme config
      darkTheme: ThemeConfig.darkTheme, // Your dark theme config
      themeMode: themeProvider.themeMode, // Controlled by ThemeProvider

      // Localization settings
      locale: languageProvider.currentLocale,
      supportedLocales: const [
        Locale('en', ''), // English, no country code
        Locale('ar', ''), // Arabic, no country code
      ],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      localeResolutionCallback: (locale, supportedLocales) {
        for (var supportedLocale in supportedLocales) {
          if (supportedLocale.languageCode == locale?.languageCode) {
            return supportedLocale;
          }
        }
        // Default to English if locale is not supported
        return supportedLocales.first;
      },

      // Use AuthWrapper as the home widget
      home: const AuthWrapper(),

      // Define routes if you use named navigation
      // routes: {
      //   '/login': (context) => const HomePage(),
      //   '/register': (context) => const Register(),
      //   '/landing': (context) => const LandingPage(),
      //   // Add other routes...
      // },
    );
  }
}
