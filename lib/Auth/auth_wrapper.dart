import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart'; // If needed for providers within pages

// Import your main pages
import 'package:bio_track/LandingPage.dart';
import 'package:bio_track/logInPage.dart'; // Assuming HomePage is your login page

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Listen to Firebase authentication state changes
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Check the connection state
        if (snapshot.connectionState == ConnectionState.waiting) {
          // Show a loading indicator while checking auth state
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(
                  // Optional: Use your theme color
                  // valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
                  ),
            ),
          );
        }

        // Check if there was an error (less common for authStateChanges)
        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(
              child: Text('Something went wrong. Please restart the app.'),
            ),
          );
        }

        // Check if the user is logged in
        if (snapshot.hasData && snapshot.data != null) {
          // User is logged in, show the main application screen
          print(
              "AuthWrapper: User is logged in (${snapshot.data!.uid}). Navigating to LandingPage.");
          return const LandingPage();
        } else {
          // User is logged out, show the login screen
          print(
              "AuthWrapper: User is logged out. Navigating to HomePage (Login).");
          // Assuming HomePage is your login page (logInPage.dart)
          return const HomePage();
        }
      },
    );
  }
}
