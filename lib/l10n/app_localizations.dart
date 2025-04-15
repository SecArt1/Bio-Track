import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  // Helper method to keep the code in the widgets concise
  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  // Static member to have a simple access to the delegate from the MaterialApp
  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  Map<String, String> _localizedStrings = {};

  Future<bool> load() async {
    try {
      // Load the language JSON file from the "l10n" folder
      String jsonString =
          await rootBundle.loadString('lib/l10n/${locale.languageCode}.json');
      Map<String, dynamic> jsonMap = json.decode(jsonString);

      _localizedStrings = jsonMap.map((key, value) {
        return MapEntry(key, value.toString());
      });

      return true;
    } catch (e) {
      // Try alternate path
      try {
        // Second attempt with a different path pattern
        String jsonString = await rootBundle
            .loadString('assets/l10n/${locale.languageCode}.json');
        Map<String, dynamic> jsonMap = json.decode(jsonString);

        _localizedStrings = jsonMap.map((key, value) {
          return MapEntry(key, value.toString());
        });

        return true;
      } catch (e2) {
        print('Failed to load ${locale.languageCode}.json: $e2');

        // Fallback to English default strings if specified language can't be loaded
        if (locale.languageCode != 'en') {
          try {
            String defaultJsonString =
                await rootBundle.loadString('lib/l10n/en.json');
            Map<String, dynamic> defaultJsonMap =
                json.decode(defaultJsonString);

            _localizedStrings = defaultJsonMap.map((key, value) {
              return MapEntry(key, value.toString());
            });

            return true;
          } catch (e3) {
            print('Failed to load fallback en.json: $e3');
          }
        }

        // If all else fails, use an empty map (this will use the keys as fallback)
        _localizedStrings = {};
        return false;
      }
    }
  }

  // This method will be called from every widget which needs a localized text
  String translate(String key) {
    return _localizedStrings[key] ?? key;
  }
}

// LocalizationsDelegate is a factory for a set of localized resources
class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  // This delegate instance will never change (it doesn't even have fields!)
  // It can provide a constant constructor.
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    // Include all supported language codes here
    return ['en', 'ar'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    // AppLocalizations class is where the JSON loading actually runs
    AppLocalizations localizations = AppLocalizations(locale);
    await localizations.load();
    return localizations;
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
