import 'package:flutter/material.dart';
import 'package:bio_track/StartTest.dart';
import 'package:bio_track/edit_profile.dart';
import 'package:bio_track/services/user_service.dart';
import 'package:bio_track/models/user_model.dart';
// New imports
import 'package:bio_track/pages/FAQ.dart';
import 'package:bio_track/pages/about.dart';
import 'package:bio_track/pages/guide.dart';
import 'package:bio_track/pages/notifications.dart';
import 'package:bio_track/pages/settings.dart';
// Localization imports
import 'package:bio_track/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:bio_track/l10n/language_provider.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  _LandingPageState createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  UserModel? _currentUser;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final userService = UserService();
      final user = await userService.getCurrentUser();

      if (mounted) {
        setState(() {
          _currentUser = user;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error loading user data: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Calculate age from date of birth
  int calculateAge(DateTime birthDate) {
    final today = DateTime.now();
    int age = today.year - birthDate.year;

    // Adjust age if birthday hasn't occurred yet this year
    if (today.month < birthDate.month ||
        (today.month == birthDate.month && today.day < birthDate.day)) {
      age--;
    }

    return age;
  }

  // Helper method for icon buttons
  Widget _buildIconWithLabel(BuildContext context, String assetPath,
      String translationKey, VoidCallback onTap) {
    final localizations = AppLocalizations.of(context);

    return Flexible(
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
            child: Image.asset(assetPath, height: 75, width: 75),
          ),
          const SizedBox(height: 3),
          Text(
            localizations.translate(translationKey),
            style: const TextStyle(
                color: Color(0xff0383c2),
                fontSize: 16,
                fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0XFF0383c2),
/////////////////////////// Part 1 /////////////////////////////////
      body: Column(
        children: [
          Expanded(
            flex: 0,
            child: Container(
              width: double.infinity,
              color: const Color(0xFF0383C2),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const CircleAvatar(
                          radius: 30,
                          backgroundColor: Colors.white,
                          child: Icon(Icons.person, color: Color(0xFF0078D4)),
                        ),
                        const SizedBox(width: 15),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  _isLoading
                                      ? localizations.translate("loading")
                                      : (_currentUser?.fullName ??
                                          localizations.translate("user")),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                // Add a refresh button
                                if (_currentUser?.fullName == null)
                                  IconButton(
                                    icon: const Icon(Icons.refresh,
                                        color: Colors.white, size: 16),
                                    onPressed: () {
                                      setState(() {
                                        _isLoading = true;
                                      });
                                      _loadUserData();
                                    },
                                  ),
                              ],
                            ),
                            Text(
                              _isLoading
                                  ? "${localizations.translate("age")}: -"
                                  : _currentUser?.dateOfBirth != null
                                      ? "${localizations.translate("age")}: ${calculateAge(_currentUser!.dateOfBirth!)}"
                                      : "${localizations.translate("age")}: ${localizations.translate("not_set")}",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        Image.asset(
                          'assets/Logo.png',
                          height: 40,
                          width: 90,
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.notifications_active,
                                  color: Colors.white, size: 20),
                              onPressed: () {
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) =>
                                            NotificationsScreen()));
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.question_mark_outlined,
                                  color: Colors.white, size: 20),
                              onPressed: () {
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) => FAQScreen()));
                              },
                            ),
                            const Icon(
                              Icons.share,
                              color: Colors.white,
                              size: 20,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

//////////////////////////////////// Part 2 ///////////////////////////////
          Expanded(
            flex: 3,
            child: Container(
              width: double.infinity,
              ////////////////// Curve ////////////////
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(80.0),
                ),
              ),

              child: Column(
                children: [
                  const SizedBox(
                    height: 50,
                  ),
                  ///////////////// Welcome Message ////////////////
                  Row(
                    children: [
                      const SizedBox(
                        width: 30,
                      ),
                      SizedBox(
                        child: Text(
                          _isLoading
                              ? "${localizations.translate("hello")}!"
                              : "${localizations.translate("hello")}, ${_currentUser?.fullName ?? localizations.translate("user")}!",
                          style: const TextStyle(
                            color: Color(0xFF0383c2),
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(
                    height: 45,
                  ),

                  ////////////////// Updated Icons Section with Navigation /////////////////
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildIconWithLabel(
                          context,
                          'assets/profile.png',
                          'profile',
                          () {
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => EditProfilePage()));
                          },
                        ),
                        _buildIconWithLabel(
                          context,
                          'assets/achieve.png',
                          'settings',
                          () {
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => SettingsScreen()));
                          },
                        ),
                        _buildIconWithLabel(
                          context,
                          'assets/goals.png',
                          'guide',
                          () {
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                        InstructionsScreen()));
                          },
                        ),
                        _buildIconWithLabel(
                          context,
                          'assets/help.png',
                          'about',
                          () {
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => AboutPage()));
                          },
                        ),
                      ],
                    ),
                  ),

                  //////////////////////// Button (Start Test) /////////////////////////
                  const SizedBox(height: 80),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        backgroundColor: const Color.fromRGBO(255, 255, 255, 1),
                        side: const BorderSide(
                            color: Color.fromRGBO(180, 180, 181, 0.3),
                            width: 2),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => HealthSummaryScreen()),
                        );
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            localizations.translate("start_test"),
                            style: const TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.bold,
                              color: Color(0xff065f89),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Image.asset(
                            "assets/start_test.png",
                            width: 50,
                            height: 60,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  //////////////////////// Button (Previous Results) /////////////////////////
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        backgroundColor: Colors.white,
                        side: const BorderSide(
                            color: Color.fromRGBO(180, 180, 181, 0.3),
                            width: 2),
                      ),
                      onPressed: () {
                        print("Previous Result Pressed");
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            localizations.translate("previous_results"),
                            style: const TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.bold,
                              color: Color(0xff065f89),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Image.asset(
                            "assets/prev_result.png",
                            width: 50,
                            height: 60,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
