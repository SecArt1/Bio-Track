import 'package:flutter/material.dart';
import 'package:bio_track/pages/faq.dart';
import 'package:bio_track/pages/about.dart'; // Import about.dart
import 'package:bio_track/forgotPassword.dart';
import 'package:bio_track/logInPage.dart';
import 'package:provider/provider.dart';
import 'package:bio_track/theme_provider.dart';
import 'package:bio_track/l10n/app_localizations.dart';
import 'package:bio_track/l10n/language_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool isNotificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadNotificationPreference();
  }

  // Load saved notification preference
  Future<void> _loadNotificationPreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      isNotificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
    });
  }

  // Save notification preference
  Future<void> _saveNotificationPreference(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', value);

    // Here you would also implement any platform-specific notification handling
    if (value) {
      _enableNotifications();
    } else {
      _disableNotifications();
    }
  }

  // Enable notifications
  void _enableNotifications() {
    // Implementation for enabling push notifications would go here
    // This might involve Firebase Messaging or another notification service
    print('Notifications enabled');
  }

  // Disable notifications
  void _disableNotifications() {
    // Implementation for disabling push notifications would go here
    print('Notifications disabled');
  }

  // Handle logout
  Future<void> _handleLogout() async {
    try {
      await FirebaseAuth.instance.signOut();
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (context) => HomePage()));
    } catch (e) {
      print('Error during logout: $e');
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logout failed. Please try again.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final languageProvider = Provider.of<LanguageProvider>(context);
    final localizations = AppLocalizations.of(context);
    final isDarkMode = themeProvider.isDarkMode;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          localizations.translate("settings"),
          style: TextStyle(color: theme.appBarTheme.foregroundColor),
        ),
        backgroundColor: theme.appBarTheme.backgroundColor,
        iconTheme: IconThemeData(color: theme.appBarTheme.foregroundColor),
        elevation: 2,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 40),
              Row(
                children: [
                  Icon(Icons.person, color: theme.iconTheme.color),
                  SizedBox(width: 8),
                  Text(
                    localizations.translate("account"),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onBackground,
                    ),
                  ),
                ],
              ),
              Divider(height: 15, thickness: 2, color: theme.dividerColor),
              ListTile(
                title: Text(
                  localizations.translate("change_password"),
                  style: TextStyle(color: theme.colorScheme.onBackground),
                ),
                trailing: Icon(Icons.arrow_forward_ios,
                    size: 18, color: theme.iconTheme.color),
                onTap: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => ForgotPassword()));
                },
              ),
              ListTile(
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      localizations.translate("language"),
                      style: TextStyle(color: theme.colorScheme.onBackground),
                    ),
                    DropdownButton<Locale>(
                      value: languageProvider.currentLocale,
                      dropdownColor: theme.cardColor,
                      onChanged: (Locale? newLocale) {
                        if (newLocale != null) {
                          languageProvider.changeLanguage(newLocale);
                        }
                      },
                      items: const [
                        DropdownMenuItem<Locale>(
                          value: Locale('en'),
                          child: Text('English'),
                        ),
                        DropdownMenuItem<Locale>(
                          value: Locale('ar'),
                          child: Text('العربية'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              ListTile(
                title: Text(
                  localizations.translate("terms_and_conditions"),
                  style: TextStyle(color: theme.colorScheme.onBackground),
                ),
                trailing: Icon(Icons.arrow_forward_ios,
                    size: 18, color: theme.iconTheme.color),
                onTap: () {
                  //Navigator.push(context, MaterialPageRoute(builder: (context) => TermsScreen()));
                },
              ),
              SwitchListTile(
                title: Text(
                  localizations.translate("notifications"),
                  style: TextStyle(color: theme.colorScheme.onBackground),
                ),
                value: isNotificationsEnabled,
                activeColor: theme.colorScheme.primary,
                onChanged: (bool value) {
                  setState(() {
                    isNotificationsEnabled = value;
                  });
                  _saveNotificationPreference(value);
                },
              ),
              SwitchListTile(
                title: Text(
                  localizations.translate("dark_mode"),
                  style: TextStyle(color: theme.colorScheme.onBackground),
                ),
                value: isDarkMode,
                activeColor: theme.colorScheme.primary,
                onChanged: (bool value) {
                  themeProvider.toggleTheme();
                },
              ),
              SizedBox(height: 20),
              Row(
                children: [
                  Icon(Icons.volume_up_outlined, color: theme.iconTheme.color),
                  SizedBox(width: 8),
                  Text(
                    localizations.translate("help"),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onBackground,
                    ),
                  ),
                ],
              ),
              Divider(height: 15, thickness: 2, color: theme.dividerColor),
              SizedBox(height: 10),
              ListTile(
                title: Text(
                  localizations.translate("faq"),
                  style: TextStyle(color: theme.colorScheme.onBackground),
                ),
                trailing: Icon(Icons.arrow_forward_ios,
                    size: 18, color: theme.iconTheme.color),
                onTap: () {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (context) => FAQScreen()));
                },
              ),
              ListTile(
                title: Text(
                  localizations.translate("contact_us"),
                  style: TextStyle(color: theme.colorScheme.onBackground),
                ),
                trailing: Icon(Icons.arrow_forward_ios,
                    size: 18, color: theme.iconTheme.color),
                onTap: () {
                  // Navigate to About page
                  Navigator.push(context,
                      MaterialPageRoute(builder: (context) => AboutPage()));
                },
              ),
              SizedBox(height: 40),
              Center(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    padding: EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  onPressed: _handleLogout,
                  child: Text(localizations.translate("logout"),
                      style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
