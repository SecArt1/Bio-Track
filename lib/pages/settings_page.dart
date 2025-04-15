import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:bio_track/l10n/app_localizations.dart';
import 'package:bio_track/l10n/language_provider.dart';
import 'package:bio_track/theme_provider.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final languageProvider = Provider.of<LanguageProvider>(context);
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          localizations.translate('settings'),
          style: const TextStyle(
            color: Color(0xff0383c2),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Theme settings
            _buildSectionTitle(context, localizations.translate('theme')),
            const SizedBox(height: 8),
            _buildSettingCard(
              context,
              title: localizations.translate('dark_mode'),
              trailing: Switch(
                value: themeProvider.isDarkMode,
                onChanged: (value) {
                  themeProvider.toggleTheme();
                },
                activeColor: const Color(0xff0383c2),
              ),
              icon: Icons.dark_mode,
            ),

            const SizedBox(height: 24),

            // Language settings
            _buildSectionTitle(context, localizations.translate('language')),
            const SizedBox(height: 8),
            _buildLanguageCard(context, localizations, languageProvider),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).primaryColor,
        ),
      ),
    );
  }

  Widget _buildSettingCard(
    BuildContext context, {
    required String title,
    required Widget trailing,
    required IconData icon,
  }) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: const Color(0xff0383c2),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: trailing,
      ),
    );
  }

  Widget _buildLanguageCard(
    BuildContext context,
    AppLocalizations localizations,
    LanguageProvider languageProvider,
  ) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(
              Icons.language,
              color: Color(0xff0383c2),
            ),
            title: Text(
              localizations.translate('select_language'),
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Divider(),
          RadioListTile<Locale>(
            title: Text(localizations.translate('english')),
            value: const Locale('en'),
            groupValue: languageProvider.currentLocale,
            onChanged: (Locale? locale) {
              if (locale != null) {
                languageProvider.changeLanguage(locale);
              }
            },
            activeColor: const Color(0xff0383c2),
          ),
          RadioListTile<Locale>(
            title: Text(localizations.translate('arabic')),
            value: const Locale('ar'),
            groupValue: languageProvider.currentLocale,
            onChanged: (Locale? locale) {
              if (locale != null) {
                languageProvider.changeLanguage(locale);
              }
            },
            activeColor: const Color(0xff0383c2),
          ),
        ],
      ),
    );
  }
}
