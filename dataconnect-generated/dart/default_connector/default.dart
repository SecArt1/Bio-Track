library default_connector;

import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';

/// DefaultConnector provides a simplified interface for Firebase operations
/// This implementation uses standard Firebase packages instead of firebase_data_connect
class DefaultConnector {
  // Singleton instance
  static DefaultConnector? _instance;

  // Firebase configuration
  static final String projectId = 'gp';
  static final String region = 'us-central1';

  // Firebase instances
  final FirebaseFirestore firestore;

  // Private constructor
  DefaultConnector._({required this.firestore});

  // Factory constructor to get the singleton instance
  static DefaultConnector get instance {
    if (_instance == null) {
      // Initialize with standard Firebase instances
      _instance = DefaultConnector._(
        firestore: FirebaseFirestore.instance,
      );
    }
    return _instance!;
  }

  // Initialize Firebase if needed
  static Future<void> ensureInitialized() async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  }

  // Example method to get a collection reference
  CollectionReference collection(String path) {
    return firestore.collection(path);
  }

  // Example method to get a document reference
  DocumentReference document(String path) {
    return firestore.doc(path);
  }

  // Add more methods as needed to match your original functionality
}
