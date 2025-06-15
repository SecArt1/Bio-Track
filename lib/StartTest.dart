import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:async';
// Import localization
import 'package:bio_track/l10n/app_localizations.dart';
import 'services/aws_iot_service.dart';
import 'pages/device_pairing_screen.dart';

// Log levels and messages for device testing
enum LogLevel { info, success, warning, error, data }

class LogMessage {
  final String message;
  final String timestamp;
  final LogLevel level;

  LogMessage({
    required this.message,
    required this.timestamp,
    required this.level,
  });

  Color get color {
    switch (level) {
      case LogLevel.success:
        return Colors.green;
      case LogLevel.warning:
        return Colors.orange;
      case LogLevel.error:
        return Colors.red;
      case LogLevel.data:
        return Colors.blue;
      case LogLevel.info:
        return Colors.white;
    }
  }

  IconData get icon {
    switch (level) {
      case LogLevel.success:
        return Icons.check_circle;
      case LogLevel.warning:
        return Icons.warning;
      case LogLevel.error:
        return Icons.error;
      case LogLevel.data:
        return Icons.analytics;
      case LogLevel.info:
        return Icons.info;
    }
  }
}

class TestResult {
  final String testType;
  final String status;
  final double value;
  final String unit;
  final DateTime timestamp;
  final String error;
  final Map<String, dynamic> additionalData;

  TestResult({
    required this.testType,
    required this.status,
    required this.value,
    required this.unit,
    required this.timestamp,
    required this.error,
    required this.additionalData,
  });
}

class HealthSummaryScreen extends StatefulWidget {
  const HealthSummaryScreen({super.key});

  @override
  State<HealthSummaryScreen> createState() => _HealthSummaryScreenState();
}

class _HealthSummaryScreenState extends State<HealthSummaryScreen> {
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late String _deviceId;
  bool _isTestingPhase = true; // Start with testing phase
  bool _testsCompleted = false;

  // Test states
  Map<String, bool> _testInProgress = {
    'temperature': false,
    'weight': false,
    'bioimpedance': false,
    'heart_rate': false,
    'spo2': false,
    'full_screening': false,
  };

  // Test results
  Map<String, TestResult> _testResults = {};

  // Live log messages
  List<LogMessage> _logMessages = [];
  ScrollController _logScrollController = ScrollController();

  // Connection status
  bool _isDeviceOnline = false;
  bool _isAwsConnected = false;
  String _connectionStatus = "Connecting...";

  // Stream subscriptions
  StreamSubscription<DatabaseEvent>? _deviceDataSubscription;
  StreamSubscription<DatabaseEvent>? _deviceStatusSubscription;
  StreamSubscription<QuerySnapshot>? _firestoreSubscription;
  // Timers
  Timer? _pingTimer;
  Timer? _statusCheckTimer;

  @override
  void initState() {
    super.initState();
    _deviceId = "biotrack_device_001";
    _initializeConnections();
    _startPeriodicStatusCheck();
  }

  @override
  void dispose() {
    _deviceDataSubscription?.cancel();
    _deviceStatusSubscription?.cancel();
    _firestoreSubscription?.cancel();
    _pingTimer?.cancel();
    _statusCheckTimer?.cancel();
    _logScrollController.dispose();
    super.dispose();
  }

  void _initializeConnections() {
    _addLogMessage("🔄 Initializing connections...", LogLevel.info);
    _addLogMessage("🚀 Running in PRODUCTION mode", LogLevel.success);

    _setupFirebaseListeners();

    // Test AWS IoT network connectivity first
    _checkAWSConnection();

    // Then test device-specific connectivity
    _checkDeviceConnectivity();
  }

  void _setupFirebaseListeners() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _addLogMessage("❌ User not authenticated", LogLevel.error);
      return;
    }

    // Listen for real-time device data from Firebase Realtime Database
    _deviceDataSubscription = _databaseRef
        .child('devices')
        .child(_deviceId)
        .child('sensor_data')
        .onValue
        .listen((DatabaseEvent event) {
      if (event.snapshot.value != null) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        _processDeviceData(data);
      }
    });

    // Listen for device status changes
    _deviceStatusSubscription = _databaseRef
        .child('devices')
        .child(_deviceId)
        .child('status')
        .onValue
        .listen((DatabaseEvent event) {
      final status = event.snapshot.value as String?;
      _updateDeviceStatus(status);
    });

    // Listen for test responses from Firestore
    _firestoreSubscription = _firestore
        .collection('device_responses')
        .where('deviceId', isEqualTo: _deviceId)
        .orderBy('timestamp', descending: true)
        .limit(10)
        .snapshots()
        .listen((snapshot) {
      for (var doc in snapshot.docChanges) {
        if (doc.type == DocumentChangeType.added) {
          _processTestResponse(doc.doc.data()!);
        }
      }
    });

    _addLogMessage("✅ Firebase listeners initialized", LogLevel.success);
  }

  Future<void> _checkAWSConnection() async {
    try {
      final response = await AWSIoTService.testAWSConnectivity();

      setState(() {
        _isAwsConnected = response.success;
      });

      if (response.success) {
        _addLogMessage(
            "✅ AWS IoT network connection established", LogLevel.success);
      } else {
        _addLogMessage(
            "⚠️ AWS IoT network connection failed: ${response.message}",
            LogLevel.error);
      }
    } catch (e) {
      setState(() {
        _isAwsConnected = false;
      });
      _addLogMessage("❌ AWS IoT network connection error: $e", LogLevel.error);
    }
  }

  Future<void> _checkDeviceConnectivity() async {
    try {
      final response =
          await AWSIoTService.requestDeviceStatus(deviceId: _deviceId);

      if (response.success) {
        _addLogMessage(
            "📡 Device $_deviceId is online and responding", LogLevel.success);
        setState(() {
          _isDeviceOnline = true;
        });
      } else {
        _addLogMessage(
            "📡 Device $_deviceId not found or offline: ${response.message}",
            LogLevel.warning);
        setState(() {
          _isDeviceOnline = false;
        });
      }
    } catch (e) {
      _addLogMessage("📡 Device connectivity check error: $e", LogLevel.error);
      setState(() {
        _isDeviceOnline = false;
      });
    }
  }

  void _startPeriodicStatusCheck() {
    Timer.periodic(const Duration(seconds: 60), (timer) {
      if (mounted) {
        _checkAWSConnection();
      }
    });

    _pingTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        _checkDeviceConnectivity();
      }
    });

    _statusCheckTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) {
        _updateConnectionStatus();
      }
    });
  }

  void _updateConnectionStatus() {
    String status;

    if (!_isAwsConnected) {
      status = "AWS IoT Disconnected";
    } else if (!_isDeviceOnline) {
      status = "AWS Connected - Device Offline";
    } else {
      status = "Fully Connected";
    }

    setState(() {
      _connectionStatus = status;
    });
  }

  void _updateDeviceStatus(String? status) {
    final wasOnline = _isDeviceOnline;
    final isOnline = status == 'online';

    setState(() {
      _isDeviceOnline = isOnline;
    });

    if (wasOnline != isOnline) {
      _addLogMessage(
          isOnline ? "🟢 Device came online" : "🔴 Device went offline",
          isOnline ? LogLevel.success : LogLevel.warning);
    }
  }

  void _processDeviceData(Map<String, dynamic> data) {
    final sensorType = data['sensor_type'] as String?;
    final value = data['value']?.toDouble();
    final unit = data['unit'] as String? ?? '';
    final timestamp = data['timestamp'] as int?;

    if (sensorType != null && value != null && timestamp != null) {
      final result = TestResult(
        testType: sensorType,
        status: 'success',
        value: value,
        unit: unit,
        timestamp: DateTime.fromMillisecondsSinceEpoch(timestamp),
        error: '',
        additionalData: Map<String, dynamic>.from(data)
          ..remove('value')
          ..remove('unit')
          ..remove('timestamp')
          ..remove('sensor_type'),
      );

      setState(() {
        _testResults[sensorType] = result;
        _testInProgress[sensorType] = false;
      });

      _addLogMessage(
          "📊 ${sensorType.toUpperCase()}: ${value.toStringAsFixed(2)} $unit",
          LogLevel.data);

      _checkIfAllTestsCompleted();
    }
  }

  void _processTestResponse(Map<String, dynamic> data) {
    final command = data['command'] as String?;
    final status = data['status'] as String?;
    final error = data['error'] as String?;

    if (command == 'sensor_test') {
      final sensorType = data['sensorType'] as String?;
      if (sensorType != null) {
        setState(() {
          _testInProgress[sensorType] = false;
        });

        if (status == 'completed') {
          _addLogMessage("✅ $sensorType test completed", LogLevel.success);
        } else if (status == 'failed') {
          _addLogMessage(
              "❌ $sensorType test failed: ${error ?? 'Unknown error'}",
              LogLevel.error);
        }

        _checkIfAllTestsCompleted();
      }
    }
  }

  void _checkIfAllTestsCompleted() {
    final hasAnyInProgress =
        _testInProgress.values.any((inProgress) => inProgress);
    final hasResults = _testResults.isNotEmpty;

    if (!hasAnyInProgress && hasResults && !_testsCompleted) {
      setState(() {
        _testsCompleted = true;
      });

      _addLogMessage(
          "🎉 All tests completed! Saving results...", LogLevel.success);

      // Save test results to database
      _saveTestResults();

      // Auto-switch to results view after 3 seconds
      Timer(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _isTestingPhase = false;
          });
        }
      });
    }
  }

  void _addLogMessage(String message, LogLevel level) {
    final timestamp = DateFormat('HH:mm:ss.SSS').format(DateTime.now());
    setState(() {
      _logMessages.add(LogMessage(
        message: message,
        timestamp: timestamp,
        level: level,
      ));

      if (_logMessages.length > 100) {
        _logMessages.removeAt(0);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_logScrollController.hasClients) {
        _logScrollController.animateTo(
          _logScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _runFullScreening() async {
    if (_testInProgress['full_screening'] == true) return;

    setState(() {
      _testInProgress['full_screening'] = true;
      _testsCompleted = false;
      _testResults.clear();
    });

    _addLogMessage("🏥 Starting full health screening...", LogLevel.info);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final response = await AWSIoTService.startFullScreening(
        deviceId: _deviceId,
        userId: user.uid,
      );

      if (response.success) {
        _addLogMessage("📤 Full screening command sent", LogLevel.success);

        // Set timeout for full screening
        Timer(const Duration(minutes: 5), () {
          if (mounted && _testInProgress['full_screening'] == true) {
            setState(() {
              _testInProgress['full_screening'] = false;
            });
            _addLogMessage("⏰ Full screening timed out", LogLevel.warning);
          }
        });
      } else {
        setState(() {
          _testInProgress['full_screening'] = false;
        });
        _addLogMessage("❌ Failed to start full screening: ${response.message}",
            LogLevel.error);
      }
    } catch (e) {
      setState(() {
        _testInProgress['full_screening'] = false;
      });
      _addLogMessage("❌ Full screening error: $e", LogLevel.error);
    }
  }

  Future<void> _runSensorTest(String sensorType) async {
    if (_testInProgress[sensorType] == true) return;

    setState(() {
      _testInProgress[sensorType] = true;
    });

    _addLogMessage(
        "🧪 Starting ${sensorType.toUpperCase()} test...", LogLevel.info);

    try {
      final response = await AWSIoTService.startSensorTest(
        deviceId: _deviceId,
        sensorType: sensorType,
        duration: 10, // 10 seconds test duration
      );

      if (response.success) {
        _addLogMessage("📤 Test command sent successfully", LogLevel.success);

        // Set timeout for test completion
        Timer(const Duration(seconds: 30), () {
          if (mounted && _testInProgress[sensorType] == true) {
            setState(() {
              _testInProgress[sensorType] = false;
            });
            _addLogMessage("⏰ ${sensorType.toUpperCase()} test timed out",
                LogLevel.warning);
          }
        });
      } else {
        setState(() {
          _testInProgress[sensorType] = false;
        });
        _addLogMessage("❌ Failed to send test command: ${response.message}",
            LogLevel.error);
      }
    } catch (e) {
      setState(() {
        _testInProgress[sensorType] = false;
      });
      _addLogMessage("❌ Test error: $e", LogLevel.error);
    }
  }

  Future<void> _calibrateSensor(String sensorType) async {
    _addLogMessage("⚙️ Starting ${sensorType.toUpperCase()} calibration...",
        LogLevel.info);

    try {
      final response = await AWSIoTService.calibrateSensor(
        deviceId: _deviceId,
        sensorType: sensorType,
      );

      if (response.success) {
        _addLogMessage(
            "✅ Calibration command sent for $sensorType", LogLevel.success);
      } else {
        _addLogMessage(
            "❌ Calibration failed: ${response.message}", LogLevel.error);
      }
    } catch (e) {
      _addLogMessage("❌ Calibration error: $e", LogLevel.error);
    }
  }

  Future<void> _emergencyStop() async {
    _addLogMessage("🛑 Emergency stop initiated...", LogLevel.warning);

    try {
      final response = await AWSIoTService.emergencyStop(deviceId: _deviceId);

      if (response.success) {
        setState(() {
          _testInProgress.updateAll((key, value) => false);
        });
        _addLogMessage("🛑 Emergency stop successful", LogLevel.success);
      } else {
        _addLogMessage(
            "❌ Emergency stop failed: ${response.message}", LogLevel.error);
      }
    } catch (e) {
      _addLogMessage("❌ Emergency stop error: $e", LogLevel.error);
    }
  }

  // بيانات القياسات - Health metrics data
  final Map<String, double> healthMetrics = const {
    "Weight (kg)": 70,
    "Body Fat (%)": 25.5,
    "Muscle Mass (kg)": 50.2,
    "Heart Rate (bpm)": 120,
    "Blood Glucose (mg/dL)": 55,
    "Body Temperature (°C)": 36.5,
  };

  // القيم الطبيعية لكل مقياس - Normal ranges for each metric
  final Map<String, String> normalRanges = const {
    "Weight (kg)": "Varies by height and age",
    "Body Fat (%)": "10% - 20% (Men), 18% - 28% (Women)",
    "Muscle Mass (kg)": "Varies by body composition",
    "Heart Rate (bpm)": "60 - 100 bpm",
    "Blood Glucose (mg/dL)": "70 - 140 mg/dL",
    "Body Temperature (°C)": "36.1 - 37.2°C",
  };

  // ألوان مخصصة لكل مقياس صحي - Custom colors for each health metric
  final Map<String, Color> healthMetricColors = const {
    "Weight (kg)": Color(0xFF0383C2),
    "Body Fat (%)": Color(0xFF0383C2),
    "Muscle Mass (kg)": Color(0xFF0383C2),
    "Heart Rate (bpm)": Color(0xFF0383C2),
    "Blood Glucose (mg/dL)": Color(0xFF0383C2),
    "Body Temperature (°C)": Color(0xFF0383C2),
  };

  // تحديد الحالة الصحية - Determine health status
  String getHealthStatus(String metric, double value, BuildContext context) {
    final localizations = AppLocalizations.of(context);

    if (metric == "Heart Rate (bpm)") {
      if (value < 60) return localizations.translate("below_average");
      if (value > 100) return localizations.translate("above_average");
    } else if (metric == "Blood Glucose (mg/dL)") {
      if (value < 70) return localizations.translate("below_average");
      if (value > 140) return localizations.translate("above_average");
    } else if (metric == "Body Temperature (°C)") {
      if (value < 36.1) return localizations.translate("below_average");
      if (value > 37.2) return localizations.translate("above_average");
    }
    return localizations.translate("average");
  }

  // Getting translated metric names
  String getTranslatedMetricName(String englishName, BuildContext context) {
    final localizations = AppLocalizations.of(context);

    Map<String, String> translationKeys = {
      "Weight (kg)": "weight_kg",
      "Body Fat (%)": "body_fat_percent",
      "Muscle Mass (kg)": "muscle_mass_kg",
      "Heart Rate (bpm)": "heart_rate_bpm",
      "Blood Glucose (mg/dL)": "blood_glucose_mgdl",
      "Body Temperature (°C)": "body_temperature_c"
    };

    return localizations.translate(translationKeys[englishName] ?? englishName);
  }

  // Getting translated normal ranges
  String getTranslatedNormalRange(String metric, BuildContext context) {
    final localizations = AppLocalizations.of(context);

    Map<String, String> rangeKeys = {
      "Weight (kg)": "weight_normal_range",
      "Body Fat (%)": "body_fat_normal_range",
      "Muscle Mass (kg)": "muscle_mass_normal_range",
      "Heart Rate (bpm)": "heart_rate_normal_range",
      "Blood Glucose (mg/dL)": "blood_glucose_normal_range",
      "Body Temperature (°C)": "body_temperature_normal_range"
    };

    return localizations.translate(rangeKeys[metric] ?? "");
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          _isTestingPhase
              ? "Device Testing"
              : localizations.translate("health_summary"),
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF0383C2),
        centerTitle: true,
        actions: _isTestingPhase
            ? [
                Container(
                  margin: const EdgeInsets.only(right: 16),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: (_isAwsConnected && _isDeviceOnline)
                        ? Colors.green
                        : Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        (_isAwsConnected && _isDeviceOnline)
                            ? Icons.wifi
                            : Icons.wifi_off,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _connectionStatus,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ]
            : null,
      ),
      body: _isTestingPhase
          ? _buildTestingPhase(localizations)
          : _buildResultsPhase(localizations),
    );
  }

  Widget _buildTestingPhase(AppLocalizations localizations) {
    return Column(
      children: [
        // Header Section
        Container(
          padding: const EdgeInsets.all(16),
          color: const Color(0xff0383c2).withOpacity(0.1),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Device Testing',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onBackground,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Running comprehensive health screening...',
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context)
                      .colorScheme
                      .onBackground
                      .withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Device ID: $_deviceId',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context)
                      .colorScheme
                      .onBackground
                      .withOpacity(0.6),
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 8),
              // Connection Status Indicators
              Row(
                children: [
                  _buildStatusChip('AWS IoT', _isAwsConnected),
                  const SizedBox(width: 8),
                  _buildStatusChip('Device', _isDeviceOnline),
                  const SizedBox(width: 8),
                  _buildStatusChip('Firebase', true),
                ],
              ),
              const SizedBox(height: 12),
              // Start Test Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _testInProgress['full_screening'] == true
                      ? null
                      : () => _runFullScreening(),
                  icon: _testInProgress['full_screening'] == true
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.play_circle_filled, size: 24),
                  label: Text(
                    _testInProgress['full_screening'] == true
                        ? 'Running Tests...'
                        : 'Start Health Screening',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff0383c2),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                  ),
                ),
              ),
              const SizedBox(height: 8), // Individual Test Buttons (optional)
              if (_testInProgress['full_screening'] != true && !_testsCompleted)
                Column(
                  children: [
                    const Text(
                      'Or run individual tests:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // First row of sensor tests
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _testInProgress['temperature'] == true
                                ? null
                                : () => _runSensorTest('temperature'),
                            icon: Icon(
                              _testInProgress['temperature'] == true
                                  ? Icons.hourglass_empty
                                  : Icons.thermostat,
                              size: 16,
                            ),
                            label: Text(_testInProgress['temperature'] == true
                                ? 'Testing...'
                                : 'Temp'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _testInProgress['heart_rate'] == true
                                ? null
                                : () => _runSensorTest('heart_rate'),
                            icon: Icon(
                              _testInProgress['heart_rate'] == true
                                  ? Icons.hourglass_empty
                                  : Icons.favorite,
                              size: 16,
                            ),
                            label: Text(_testInProgress['heart_rate'] == true
                                ? 'Testing...'
                                : 'Heart'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _testInProgress['weight'] == true
                                ? null
                                : () => _runSensorTest('weight'),
                            icon: Icon(
                              _testInProgress['weight'] == true
                                  ? Icons.hourglass_empty
                                  : Icons.monitor_weight,
                              size: 16,
                            ),
                            label: Text(_testInProgress['weight'] == true
                                ? 'Testing...'
                                : 'Weight'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Second row of sensor tests
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _testInProgress['bioimpedance'] == true
                                ? null
                                : () => _runSensorTest('bioimpedance'),
                            icon: Icon(
                              _testInProgress['bioimpedance'] == true
                                  ? Icons.hourglass_empty
                                  : Icons.biotech,
                              size: 16,
                            ),
                            label: Text(_testInProgress['bioimpedance'] == true
                                ? 'Testing...'
                                : 'BIA'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _testInProgress['spo2'] == true
                                ? null
                                : () => _runSensorTest('spo2'),
                            icon: Icon(
                              _testInProgress['spo2'] == true
                                  ? Icons.hourglass_empty
                                  : Icons.air,
                              size: 16,
                            ),
                            label: Text(_testInProgress['spo2'] == true
                                ? 'Testing...'
                                : 'SpO2'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.cyan,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: PopupMenuButton<String>(
                            onSelected: (value) => _calibrateSensor(value),
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'temperature',
                                child: Row(
                                  children: [
                                    Icon(Icons.thermostat,
                                        color: Colors.orange),
                                    SizedBox(width: 8),
                                    Text('Calibrate Temp'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'weight',
                                child: Row(
                                  children: [
                                    Icon(Icons.monitor_weight,
                                        color: Colors.blue),
                                    SizedBox(width: 8),
                                    Text('Calibrate Weight'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'bioimpedance',
                                child: Row(
                                  children: [
                                    Icon(Icons.biotech, color: Colors.purple),
                                    SizedBox(width: 8),
                                    Text('Calibrate BIA'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'heart_rate',
                                child: Row(
                                  children: [
                                    Icon(Icons.favorite, color: Colors.red),
                                    SizedBox(width: 8),
                                    Text('Calibrate Heart'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'spo2',
                                child: Row(
                                  children: [
                                    Icon(Icons.air, color: Colors.cyan),
                                    SizedBox(width: 8),
                                    Text('Calibrate SpO2'),
                                  ],
                                ),
                              ),
                            ],
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 8, horizontal: 12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.settings, size: 16),
                                  SizedBox(width: 4),
                                  Text('Calibrate',
                                      style: TextStyle(fontSize: 12)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              // Device Connection and Pairing Buttons
              if (_testInProgress['full_screening'] != true && !_testsCompleted)
                Column(
                  children: [
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _checkDeviceConnectivity(),
                            icon: Icon(
                              _isDeviceOnline ? Icons.wifi : Icons.wifi_off,
                              color:
                                  _isDeviceOnline ? Colors.green : Colors.red,
                            ),
                            label: Text(
                              'Test Connection',
                              style: TextStyle(
                                color:
                                    _isDeviceOnline ? Colors.green : Colors.red,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color:
                                    _isDeviceOnline ? Colors.green : Colors.red,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const DevicePairingScreen(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.link,
                                color: Color(0xff0383c2)),
                            label: const Text(
                              'Pair Device',
                              style: TextStyle(color: Color(0xff0383c2)),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xff0383c2)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              // Emergency Stop Button (visible during testing)
              if (_testInProgress.values.any((inProgress) => inProgress))
                Column(
                  children: [
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _emergencyStop,
                        icon: const Icon(Icons.stop, color: Colors.white),
                        label: const Text(
                          'Emergency Stop',
                          style: TextStyle(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        // Log Panel
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Test Status Overview
                if (_testResults.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Tests Completed: ${_testResults.length}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        if (_testsCompleted)
                          const Text(
                            'Preparing results...',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green,
                            ),
                          ),
                      ],
                    ),
                  ),
                Expanded(child: _buildLogPanel()),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResultsPhase(AppLocalizations localizations) {
    // Convert test results to health metrics format
    Map<String, double> healthMetrics = {};

    for (var testResult in _testResults.values) {
      if (testResult.status == 'success') {
        switch (testResult.testType) {
          case 'temperature':
            healthMetrics["Body Temperature (°C)"] = testResult.value;
            break;
          case 'weight':
            healthMetrics["Weight (kg)"] = testResult.value;
            break;
          case 'bioimpedance':
            healthMetrics["Body Fat (%)"] = testResult.value;
            break;
          case 'heart_rate':
            healthMetrics["Heart Rate (bpm)"] = testResult.value;
            break;
          case 'spo2':
            healthMetrics["Blood Oxygen (%)"] = testResult.value;
            break;
        }
      }
    }

    // Use default values if no test results available
    if (healthMetrics.isEmpty) {
      healthMetrics = const {
        "Weight (kg)": 70,
        "Body Fat (%)": 25.5,
        "Muscle Mass (kg)": 50.2,
        "Heart Rate (bpm)": 120,
        "Blood Glucose (mg/dL)": 55,
        "Body Temperature (°C)": 36.5,
      };
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Results summary
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 32,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Health Screening Complete!',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                Text(
                  'Tests completed: ${_testResults.length}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.green.shade700,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Health metrics grid
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: healthMetrics.length,
              itemBuilder: (context, index) {
                String key = healthMetrics.keys.elementAt(index);
                double value = healthMetrics[key]!;
                String translatedMetric = getTranslatedMetricName(key, context);
                String healthStatus = getHealthStatus(key, value, context);

                return GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text(translatedMetric),
                        content: Text(
                            "${localizations.translate("normal_range")}: ${getTranslatedNormalRange(key, context)}"),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text(localizations.translate("close")),
                          ),
                        ],
                      ),
                    );
                  },
                  child: Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            translatedMetric,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: healthMetricColors[key] ??
                                  const Color(0xFF0383C2),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "$value",
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            healthStatus,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: healthStatus ==
                                      localizations.translate("average")
                                  ? Colors.green
                                  : Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 20),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _isTestingPhase = true;
                      _testsCompleted = false;
                      _testResults.clear();
                    });
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Run New Test'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0383C2),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    // Share functionality
                  },
                  icon: const Icon(Icons.share),
                  label: Text(localizations.translate("share_report")),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLogPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Live Log',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onBackground,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                setState(() {
                  _logMessages.clear();
                });
              },
              tooltip: 'Clear log',
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.withOpacity(0.3)),
            ),
            child: _logMessages.isEmpty
                ? const Center(
                    child: Text(
                      'Waiting for test data...',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    controller: _logScrollController,
                    padding: const EdgeInsets.all(8),
                    itemCount: _logMessages.length,
                    itemBuilder: (context, index) {
                      final log = _logMessages[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '[${log.timestamp}] ',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                                fontFamily: 'monospace',
                              ),
                            ),
                            Icon(
                              log.icon,
                              color: log.color,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                log.message,
                                style: TextStyle(
                                  color: log.color,
                                  fontSize: 12,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip(String label, bool isConnected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isConnected
            ? Colors.green.withOpacity(0.2)
            : Colors.red.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isConnected ? Colors.green : Colors.red,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isConnected ? Icons.check_circle : Icons.error,
            size: 12,
            color: isConnected ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isConnected ? Colors.green : Colors.red,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // Save test results to Firestore for history tracking
  Future<void> _saveTestResults() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final batch = FirebaseFirestore.instance.batch();
      final timestamp = Timestamp.now();

      for (var entry in _testResults.entries) {
        final testResult = entry.value;

        // Create a document for each test result
        final docRef =
            FirebaseFirestore.instance.collection('testResults').doc();

        batch.set(docRef, {
          'userId': user.uid,
          'testType': testResult.testType,
          'type': _normalizeTestType(
              testResult.testType), // Normalized for consistency
          'value': testResult.value,
          'unit': testResult.unit,
          'status': testResult.status,
          'timestamp': timestamp,
          'deviceId': _deviceId,
          'sessionId': DateTime.now().millisecondsSinceEpoch.toString(),
          'additionalData': testResult.additionalData,
          'error': testResult.error.isEmpty ? null : testResult.error,
        });
      }

      // Also save a summary document for the complete screening
      final summaryRef =
          FirebaseFirestore.instance.collection('healthScreenings').doc();
      batch.set(summaryRef, {
        'userId': user.uid,
        'type': 'complete_screening',
        'timestamp': timestamp,
        'deviceId': _deviceId,
        'testsCompleted': _testResults.length,
        'testTypes': _testResults.keys.toList(),
        'sessionId': DateTime.now().millisecondsSinceEpoch.toString(),
        'status': 'completed',
      });

      await batch.commit();

      _addLogMessage("💾 Test results saved to database", LogLevel.success);
    } catch (e) {
      _addLogMessage("❌ Failed to save test results: $e", LogLevel.error);
      print('Error saving test results: $e');
    }
  }

  String _normalizeTestType(String testType) {
    // Normalize test types to match previous results screen expectations
    switch (testType.toLowerCase()) {
      case 'heart_rate':
      case 'heartrate':
        return 'heart_rate';
      case 'bioimpedance':
      case 'body_fat':
      case 'bodyfat':
        return 'body_composition';
      case 'temperature':
      case 'body_temperature':
        return 'temperature';
      case 'weight':
        return 'weight';
      case 'spo2':
      case 'blood_oxygen':
      case 'oxygen':
        return 'oxygen';
      default:
        return testType.toLowerCase();
    }
  }
}
