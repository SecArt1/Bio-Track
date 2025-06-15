# Firebase Configuration Setup

## Security Notice
The `lib/firebase_options.dart` file has been removed from this repository as it contained sensitive Firebase configuration data including API keys.

## Setup Instructions

1. **Install FlutterFire CLI**:
   ```bash
   dart pub global activate flutterfire_cli
   ```

2. **Configure Firebase for your project**:
   ```bash
   flutterfire configure
   ```
   
   This will:
   - Prompt you to select your Firebase project
   - Generate a new `lib/firebase_options.dart` file with your actual configuration
   - Set up platform-specific configurations

3. **Alternative Manual Setup**:
   If you prefer manual setup, copy `lib/firebase_options.dart.template` to `lib/firebase_options.dart` and replace the placeholder values with your actual Firebase configuration:
   
   - Get your config from Firebase Console > Project Settings > General
   - Replace `YOUR_*_HERE` placeholders with actual values
   - Never commit this file to version control

## Important Security Notes

- The `firebase_options.dart` file is now in `.gitignore` to prevent accidental commits
- Always use environment variables or secure configuration management in production
- Consider using Firebase App Check for additional security in production

## Required Firebase Services

This app uses:
- Firebase Firestore (Database)
- Firebase Authentication (if implemented)
- Firebase Storage (if implemented)

Make sure these services are enabled in your Firebase project.
