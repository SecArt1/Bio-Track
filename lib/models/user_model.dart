import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String fullName;
  final String email;
  final Timestamp createdAt;

  // Basic user info
  final String? phoneNumber;
  final DateTime? dateOfBirth;
  final String? gender;
  final String? photoUrl;
  final String? address;

  // Health metrics
  final Map<String, dynamic>?
      healthMetrics; // For storing latest health measurements
  final List<Map<String, dynamic>>?
      healthHistory; // For tracking changes over time

  // Medical information
  final String? bloodType;
  final List<String>? allergies;
  final List<String>? medications;
  final List<String>? medicalConditions;
  final Map<String, dynamic>? emergencyContact;

  // Fitness goals and tracking
  final Map<String, dynamic>? fitnessGoals;
  final Map<String, dynamic>? activityTracking;

  UserModel({
    required this.uid,
    required this.fullName,
    required this.email,
    required this.createdAt,
    this.phoneNumber,
    this.dateOfBirth,
    this.gender,
    this.photoUrl,
    this.address,
    this.healthMetrics,
    this.healthHistory,
    this.bloodType,
    this.allergies,
    this.medications,
    this.medicalConditions,
    this.emergencyContact,
    this.fitnessGoals,
    this.activityTracking,
  });

  // Create from Firestore document
  factory UserModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    // Handle dateOfBirth which could be either a String or a Timestamp
    DateTime? parsedDateOfBirth;
    if (data['dateOfBirth'] != null) {
      if (data['dateOfBirth'] is Timestamp) {
        parsedDateOfBirth = (data['dateOfBirth'] as Timestamp).toDate();
      } else if (data['dateOfBirth'] is String) {
        // Parse the string date format
        try {
          parsedDateOfBirth = DateTime.parse(data['dateOfBirth']);
        } catch (e) {
          print("Error parsing dateOfBirth: $e");
        }
      }
    }

    return UserModel(
      uid: doc.id,
      fullName: data['fullName'] ?? 'User',
      email: data['email'] ?? '',
      createdAt:
          data['createdAt'] is Timestamp ? data['createdAt'] : Timestamp.now(),

      // Use the parsed date
      dateOfBirth: parsedDateOfBirth,

      // Rest of your model fields...
      phoneNumber: data['phoneNumber'],
      gender: data['gender'],
      photoUrl: data['photoUrl'],
      address: data['address'],

      // Health metrics
      healthMetrics: data['healthMetrics'],
      healthHistory: data['healthHistory'] != null
          ? List<Map<String, dynamic>>.from(data['healthHistory'])
          : null,

      // Medical information
      bloodType: data['bloodType'],
      allergies: data['allergies'] != null
          ? List<String>.from(data['allergies'])
          : null,
      medications: data['medications'] != null
          ? List<String>.from(data['medications'])
          : null,
      medicalConditions: data['medicalConditions'] != null
          ? List<String>.from(data['medicalConditions'])
          : null,
      emergencyContact: data['emergencyContact'],

      // Fitness goals and tracking
      fitnessGoals: data['fitnessGoals'],
      activityTracking: data['activityTracking'],
    );
  }

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'fullName': fullName,
      'email': email,
      'createdAt': createdAt,

      // Only include non-null fields
      if (phoneNumber != null) 'phoneNumber': phoneNumber,
      if (dateOfBirth != null) 'dateOfBirth': Timestamp.fromDate(dateOfBirth!),
      if (gender != null) 'gender': gender,
      if (photoUrl != null) 'photoUrl': photoUrl,
      if (address != null) 'address': address,

      if (healthMetrics != null) 'healthMetrics': healthMetrics,
      if (healthHistory != null) 'healthHistory': healthHistory,

      if (bloodType != null) 'bloodType': bloodType,
      if (allergies != null) 'allergies': allergies,
      if (medications != null) 'medications': medications,
      if (medicalConditions != null) 'medicalConditions': medicalConditions,
      if (emergencyContact != null) 'emergencyContact': emergencyContact,

      if (fitnessGoals != null) 'fitnessGoals': fitnessGoals,
      if (activityTracking != null) 'activityTracking': activityTracking,
    };
  }

  // Create a copy with updated fields
  UserModel copyWith({
    String? fullName,
    String? email,
    String? phoneNumber,
    DateTime? dateOfBirth,
    String? gender,
    String? photoUrl,
    String? address,
    Map<String, dynamic>? healthMetrics,
    List<Map<String, dynamic>>? healthHistory,
    String? bloodType,
    List<String>? allergies,
    List<String>? medications,
    List<String>? medicalConditions,
    Map<String, dynamic>? emergencyContact,
    Map<String, dynamic>? fitnessGoals,
    Map<String, dynamic>? activityTracking,
  }) {
    return UserModel(
      uid: this.uid,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      createdAt: this.createdAt,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      photoUrl: photoUrl ?? this.photoUrl,
      address: address ?? this.address,
      healthMetrics: healthMetrics ?? this.healthMetrics,
      healthHistory: healthHistory ?? this.healthHistory,
      bloodType: bloodType ?? this.bloodType,
      allergies: allergies ?? this.allergies,
      medications: medications ?? this.medications,
      medicalConditions: medicalConditions ?? this.medicalConditions,
      emergencyContact: emergencyContact ?? this.emergencyContact,
      fitnessGoals: fitnessGoals ?? this.fitnessGoals,
      activityTracking: activityTracking ?? this.activityTracking,
    );
  }
}
