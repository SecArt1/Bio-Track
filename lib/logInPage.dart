import 'package:bio_track/main.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:bio_track/register.dart';
import 'package:bio_track/stillStart.dart';
import 'package:bio_track/forgotPassword.dart';
import 'package:bio_track/LandingPage.dart';
import 'package:bio_track/startScreen.dart';
import 'package:firebase_auth/firebase_auth.dart';
// Localization imports
import 'package:bio_track/l10n/app_localizations.dart';
import 'package:bio_track/l10n/language_provider.dart';
import 'package:bio_track/Auth/auth_wrapper.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Form controllers
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // Form state
  bool _isLoading = false;
  String? _errorMessage;

  // Add this at the top of your _HomePageState class
  bool _hasNavigated = false;

  // Form validation
  bool _validateForm() {
    final localizations = AppLocalizations.of(context);
    // Reset error message
    setState(() => _errorMessage = null);

    // Check if fields are empty
    if (_emailController.text.trim().isEmpty) {
      setState(() => _errorMessage = localizations.translate("enter_email"));
      return false;
    }

    if (_passwordController.text.isEmpty) {
      setState(() => _errorMessage = localizations.translate("enter_password"));
      return false;
    }

    return true;
  }

  // Update your _signIn method
  Future<void> _signIn() async {
    final localizations = AppLocalizations.of(context);

    if (!_validateForm()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Set global flag to ignore auth changes (from main.dart)
      ignoreAuthChanges = true;

      // Sign in
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      // Wait a moment for any auth listeners to fire and be ignored
      await Future.delayed(Duration(milliseconds: 300));

      if (!mounted) return;

      // Clear navigation stack and go to landing page instead of start screen
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LandingPage()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      print(
          "Firebase Auth Error: ${e.code} - ${e.message}"); // Add this debug line

      // Update error messages for each error type
      String errorMessage;
      switch (e.code) {
        case 'user-not-found':
          errorMessage = localizations.translate("user_not_found");
          break;
        case 'wrong-password':
          errorMessage = localizations.translate("wrong_password");
          break;
        case 'invalid-email':
          errorMessage = localizations.translate("invalid_email");
          break;
        case 'user-disabled':
          errorMessage = localizations.translate("user_disabled");
          break;
        case 'network-request-failed':
          errorMessage = localizations.translate("network_error");
          break;
        case 'invalid-credential':
        case 'invalid-verification-code':
        case 'invalid-verification-id':
          errorMessage = localizations.translate("invalid_credentials");
          break;
        case 'too-many-requests':
          errorMessage = localizations.translate("too_many_requests");
          break;
        default:
          errorMessage =
              "${localizations.translate("login_error")}: ${e.message}";
          break;
      }

      // Update state with error message
      if (mounted) {
        setState(() {
          _errorMessage = errorMessage;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("General error: $e"); // Debug info

      // Check if we're actually logged in despite the error
      if (FirebaseAuth.instance.currentUser != null) {
        // We're logged in! Navigate to landing page despite the error
        print("User is authenticated despite error, navigating...");

        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LandingPage()),
          (route) => false,
        );
      } else {
        // Only show error if we're not logged in
        if (mounted) {
          setState(() {
            _errorMessage = localizations.translate("general_error");
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isArabic = languageProvider.isArabic;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.all(0.0),
              child: Container(
                height: 200,
                width: double.infinity,
                color: Colors.white,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 70),
                    Image.asset(
                      'assets/Logo2.png',
                      width: 250,
                    ),
                    const SizedBox(height: 40),

                    // Error message display
                    if (_errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(8),
                        margin: const EdgeInsets.symmetric(
                            vertical: 10, horizontal: 20),
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error, color: Colors.red),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 20),
                    SizedBox(
                      width: 300,
                      height: 60,
                      child: TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          fillColor: const Color.fromARGB(255, 3, 131, 194),
                          iconColor: const Color.fromARGB(255, 3, 131, 194),
                          labelText: localizations.translate("email"),
                          labelStyle: const TextStyle(
                            color: Color.fromARGB(255, 95, 127, 154),
                          ),
                          prefixIcon: const Icon(Icons.person),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30.0),
                            borderSide: const BorderSide(
                              color: Color.fromARGB(255, 3, 131, 194),
                            ),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30.0),
                            borderSide: const BorderSide(
                                color: Color.fromARGB(255, 3, 131, 194)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30.0),
                            borderSide: const BorderSide(
                                color: Color.fromARGB(255, 3, 131, 194)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: 300,
                      height: 60,
                      child: TextField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          fillColor: const Color.fromARGB(255, 3, 131, 194),
                          iconColor: const Color.fromARGB(255, 3, 131, 194),
                          labelText: localizations.translate("password"),
                          labelStyle: TextStyle(
                            color: const Color.fromARGB(255, 95, 127, 154),
                          ),
                          prefixIcon: const Icon(Icons.lock),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30.0),
                            borderSide: const BorderSide(
                              color: Color.fromARGB(255, 3, 131, 194),
                            ),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30.0),
                            borderSide: const BorderSide(
                                color: Color.fromARGB(255, 3, 131, 194)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30.0),
                            borderSide: const BorderSide(
                                color: Color.fromARGB(255, 3, 131, 194)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              decoration: const BoxDecoration(
                color: Color.fromARGB(255, 3, 131, 194),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(40.0),
                  topRight: Radius.circular(40.0),
                ),
              ),
              width: double.infinity,
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => ForgotPassword()),
                            );
                          },
                    child: Text(
                      localizations.translate("forgot_password"),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _signIn,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(300, 50),
                      backgroundColor: const Color.fromARGB(255, 255, 255, 255),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20.0),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(
                            color: Color.fromARGB(255, 2, 113, 169),
                          )
                        : Text(
                            localizations.translate("sign_in"),
                            style: const TextStyle(
                              color: Color.fromARGB(255, 2, 113, 169),
                            ),
                          ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    localizations.translate("or"),
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => RegisterPage()),
                            );
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 2, 109, 162),
                      minimumSize: const Size(300, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20.0),
                        side: const BorderSide(
                          color: Color.fromARGB(255, 255, 255, 255),
                        ),
                      ),
                    ),
                    child: Text(
                      localizations.translate("create_account"),
                      style: const TextStyle(color: Colors.white),
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
