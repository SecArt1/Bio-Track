import 'package:bio_track/LandingPage.dart';
import 'package:bio_track/pages/profile_completion_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:bio_track/stillStart.dart';
import 'package:bio_track/logInPage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bio_track/services/user_service.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  // Form controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  // Form state
  bool _agreeToTerms = false;
  bool _isLoading = false;
  String? _errorMessage;

  // Form validation
  bool _isValidEmail(String email) {
    final RegExp emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(email);
  }

  bool _validateForm() {
    // Reset error message
    setState(() => _errorMessage = null);

    // Check if fields are empty
    if (_nameController.text.trim().isEmpty) {
      setState(() => _errorMessage = "Please enter your name");
      return false;
    }

    if (_emailController.text.trim().isEmpty) {
      setState(() => _errorMessage = "Please enter your email");
      return false;
    }

    if (!_isValidEmail(_emailController.text.trim())) {
      setState(() => _errorMessage = "Please enter a valid email address");
      return false;
    }

    if (_passwordController.text.isEmpty) {
      setState(() => _errorMessage = "Please enter a password");
      return false;
    }

    if (_passwordController.text.length < 6) {
      setState(() => _errorMessage = "Password must be at least 6 characters");
      return false;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() => _errorMessage = "Passwords do not match");
      return false;
    }

    if (!_agreeToTerms) {
      setState(() =>
          _errorMessage = "You must agree to the terms and privacy policy");
      return false;
    }

    return true;
  }

  // Sign up with Firebase
  Future<void> _signUp() async {
    if (!_validateForm()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Create user in Firebase Auth
      final userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      final user = userCredential.user;
      print("User created successfully: ${user?.uid}");

      if (user != null) {
        // Save user data to Firestore
        try {
          final userService = UserService();
          await userService.createUser(user, _nameController.text.trim());
          print("User data saved to Firestore");
        } catch (firestoreError) {
          print("Error saving to Firestore: $firestoreError");
          // Continue despite error
        }

        // Reset loading state
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }

        if (!mounted) return;

        // Show dialog for profile completion
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              title: const Text('Account Created Successfully'),
              content:
                  const Text('Would you like to complete your profile now?'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                          builder: (context) => const LandingPage()),
                      (route) => false,
                    );
                  },
                  child: const Text('Skip for now'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0383C2),
                    foregroundColor:
                        Colors.white, // Add this to ensure text is white
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                  ),
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (context) => const ProfileCompletionPage(
                          isAfterRegistration: true,
                        ),
                      ),
                      (route) => false,
                    );
                  },
                  child: const Text('Complete Profile'),
                ),
              ],
            );
          },
        );
      }
    } catch (e) {
      print("Registration error: $e");

      // Add this critical line to reset loading state on error
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Registration failed: ${e.toString()}";
        });
      }

      // Check if the user was created despite the error
      final createdUser = FirebaseAuth.instance.currentUser;
      if (createdUser != null) {
        // Reset loading state (redundant but ensures it happens)
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }

        if (!mounted) return;

        // Show dialog for profile completion
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              title: const Text('Account Created Successfully'),
              content:
                  const Text('Would you like to complete your profile now?'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                          builder: (context) => const LandingPage()),
                      (route) => false,
                    );
                  },
                  child: const Text('Skip for now'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0383C2),
                    foregroundColor:
                        Colors.white, // Add this to ensure text is white
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                  ),
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (context) => const ProfileCompletionPage(
                          isAfterRegistration: true,
                        ),
                      ),
                      (route) => false,
                    );
                  },
                  child: const Text('Complete Profile'),
                ),
              ],
            );
          },
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Padding(
        padding: const EdgeInsets.all(0.0),
        child: Column(
          children: [
            // First section remains unchanged
            Flexible(
              flex: 1,
              child: Container(
                decoration: const BoxDecoration(
                    color: Color.fromARGB(255, 3, 131, 194),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(40.0),
                      bottomRight: Radius.circular(40.0),
                    )),
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.only(left: 20.0),
                child: const Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: "Let's ",
                        style: TextStyle(
                          color: Color.fromARGB(255, 255, 255, 255),
                          fontSize: 35.0,
                        ),
                      ),
                      TextSpan(
                        text: "\nCreate \nYour \nAccount",
                        style: TextStyle(
                          color: Color.fromARGB(255, 255, 255, 255),
                          fontSize: 35.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Second section with form
            Flexible(
              flex: 2,
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(16.0),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Error message display
                      if (_errorMessage != null)
                        Container(
                          padding: const EdgeInsets.all(8),
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: Colors.red.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error, color: Colors.red),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Name field
                      TextField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          fillColor: const Color.fromARGB(255, 3, 131, 194),
                          iconColor: const Color.fromARGB(255, 3, 131, 194),
                          labelText: 'Full Name',
                          labelStyle: const TextStyle(
                            color: Color.fromARGB(255, 95, 127, 154),
                          ),
                          prefixIcon: const Icon(Icons.person),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30.0),
                            borderSide: const BorderSide(
                              color: Color.fromARGB(255, 3, 131, 194),
                              width: 2.0,
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
                      const SizedBox(height: 10),

                      // Email field
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          fillColor: const Color.fromARGB(255, 3, 131, 194),
                          iconColor: const Color.fromARGB(255, 3, 131, 194),
                          labelText: 'Email',
                          labelStyle: const TextStyle(
                            color: Color.fromARGB(255, 95, 127, 154),
                          ),
                          prefixIcon: const Icon(Icons.mail),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30.0),
                            borderSide: const BorderSide(
                              color: Color.fromARGB(255, 3, 131, 194),
                              width: 2.0,
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
                      const SizedBox(height: 10),

                      // Password field
                      TextField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          fillColor: const Color.fromARGB(255, 3, 131, 194),
                          iconColor: const Color.fromARGB(255, 3, 131, 194),
                          labelText: 'Password',
                          labelStyle: const TextStyle(
                            color: Color.fromARGB(255, 95, 127, 154),
                          ),
                          prefixIcon: const Icon(Icons.lock),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30.0),
                            borderSide: const BorderSide(
                              color: Color.fromARGB(255, 3, 131, 194),
                              width: 2.0,
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
                        obscureText: true,
                      ),
                      const SizedBox(height: 10),

                      // Confirm password field
                      TextField(
                        controller: _confirmPasswordController,
                        decoration: InputDecoration(
                          fillColor: const Color.fromARGB(255, 3, 131, 194),
                          iconColor: const Color.fromARGB(255, 3, 131, 194),
                          labelText: 'Retype Password',
                          labelStyle: const TextStyle(
                            color: Color.fromARGB(255, 95, 127, 154),
                          ),
                          prefixIcon: const Icon(
                              Icons.lock), // Changed from person to lock icon
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30.0),
                            borderSide: const BorderSide(
                              color: Color.fromARGB(255, 3, 131, 194),
                              width: 2.0,
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
                        obscureText: true,
                      ),
                      const SizedBox(height: 10),

                      // Terms checkbox
                      Row(
                        children: [
                          Checkbox(
                            value: _agreeToTerms,
                            onChanged: (bool? value) {
                              setState(() {
                                _agreeToTerms = value ?? false;
                              });
                            },
                            activeColor: const Color.fromARGB(255, 6, 106, 222),
                          ),
                          const Text(
                            'I agree to the Terms & Privacy',
                            style: TextStyle(
                              color: Color.fromARGB(255, 70, 108, 139),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Sign up button
                      Center(
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _signUp,
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                const Color.fromARGB(255, 2, 109, 162),
                            minimumSize: const Size(300, 50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20.0),
                              side: const BorderSide(
                                color: Color.fromARGB(255, 255, 255, 255),
                              ),
                            ),
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(
                                  color: Colors.white)
                              : const Text(
                                  'Sign up',
                                  style: TextStyle(color: Colors.white),
                                ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Login link
                      Center(
                        child: TextButton(
                          onPressed: _isLoading
                              ? null
                              : () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) => HomePage()),
                                  );
                                },
                          child: const Text(
                            'Have an account? Sign In',
                            style: TextStyle(
                              color: Color.fromARGB(255, 70, 108, 139),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
