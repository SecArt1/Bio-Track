import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:bio_track/l10n/app_localizations.dart';
import 'package:bio_track/l10n/language_provider.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({Key? key}) : super(key: key);

  @override
  _EditProfilePageState createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  // Form key and controllers
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _heightController = TextEditingController();
  final _passwordController = TextEditingController();
  final _dobController = TextEditingController();

  // State variables
  String? _selectedGender;
  DateTime? _selectedDate;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _imageUrl;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    // Get current user immediately to detect auth issues early
    _currentUser = FirebaseAuth.instance.currentUser;
    _loadUserData();
  }

  @override
  void dispose() {
    // Clean up controllers to prevent memory leaks
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _heightController.dispose();
    _passwordController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  // Load user data from Firestore
  Future<void> _loadUserData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      if (_currentUser == null) {
        throw Exception("No authenticated user found");
      }

      debugPrint('Loading data for user: ${_currentUser!.uid}');

      final DocumentSnapshot userData = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .get();

      if (!mounted) return;

      if (userData.exists && userData.data() != null) {
        final data = userData.data() as Map<String, dynamic>;

        setState(() {
          _nameController.text = data['fullName'] ?? '';
          _emailController.text = data['email'] ?? _currentUser!.email ?? '';
          _phoneController.text = data['phone'] ?? '';
          _heightController.text = data['height']?.toString() ?? '';
          _selectedGender = data['gender'];
          _imageUrl = data['profileImage'];

          // Handle date of birth if present
          if (data.containsKey('dob') && data['dob'] != null) {
            _selectedDate = (data['dob'] as Timestamp).toDate();
            _dobController.text = formatDate(_selectedDate!);
          }
        });

        debugPrint('User data loaded successfully');
      } else {
        debugPrint('User document does not exist, using auth data');
        // Pre-fill with auth data
        setState(() {
          _emailController.text = _currentUser!.email ?? '';
          _nameController.text = _currentUser!.displayName ?? '';
        });
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load profile: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Format date consistently
  String formatDate(DateTime date) {
    return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
  }

  // Save profile to Firestore
  Future<void> _saveProfile() async {
    debugPrint('Save button pressed');

    // Validate form first
    if (_formKey.currentState == null) {
      debugPrint('Form key is null');
      return;
    }

    if (!_formKey.currentState!.validate()) {
      debugPrint('Form validation failed');
      return;
    }

    // Start saving process
    setState(() {
      _isSaving = true;
    });

    try {
      if (_currentUser == null) {
        throw Exception('No authenticated user found');
      }

      final uid = _currentUser!.uid;
      debugPrint('Preparing data for user $uid');

      // Create user data map
      final Map<String, dynamic> userData = {
        'fullName': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'gender': _selectedGender,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Add optional fields if present
      if (_heightController.text.isNotEmpty) {
        final height = double.tryParse(_heightController.text);
        if (height != null) {
          userData['height'] = height;
        }
      }

      if (_selectedDate != null) {
        userData['dob'] = Timestamp.fromDate(_selectedDate!);
      }

      debugPrint('Saving user data to Firestore');

      // Update Firestore document
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set(userData, SetOptions(merge: true));

      debugPrint('Firestore update successful');

      // Update Auth profile
      await _currentUser!.updateDisplayName(_nameController.text.trim());

      // Only update email if changed (this operation requires recent authentication)
      if (_emailController.text.trim() != _currentUser!.email &&
          _emailController.text.trim().isNotEmpty) {
        debugPrint('Updating email in Auth');
        try {
          await _currentUser!.updateEmail(_emailController.text.trim());
          debugPrint('Email updated successfully');
        } catch (e) {
          debugPrint('Email update failed: $e');
          // Show specific message for email update failure
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('Email update requires recent login: ${e.toString()}'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }

      // Update password if provided
      if (_passwordController.text.isNotEmpty) {
        try {
          await _currentUser!.updatePassword(_passwordController.text);
          debugPrint('Password updated successfully');
        } catch (e) {
          debugPrint('Password update failed: $e');
          // Show specific message for password update failure but don't fail the whole operation
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Password update requires recent login'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Reload user data to reflect changes
      _currentUser = FirebaseAuth.instance.currentUser;
      _loadUserData();
    } catch (e) {
      debugPrint('Error saving profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // Clear all form fields
  void _clearForm() {
    setState(() {
      _nameController.clear();
      _phoneController.clear();
      _heightController.clear();
      _passwordController.clear();
      _dobController.clear();
      _selectedGender = null;
      _selectedDate = null;
    });
  }

  // Open date picker for selecting date of birth
  Future<void> _selectDate(BuildContext context) async {
    final initialDate = _selectedDate ??
        DateTime.now().subtract(const Duration(days: 365 * 20));

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      helpText: 'Select Date of Birth',
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dobController.text = formatDate(picked);
      });
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
        title: Text(
          localizations.translate('edit_profile'),
          style: const TextStyle(
            color: Color(0xff0383c2),
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xff0383c2)))
          : GestureDetector(
              // Close keyboard when tapping outside
              onTap: () => FocusScope.of(context).unfocus(),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(30.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Profile Avatar
                        Center(
                          child: Stack(
                            children: [
                              CircleAvatar(
                                radius: 60,
                                backgroundImage: _imageUrl != null
                                    ? NetworkImage(_imageUrl!)
                                    : const AssetImage('assets/Dr. Amira.jpg')
                                        as ImageProvider,
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: InkWell(
                                  onTap: () {
                                    // Image picker would go here
                                  },
                                  child: const CircleAvatar(
                                    backgroundColor: Color(0xff0383c2),
                                    radius: 18,
                                    child:
                                        Icon(Icons.edit, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 50),

                        // Name Field
                        SizedBox(
                          width: 400,
                          height: 80,
                          child: TextFormField(
                            controller: _nameController,
                            decoration: InputDecoration(
                              labelText: localizations.translate('name'),
                              labelStyle: const TextStyle(
                                color: Color.fromARGB(255, 95, 127, 154),
                              ),
                              prefixIcon: const Icon(Icons.person_rounded),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30.0),
                                borderSide: const BorderSide(
                                  color: Color(0xff0383c2),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30.0),
                                borderSide: const BorderSide(
                                  color: Color(0xff0383c2),
                                  width: 2.0,
                                ),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30.0),
                                borderSide: const BorderSide(
                                  color: Colors.red,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return localizations.translate('enter_name');
                              }
                              return null;
                            },
                          ),
                        ),

                        // Gender Selection
                        const SizedBox(height: 6),
                        SizedBox(
                          width: 400,
                          height: 60,
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: localizations.translate('gender'),
                              labelStyle: const TextStyle(
                                color: Color.fromARGB(255, 95, 127, 154),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30.0),
                                borderSide: const BorderSide(
                                  color: Color(0xff0383c2),
                                ),
                              ),
                            ),
                            child: DropdownButton<String>(
                              underline:
                                  Container(), // Remove the default underline
                              isExpanded: true,
                              hint: Text(
                                  localizations.translate('select_gender')),
                              value: _selectedGender,
                              items: [
                                DropdownMenuItem<String>(
                                  value: 'Male',
                                  child: Text(localizations.translate('male')),
                                ),
                                DropdownMenuItem<String>(
                                  value: 'Female',
                                  child:
                                      Text(localizations.translate('female')),
                                ),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _selectedGender = value;
                                });
                              },
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Date of Birth
                        SizedBox(
                          width: 400,
                          height: 80,
                          child: TextFormField(
                            controller: _dobController,
                            decoration: InputDecoration(
                              labelText:
                                  localizations.translate('date_of_birth'),
                              labelStyle: const TextStyle(
                                color: Color.fromARGB(255, 95, 127, 154),
                              ),
                              prefixIcon: const Icon(Icons.calendar_today),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30.0),
                                borderSide: const BorderSide(
                                  color: Color(0xff0383c2),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30.0),
                                borderSide: const BorderSide(
                                  color: Color(0xff0383c2),
                                  width: 2.0,
                                ),
                              ),
                            ),
                            readOnly: true,
                            onTap: () => _selectDate(context),
                          ),
                        ),

                        // Height
                        SizedBox(
                          width: 400,
                          height: 80,
                          child: TextFormField(
                            controller: _heightController,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: InputDecoration(
                              labelText: localizations.translate('height'),
                              labelStyle: const TextStyle(
                                color: Color.fromARGB(255, 95, 127, 154),
                              ),
                              prefixIcon: const Icon(Icons.height),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30.0),
                                borderSide: const BorderSide(
                                  color: Color(0xff0383c2),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30.0),
                                borderSide: const BorderSide(
                                  color: Color(0xff0383c2),
                                  width: 2.0,
                                ),
                              ),
                              suffixText: 'cm',
                            ),
                            validator: (value) {
                              if (value != null && value.isNotEmpty) {
                                if (double.tryParse(value) == null) {
                                  return localizations
                                      .translate('invalid_height');
                                }
                              }
                              return null;
                            },
                          ),
                        ),

                        // Phone Number
                        SizedBox(
                          width: 400,
                          height: 80,
                          child: TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              labelText: localizations.translate('phone'),
                              labelStyle: const TextStyle(
                                color: Color.fromARGB(255, 95, 127, 154),
                              ),
                              prefixIcon: const Icon(Icons.phone_rounded),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30.0),
                                borderSide: const BorderSide(
                                  color: Color(0xff0383c2),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30.0),
                                borderSide: const BorderSide(
                                  color: Color(0xff0383c2),
                                  width: 2.0,
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Email
                        SizedBox(
                          width: 400,
                          height: 80,
                          child: TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              labelText: localizations.translate('email'),
                              labelStyle: const TextStyle(
                                color: Color.fromARGB(255, 95, 127, 154),
                              ),
                              prefixIcon: const Icon(Icons.mail_rounded),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30.0),
                                borderSide: const BorderSide(
                                  color: Color(0xff0383c2),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30.0),
                                borderSide: const BorderSide(
                                  color: Color(0xff0383c2),
                                  width: 2.0,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return localizations.translate('enter_email');
                              }
                              final emailRegex =
                                  RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                              if (!emailRegex.hasMatch(value)) {
                                return localizations.translate('invalid_email');
                              }
                              return null;
                            },
                          ),
                        ),

                        // Password
                        SizedBox(
                          width: 400,
                          height: 80,
                          child: TextFormField(
                            controller: _passwordController,
                            obscureText: true,
                            decoration: InputDecoration(
                              labelText: localizations.translate('password'),
                              labelStyle: const TextStyle(
                                color: Color.fromARGB(255, 95, 127, 154),
                              ),
                              prefixIcon: const Icon(Icons.lock),
                              helperText: localizations
                                  .translate('leave_empty_if_no_change'),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30.0),
                                borderSide: const BorderSide(
                                  color: Color(0xff0383c2),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30.0),
                                borderSide: const BorderSide(
                                  color: Color(0xff0383c2),
                                  width: 2.0,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if (value != null &&
                                  value.isNotEmpty &&
                                  value.length < 6) {
                                return localizations
                                    .translate('password_short');
                              }
                              return null;
                            },
                          ),
                        ),

                        const SizedBox(height: 60),

                        // Buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            SizedBox(
                              width: 150,
                              child: ElevatedButton(
                                onPressed: _isSaving ? null : _saveProfile,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xff0383c2),
                                  minimumSize: const Size(100, 60),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20.0),
                                    side: const BorderSide(
                                      color: Color.fromRGBO(180, 180, 181, 0.3),
                                    ),
                                  ),
                                ),
                                child: _isSaving
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(
                                        localizations.translate('save'),
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                              ),
                            ),
                            SizedBox(
                              width: 150,
                              child: ElevatedButton(
                                onPressed: _clearForm,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xff0383c2),
                                  minimumSize: const Size(100, 60),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20.0),
                                    side: const BorderSide(
                                      color: Color.fromRGBO(180, 180, 181, 0.3),
                                    ),
                                  ),
                                ),
                                child: Text(
                                  localizations.translate('clear'),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
