import 'package:flutter/material.dart';
import 'package:bio_track/services/user_service.dart';
import 'package:bio_track/models/user_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:bio_track/LandingPage.dart';
// Import localization
import 'package:bio_track/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:bio_track/l10n/language_provider.dart';

class ProfileCompletionPage extends StatefulWidget {
  final bool isAfterRegistration;

  const ProfileCompletionPage({Key? key, this.isAfterRegistration = false})
      : super(key: key);

  @override
  State<ProfileCompletionPage> createState() => _ProfileCompletionPageState();
}

class _ProfileCompletionPageState extends State<ProfileCompletionPage> {
  final _userService = UserService();
  UserModel? _currentUser;
  bool _isLoading = true;

  // Form controllers
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  DateTime? _selectedDate;
  String? _selectedGender;
  String? _selectedBloodType;
  final _bloodTypeController = TextEditingController();
  final _allergiesController = TextEditingController();
  final _medicationsController = TextEditingController();
  final _conditionsController = TextEditingController();
  final _emergencyNameController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();
  final _emergencyRelationController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();

  // Expanded sections
  bool _basicInfoExpanded = true;
  bool _medicalInfoExpanded = false;
  bool _emergencyContactExpanded = false;
  bool _healthMetricsExpanded = false;

  // Gender options
  final List<String> _genders = [
    'Male',
    'Female',
  ];

  // Blood type options
  final List<String> _bloodTypes = [
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-'
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = await _userService.getCurrentUser();

      if (mounted) {
        setState(() {
          _currentUser = user;
          _isLoading = false;

          // Populate form fields if data exists
          if (user != null) {
            _phoneController.text = user.phoneNumber ?? '';
            _addressController.text = user.address ?? '';
            _selectedDate = user.dateOfBirth;
            _selectedGender = user.gender;
            _selectedBloodType = user.bloodType;
            _bloodTypeController.text = user.bloodType ?? '';
            _allergiesController.text = user.allergies?.join(', ') ?? '';
            _medicationsController.text = user.medications?.join(', ') ?? '';
            _conditionsController.text =
                user.medicalConditions?.join(', ') ?? '';

            // Emergency contact
            if (user.emergencyContact != null) {
              _emergencyNameController.text =
                  user.emergencyContact!['name'] ?? '';
              _emergencyPhoneController.text =
                  user.emergencyContact!['phone'] ?? '';
              _emergencyRelationController.text =
                  user.emergencyContact!['relation'] ?? '';
            }

            // Health metrics
            if (user.healthMetrics != null) {
              _heightController.text =
                  user.healthMetrics!['height']?.toString() ?? '';
              _weightController.text =
                  user.healthMetrics!['weight']?.toString() ?? '';
            }
          }
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

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ??
          DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0383C2),
              onPrimary: Colors.white,
              onSurface: Color(0xFF0383C2),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF0383C2),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _saveProfile() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Prepare basic info data
      final basicInfoData = {
        'phoneNumber': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'gender': _selectedGender,
      };

      // Convert DateTime to String before storing
      if (_selectedDate != null) {
        basicInfoData['dateOfBirth'] =
            DateFormat('yyyy-MM-dd').format(_selectedDate!);
      }

      // Prepare medical info
      final medicalInfoData = {
        'bloodType': _bloodTypeController.text.trim(),
        'allergies': _allergiesController.text.isEmpty
            ? []
            : _allergiesController.text
                .split(',')
                .map((e) => e.trim())
                .toList(),
        'medications': _medicationsController.text.isEmpty
            ? []
            : _medicationsController.text
                .split(',')
                .map((e) => e.trim())
                .toList(),
        'medicalConditions': _conditionsController.text.isEmpty
            ? []
            : _conditionsController.text
                .split(',')
                .map((e) => e.trim())
                .toList(),
      };

      // Prepare emergency contact
      final emergencyContactData = {
        'emergencyContact': {
          'name': _emergencyNameController.text.trim(),
          'phone': _emergencyPhoneController.text.trim(),
          'relation': _emergencyRelationController.text.trim(),
        }
      };

      // Prepare health metrics
      final healthMetricsData = {
        'height': _heightController.text.isEmpty
            ? null
            : double.tryParse(_heightController.text),
        'weight': _weightController.text.isEmpty
            ? null
            : double.tryParse(_weightController.text),
        'recordedAt': Timestamp.now(),
      };

      // Update user profile with all data
      await _userService.updateUserProfileWithTimestamp({
        ...basicInfoData,
        ...medicalInfoData,
        ...emergencyContactData,
      });

      // Update health metrics if provided
      if (_heightController.text.isNotEmpty ||
          _weightController.text.isNotEmpty) {
        await _userService.updateHealthMetrics(healthMetricsData);
      }

      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate to landing page
        if (widget.isAfterRegistration) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LandingPage()),
          );
        } else {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      print("Error saving profile: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating profile: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isArabic = languageProvider.isArabic;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0383C2),
        elevation: 0,
        title: Text(localizations.translate('complete_profile'),
            style: const TextStyle(color: Colors.white)),
        leading: widget.isAfterRegistration
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF0383C2)))
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16.0),
                    color: const Color(0xFF0383C2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isArabic
                              ? localizations
                                  .translate('personalize_experience')
                              : localizations
                                  .translate('personalize_experience'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          localizations.translate('optional_fields'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Form
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        // Basic Information
                        Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: ExpansionTile(
                            initiallyExpanded: _basicInfoExpanded,
                            onExpansionChanged: (expanded) {
                              setState(() {
                                _basicInfoExpanded = expanded;
                              });
                            },
                            title: Text(
                              localizations.translate('basic_information'),
                              style: const TextStyle(
                                color: Color(0xFF0383C2),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  children: [
                                    // Phone Number
                                    TextField(
                                      controller: _phoneController,
                                      keyboardType: TextInputType.phone,
                                      decoration: InputDecoration(
                                        fillColor: const Color.fromARGB(
                                            255, 3, 131, 194),
                                        iconColor: const Color.fromARGB(
                                            255, 3, 131, 194),
                                        labelText:
                                            localizations.translate('phone'),
                                        labelStyle: const TextStyle(
                                          color:
                                              Color.fromARGB(255, 95, 127, 154),
                                        ),
                                        prefixIcon: const Icon(Icons.phone),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(30.0),
                                          borderSide: const BorderSide(
                                            color: Color.fromARGB(
                                                255, 3, 131, 194),
                                            width: 2.0,
                                          ),
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(30.0),
                                          borderSide: const BorderSide(
                                              color: Color.fromARGB(
                                                  255, 3, 131, 194)),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(30.0),
                                          borderSide: const BorderSide(
                                              color: Color.fromARGB(
                                                  255, 3, 131, 194)),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),

                                    // Date of Birth
                                    InkWell(
                                      onTap: () => _selectDate(context),
                                      child: InputDecorator(
                                        decoration: InputDecoration(
                                          fillColor: const Color.fromARGB(
                                              255, 3, 131, 194),
                                          iconColor: const Color.fromARGB(
                                              255, 3, 131, 194),
                                          labelText: localizations
                                              .translate('date_of_birth'),
                                          labelStyle: const TextStyle(
                                            color: Color.fromARGB(
                                                255, 95, 127, 154),
                                          ),
                                          prefixIcon:
                                              const Icon(Icons.calendar_today),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(30.0),
                                            borderSide: const BorderSide(
                                              color: Color.fromARGB(
                                                  255, 3, 131, 194),
                                              width: 2.0,
                                            ),
                                          ),
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(30.0),
                                            borderSide: const BorderSide(
                                                color: Color.fromARGB(
                                                    255, 3, 131, 194)),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(30.0),
                                            borderSide: const BorderSide(
                                                color: Color.fromARGB(
                                                    255, 3, 131, 194)),
                                          ),
                                        ),
                                        child: Text(
                                          _selectedDate == null
                                              ? localizations
                                                  .translate('select_date')
                                              : DateFormat('MMM dd, yyyy')
                                                  .format(_selectedDate!),
                                          style: TextStyle(
                                            color: _selectedDate == null
                                                ? Colors.grey
                                                : Colors.black,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),

                                    // Gender
                                    DropdownButtonFormField<String>(
                                      value: _selectedGender,
                                      decoration: InputDecoration(
                                        fillColor: const Color.fromARGB(
                                            255, 3, 131, 194),
                                        iconColor: const Color.fromARGB(
                                            255, 3, 131, 194),
                                        labelText:
                                            localizations.translate('gender'),
                                        labelStyle: const TextStyle(
                                          color:
                                              Color.fromARGB(255, 95, 127, 154),
                                        ),
                                        prefixIcon: const Icon(Icons.person),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(30.0),
                                          borderSide: const BorderSide(
                                            color: Color.fromARGB(
                                                255, 3, 131, 194),
                                            width: 2.0,
                                          ),
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(30.0),
                                          borderSide: const BorderSide(
                                              color: Color.fromARGB(
                                                  255, 3, 131, 194)),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(30.0),
                                          borderSide: const BorderSide(
                                              color: Color.fromARGB(
                                                  255, 3, 131, 194)),
                                        ),
                                      ),
                                      items: [
                                        DropdownMenuItem(
                                          value: 'male',
                                          child: Text(
                                              localizations.translate('male')),
                                        ),
                                        DropdownMenuItem(
                                          value: 'female',
                                          child: Text(localizations
                                              .translate('female')),
                                        ),
                                      ],
                                      onChanged: (value) {
                                        setState(() {
                                          _selectedGender = value;
                                        });
                                      },
                                    ),
                                    const SizedBox(height: 16),

                                    // Address
                                    TextField(
                                      controller: _addressController,
                                      decoration: InputDecoration(
                                        fillColor: const Color.fromARGB(
                                            255, 3, 131, 194),
                                        iconColor: const Color.fromARGB(
                                            255, 3, 131, 194),
                                        labelText:
                                            localizations.translate('address'),
                                        labelStyle: const TextStyle(
                                          color:
                                              Color.fromARGB(255, 95, 127, 154),
                                        ),
                                        prefixIcon: const Icon(Icons.home),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(30.0),
                                          borderSide: const BorderSide(
                                            color: Color.fromARGB(
                                                255, 3, 131, 194),
                                            width: 2.0,
                                          ),
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(30.0),
                                          borderSide: const BorderSide(
                                              color: Color.fromARGB(
                                                  255, 3, 131, 194)),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(30.0),
                                          borderSide: const BorderSide(
                                              color: Color.fromARGB(
                                                  255, 3, 131, 194)),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Medical Information
                        Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: ExpansionTile(
                            initiallyExpanded: _medicalInfoExpanded,
                            onExpansionChanged: (expanded) {
                              setState(() {
                                _medicalInfoExpanded = expanded;
                              });
                            },
                            title: Text(
                              localizations.translate('medical_information'),
                              style: const TextStyle(
                                color: Color(0xFF0383C2),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  children: [
                                    // Blood Type
                                    DropdownButtonFormField<String>(
                                      value: _selectedBloodType,
                                      decoration: InputDecoration(
                                        fillColor: const Color.fromARGB(
                                            255, 3, 131, 194),
                                        iconColor: const Color.fromARGB(
                                            255, 3, 131, 194),
                                        labelText: localizations
                                            .translate('blood_type'),
                                        labelStyle: const TextStyle(
                                          color:
                                              Color.fromARGB(255, 95, 127, 154),
                                        ),
                                        prefixIcon: const Icon(Icons.bloodtype),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(30.0),
                                          borderSide: const BorderSide(
                                            color: Color.fromARGB(
                                                255, 3, 131, 194),
                                            width: 2.0,
                                          ),
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(30.0),
                                          borderSide: const BorderSide(
                                              color: Color.fromARGB(
                                                  255, 3, 131, 194)),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(30.0),
                                          borderSide: const BorderSide(
                                              color: Color.fromARGB(
                                                  255, 3, 131, 194)),
                                        ),
                                      ),
                                      items: [
                                        'A+',
                                        'A-',
                                        'B+',
                                        'B-',
                                        'AB+',
                                        'AB-',
                                        'O+',
                                        'O-'
                                      ].map((String value) {
                                        return DropdownMenuItem<String>(
                                          value: value,
                                          child: Text(value),
                                        );
                                      }).toList(),
                                      onChanged: (value) {
                                        setState(() {
                                          _selectedBloodType = value;
                                        });
                                      },
                                    ),
                                    const SizedBox(height: 16),

                                    // Allergies
                                    TextField(
                                      controller: _allergiesController,
                                      decoration: InputDecoration(
                                        fillColor: const Color.fromARGB(
                                            255, 3, 131, 194),
                                        iconColor: const Color.fromARGB(
                                            255, 3, 131, 194),
                                        labelText: localizations
                                            .translate('allergies'),
                                        hintText: localizations
                                            .translate('allergies_hint'),
                                        labelStyle: const TextStyle(
                                          color:
                                              Color.fromARGB(255, 95, 127, 154),
                                        ),
                                        prefixIcon: const Icon(Icons.warning),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(30.0),
                                          borderSide: const BorderSide(
                                            color: Color.fromARGB(
                                                255, 3, 131, 194),
                                            width: 2.0,
                                          ),
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(30.0),
                                          borderSide: const BorderSide(
                                              color: Color.fromARGB(
                                                  255, 3, 131, 194)),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(30.0),
                                          borderSide: const BorderSide(
                                              color: Color.fromARGB(
                                                  255, 3, 131, 194)),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),

                                    // Medications
                                    TextField(
                                      controller: _medicationsController,
                                      decoration: InputDecoration(
                                        fillColor: const Color.fromARGB(
                                            255, 3, 131, 194),
                                        iconColor: const Color.fromARGB(
                                            255, 3, 131, 194),
                                        labelText: localizations
                                            .translate('medications'),
                                        hintText: localizations
                                            .translate('medications_hint'),
                                        labelStyle: const TextStyle(
                                          color:
                                              Color.fromARGB(255, 95, 127, 154),
                                        ),
                                        prefixIcon:
                                            const Icon(Icons.medication),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(30.0),
                                          borderSide: const BorderSide(
                                            color: Color.fromARGB(
                                                255, 3, 131, 194),
                                            width: 2.0,
                                          ),
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(30.0),
                                          borderSide: const BorderSide(
                                              color: Color.fromARGB(
                                                  255, 3, 131, 194)),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(30.0),
                                          borderSide: const BorderSide(
                                              color: Color.fromARGB(
                                                  255, 3, 131, 194)),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),

                                    // Medical Conditions
                                    TextField(
                                      controller: _conditionsController,
                                      decoration: InputDecoration(
                                        fillColor: const Color.fromARGB(
                                            255, 3, 131, 194),
                                        iconColor: const Color.fromARGB(
                                            255, 3, 131, 194),
                                        labelText: localizations
                                            .translate('medical_conditions'),
                                        hintText: localizations.translate(
                                            'medical_conditions_hint'),
                                        labelStyle: const TextStyle(
                                          color:
                                              Color.fromARGB(255, 95, 127, 154),
                                        ),
                                        prefixIcon:
                                            const Icon(Icons.medical_services),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(30.0),
                                          borderSide: const BorderSide(
                                            color: Color.fromARGB(
                                                255, 3, 131, 194),
                                            width: 2.0,
                                          ),
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(30.0),
                                          borderSide: const BorderSide(
                                              color: Color.fromARGB(
                                                  255, 3, 131, 194)),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(30.0),
                                          borderSide: const BorderSide(
                                              color: Color.fromARGB(
                                                  255, 3, 131, 194)),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Emergency Contact
                        Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: ExpansionTile(
                            initiallyExpanded: _emergencyContactExpanded,
                            onExpansionChanged: (expanded) {
                              setState(() {
                                _emergencyContactExpanded = expanded;
                              });
                            },
                            title: Text(
                              localizations.translate('emergency_contact'),
                              style: const TextStyle(
                                color: Color(0xFF0383C2),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  children: [
                                    // Emergency Contact Name
                                    TextField(
                                      controller: _emergencyNameController,
                                      decoration: InputDecoration(
                                        fillColor: const Color.fromARGB(
                                            255, 3, 131, 194),
                                        iconColor: const Color.fromARGB(
                                            255, 3, 131, 194),
                                        labelText:
                                            localizations.translate('name'),
                                        labelStyle: const TextStyle(
                                          color:
                                              Color.fromARGB(255, 95, 127, 154),
                                        ),
                                        prefixIcon: const Icon(Icons.person),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(30.0),
                                          borderSide: const BorderSide(
                                            color: Color.fromARGB(
                                                255, 3, 131, 194),
                                            width: 2.0,
                                          ),
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(30.0),
                                          borderSide: const BorderSide(
                                              color: Color.fromARGB(
                                                  255, 3, 131, 194)),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(30.0),
                                          borderSide: const BorderSide(
                                              color: Color.fromARGB(
                                                  255, 3, 131, 194)),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),

                                    // Emergency Contact Phone
                                    TextField(
                                      controller: _emergencyPhoneController,
                                      keyboardType: TextInputType.phone,
                                      decoration: InputDecoration(
                                        fillColor: const Color.fromARGB(
                                            255, 3, 131, 194),
                                        iconColor: const Color.fromARGB(
                                            255, 3, 131, 194),
                                        labelText:
                                            localizations.translate('phone'),
                                        labelStyle: const TextStyle(
                                          color:
                                              Color.fromARGB(255, 95, 127, 154),
                                        ),
                                        prefixIcon: const Icon(Icons.phone),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(30.0),
                                          borderSide: const BorderSide(
                                            color: Color.fromARGB(
                                                255, 3, 131, 194),
                                            width: 2.0,
                                          ),
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(30.0),
                                          borderSide: const BorderSide(
                                              color: Color.fromARGB(
                                                  255, 3, 131, 194)),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(30.0),
                                          borderSide: const BorderSide(
                                              color: Color.fromARGB(
                                                  255, 3, 131, 194)),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),

                                    // Emergency Contact Relation
                                    TextField(
                                      controller: _emergencyRelationController,
                                      decoration: InputDecoration(
                                        fillColor: const Color.fromARGB(
                                            255, 3, 131, 194),
                                        iconColor: const Color.fromARGB(
                                            255, 3, 131, 194),
                                        labelText: localizations
                                            .translate('relationship'),
                                        hintText: localizations
                                            .translate('relationship_hint'),
                                        labelStyle: const TextStyle(
                                          color:
                                              Color.fromARGB(255, 95, 127, 154),
                                        ),
                                        prefixIcon: const Icon(Icons.people),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(30.0),
                                          borderSide: const BorderSide(
                                            color: Color.fromARGB(
                                                255, 3, 131, 194),
                                            width: 2.0,
                                          ),
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(30.0),
                                          borderSide: const BorderSide(
                                              color: Color.fromARGB(
                                                  255, 3, 131, 194)),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(30.0),
                                          borderSide: const BorderSide(
                                              color: Color.fromARGB(
                                                  255, 3, 131, 194)),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Health Metrics
                        Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: ExpansionTile(
                            initiallyExpanded: _healthMetricsExpanded,
                            onExpansionChanged: (expanded) {
                              setState(() {
                                _healthMetricsExpanded = expanded;
                              });
                            },
                            title: Text(
                              localizations.translate('health_metrics'),
                              style: const TextStyle(
                                color: Color(0xFF0383C2),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  children: [
                                    // Height
                                    TextField(
                                      controller: _heightController,
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        fillColor: const Color.fromARGB(
                                            255, 3, 131, 194),
                                        iconColor: const Color.fromARGB(
                                            255, 3, 131, 194),
                                        labelText:
                                            localizations.translate('height'),
                                        labelStyle: const TextStyle(
                                          color:
                                              Color.fromARGB(255, 95, 127, 154),
                                        ),
                                        prefixIcon: const Icon(Icons.height),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(30.0),
                                          borderSide: const BorderSide(
                                            color: Color.fromARGB(
                                                255, 3, 131, 194),
                                            width: 2.0,
                                          ),
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(30.0),
                                          borderSide: const BorderSide(
                                              color: Color.fromARGB(
                                                  255, 3, 131, 194)),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(30.0),
                                          borderSide: const BorderSide(
                                              color: Color.fromARGB(
                                                  255, 3, 131, 194)),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),

                                    // Weight
                                    TextField(
                                      controller: _weightController,
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        fillColor: const Color.fromARGB(
                                            255, 3, 131, 194),
                                        iconColor: const Color.fromARGB(
                                            255, 3, 131, 194),
                                        labelText:
                                            localizations.translate('weight'),
                                        labelStyle: const TextStyle(
                                          color:
                                              Color.fromARGB(255, 95, 127, 154),
                                        ),
                                        prefixIcon:
                                            const Icon(Icons.monitor_weight),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(30.0),
                                          borderSide: const BorderSide(
                                            color: Color.fromARGB(
                                                255, 3, 131, 194),
                                            width: 2.0,
                                          ),
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(30.0),
                                          borderSide: const BorderSide(
                                              color: Color.fromARGB(
                                                  255, 3, 131, 194)),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(30.0),
                                          borderSide: const BorderSide(
                                              color: Color.fromARGB(
                                                  255, 3, 131, 194)),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Save Button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _saveProfile,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0383C2),
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.grey,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30.0),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.0,
                                    ))
                                : Text(
                                    localizations.translate('save_profile'),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),

                        // Skip Button (only show after registration)
                        if (widget.isAfterRegistration)
                          Padding(
                            padding: const EdgeInsets.only(top: 16.0),
                            child: TextButton(
                              onPressed: _isLoading
                                  ? null
                                  : () {
                                      Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const LandingPage(),
                                        ),
                                      );
                                    },
                              child: Text(
                                localizations.translate('skip_for_now'),
                                style: const TextStyle(
                                  color: Color(0xFF0383C2),
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _addressController.dispose();
    _bloodTypeController.dispose();
    _allergiesController.dispose();
    _medicationsController.dispose();
    _conditionsController.dispose();
    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();
    _emergencyRelationController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }
}
