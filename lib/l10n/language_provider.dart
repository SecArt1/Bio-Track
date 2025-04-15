import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider extends ChangeNotifier {
  Locale _currentLocale = const Locale('en');
  static const String LANGUAGE_CODE = 'languageCode';

  Locale get currentLocale => _currentLocale;

  LanguageProvider() {
    _loadSavedLanguage();
  }

  Future<void> _loadSavedLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLanguageCode = prefs.getString(LANGUAGE_CODE);

    if (savedLanguageCode != null) {
      _currentLocale = Locale(savedLanguageCode);
      notifyListeners();
    }
  }

  Future<void> changeLanguage(Locale locale) async {
    if (_currentLocale == locale) return;

    _currentLocale = locale;

    // Save to shared preferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(LANGUAGE_CODE, locale.languageCode);

    notifyListeners();
  }

  bool get isArabic => _currentLocale.languageCode == 'ar';
}
