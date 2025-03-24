import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:bio_track/models/user_model.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Collection reference
  final CollectionReference _usersCollection =
      FirebaseFirestore.instance.collection('users');

  // Create new user document with better debugging
  Future<void> createUser(User user, String displayName) async {
    try {
      print("Creating Firestore user document for uid: ${user.uid}");
      final userData = {
        'fullName': displayName,
        'email': user.email ?? '',
        'createdAt': Timestamp.now(),
      };

      print("Data to save: $userData");
      await _firestore.collection('users').doc(user.uid).set(userData);
      print("User document created successfully");
    } catch (e) {
      print("Error creating user document: $e");
      throw e;
    }
  }

  // Get current user data with better debugging
  Future<UserModel?> getCurrentUser() async {
    try {
      final user = _auth.currentUser;
      print("Current Firebase Auth user: ${user?.uid}");

      if (user == null) {
        print("No authenticated user found");
        return null;
      }

      print("Fetching Firestore document for user: ${user.uid}");
      final docSnapshot =
          await _firestore.collection('users').doc(user.uid).get();

      if (!docSnapshot.exists) {
        print("No Firestore document exists for user: ${user.uid}");

        // Create a record if it doesn't exist
        print("Creating a new user document");
        await createUser(user, user.displayName ?? "New User");

        // Try to get the document again
        final newDocSnapshot =
            await _firestore.collection('users').doc(user.uid).get();
        if (!newDocSnapshot.exists) {
          print("Still no document after creation attempt");
          return null;
        }

        print("Document created successfully");
        return UserModel.fromDocument(newDocSnapshot);
      }

      print("Found Firestore document. Data: ${docSnapshot.data()}");
      return UserModel.fromDocument(docSnapshot);
    } catch (e) {
      print("Error in getCurrentUser: $e");
      return null;
    }
  }

  // Update user profile
  Future<void> updateUserProfile(Map<String, dynamic> data) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _usersCollection.doc(user.uid).update(data);
  }

  // Add medical information
  Future<void> addMedicalInfo(Map<String, dynamic> medicalData) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _usersCollection.doc(user.uid).update({
      'medicalInfo': medicalData,
    });
  }

  // Update health metrics
  Future<void> updateHealthMetrics(Map<String, dynamic> metrics) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final docRef =
          FirebaseFirestore.instance.collection('users').doc(user.uid);

      // Get current data to update history
      final docSnapshot = await docRef.get();
      if (docSnapshot.exists) {
        final userData = docSnapshot.data() as Map<String, dynamic>;

        // Add timestamp to metrics
        metrics['recordedAt'] = Timestamp.now();

        // Create/update health history
        List<Map<String, dynamic>> healthHistory = [];
        if (userData['healthHistory'] != null) {
          healthHistory =
              List<Map<String, dynamic>>.from(userData['healthHistory']);
        }
        healthHistory.add(metrics);

        // Update document with new metrics and history
        await docRef.update({
          'healthMetrics': metrics,
          'healthHistory': healthHistory,
          'lastUpdated': Timestamp.now(),
        });
      } else {
        // If document doesn't exist, create it
        await docRef.set({
          'healthMetrics': metrics,
          'healthHistory': [metrics],
          'createdAt': Timestamp.now(),
          'lastUpdated': Timestamp.now(),
        });
      }
    } catch (e) {
      print("Error updating health metrics: $e");
      throw e;
    }
  }

  // Update medical information
  Future<void> updateMedicalInfo(Map<String, dynamic> medicalInfo) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        ...medicalInfo,
        'lastUpdated': Timestamp.now(),
      });
    } catch (e) {
      print("Error updating medical info: $e");
      throw e;
    }
  }

  // Update user profile with timestamp
  Future<void> updateUserProfileWithTimestamp(Map<String, dynamic> profileData) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        ...profileData,
        'lastUpdated': Timestamp.now(),
      });
    } catch (e) {
      print("Error updating user profile: $e");
      throw e;
    }
  }

  // Add fitness goals
  Future<void> setFitnessGoals(Map<String, dynamic> goals) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'fitnessGoals': goals,
        'lastUpdated': Timestamp.now(),
      });
    } catch (e) {
      print("Error setting fitness goals: $e");
      throw e;
    }
  }
}
