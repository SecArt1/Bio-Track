import 'package:flutter/material.dart';
import 'package:bio_track/pages/faq.dart';
import 'package:bio_track/forgotPassword.dart';
import 'package:bio_track/logInPage.dart';
import 'package:provider/provider.dart';
import 'package:bio_track/theme_provider.dart';

class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool isNotificationsEnabled = true;
  String selectedLanguage = "English";

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text("Settings",
            style: TextStyle(color: theme.appBarTheme.foregroundColor)),
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
                    "Account",
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
                  "Change Password",
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
                      "Language",
                      style: TextStyle(color: theme.colorScheme.onBackground),
                    ),
                    DropdownButton<String>(
                      value: selectedLanguage,
                      dropdownColor: theme.cardColor,
                      onChanged: (String? newValue) {
                        setState(() {
                          selectedLanguage = newValue!;
                        });
                      },
                      items: [
                        "English",
                        "Arabic",
                      ].map<DropdownMenuItem<String>>((String language) {
                        return DropdownMenuItem<String>(
                          value: language,
                          child: Text(
                            language,
                            style: TextStyle(
                                color: theme.colorScheme.onBackground),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              ListTile(
                title: Text(
                  "Terms and Conditions",
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
                  "Notifications",
                  style: TextStyle(color: theme.colorScheme.onBackground),
                ),
                value: isNotificationsEnabled,
                activeColor: theme.colorScheme.primary,
                onChanged: (bool value) {
                  setState(() {
                    isNotificationsEnabled = value;
                  });
                },
              ),
              SwitchListTile(
                title: Text(
                  "Dark Mode",
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
                    "Help",
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
                  "Frequently Asked Questions",
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
                  "Contact Us",
                  style: TextStyle(color: theme.colorScheme.onBackground),
                ),
                trailing: Icon(Icons.arrow_forward_ios,
                    size: 18, color: theme.iconTheme.color),
                onTap: () {},
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
                  onPressed: () {
                    Navigator.pushReplacement(context,
                        MaterialPageRoute(builder: (context) => HomePage()));
                  },
                  child: Text("Log Out", style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
