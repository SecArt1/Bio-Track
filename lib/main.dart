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
// Import localization packages
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:bio_track/l10n/app_localizations.dart';
import 'package:bio_track/l10n/language_provider.dart';

bool ignoreAuthChanges = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
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
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer2<ThemeProvider, LanguageProvider>(
      builder: (context, themeProvider, languageProvider, child) {
        return MaterialApp(
          title: 'BioTrack',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(context),
          darkTheme: AppTheme.dark(context),
          themeMode:
              themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,

          // Localization setup
          locale: languageProvider.currentLocale,
          supportedLocales: const [
            Locale('en', ''), // English
            Locale('ar', ''), // Arabic
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
            // If device language is not supported, use first one from the list (English)
            return supportedLocales.first;
          },

          // Set text direction based on language
          builder: (context, child) {
            return Directionality(
              textDirection: languageProvider.isArabic
                  ? TextDirection.rtl
                  : TextDirection.ltr,
              child: child!,
            );
          },
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
