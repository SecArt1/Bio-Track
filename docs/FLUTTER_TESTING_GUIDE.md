# Flutter Mobile App Testing Guide

## 📱 BioTrack Health Monitoring App

### Current Build Status
- **Platform**: Android (iOS support available)
- **Status**: ✅ Dependencies installed, 🔄 Building APK
- **Firebase Integration**: ✅ Configured
- **Authentication**: ✅ Ready

## 🚀 Quick Start Testing

### 1. Install on Android Device
Once the build completes, install the debug APK:
```bash
# APK location after build
build/app/outputs/flutter-apk/app-debug.apk

# Install via ADB (if device connected)
adb install build/app/outputs/flutter-apk/app-debug.apk

# Or manually transfer APK to device and install
```

### 2. Firebase Authentication Test
The app supports multiple authentication methods:
- Email/Password registration
- Google Sign-In (configured)
- Anonymous authentication (for testing)

**Test Credentials**: Create test account or use anonymous mode

### 3. Core Features to Test

#### 📊 Dashboard & Real-time Data
- [ ] Dashboard loads with health metrics cards
- [ ] Real-time data updates from connected ESP32 devices
- [ ] Charts display historical health data
- [ ] Heart rate, temperature, weight readings display correctly

#### 🔐 Authentication Flow
- [ ] User registration works
- [ ] Login/logout functionality
- [ ] Password reset functionality
- [ ] Profile management
- [ ] Secure session handling

#### 📈 Health Monitoring
- [ ] Live sensor data visualization
- [ ] Health trends and analytics
- [ ] Alert notifications for abnormal readings
- [ ] Daily/weekly/monthly health summaries

#### ⚙️ Device Management
- [ ] ESP32 device pairing
- [ ] Device status monitoring
- [ ] Device configuration settings
- [ ] Connection status indicators

## 🧪 Test Scenarios

### Scenario 1: New User Onboarding
1. Open app for first time
2. Create new account with email/password
3. Complete profile setup (age, weight, height, medical conditions)
4. Navigate through app features tour
5. Verify profile data is saved to Firebase

### Scenario 2: Device Connection
1. Login to existing account
2. Navigate to "Add Device" screen
3. Scan for ESP32 device (or simulate with test data)
4. Pair device and verify connection status
5. View real-time data from device

### Scenario 3: Health Data Monitoring
1. View dashboard with current health metrics
2. Check historical data charts
3. Verify data updates in real-time
4. Test alert functionality with simulated critical values
5. Export health data report

### Scenario 4: Offline Functionality
1. Disconnect internet connection
2. Verify app still shows cached data
3. Test local data storage
4. Reconnect and verify data sync

## 📋 Test Data & Simulation

### Mock ESP32 Device Data
For testing without physical hardware, the app can use simulated data:

```json
{
  "deviceId": "test_device_001",
  "heartRate": 72,
  "temperature": 36.8,
  "weight": 70.5,
  "bloodPressure": {
    "systolic": 120,
    "diastolic": 80
  },
  "oxygenSaturation": 98,
  "timestamp": "2025-06-12T10:30:00Z"
}
```

### Test User Profiles
Create these test accounts for different scenarios:
- **Healthy Adult**: Normal range values, no alerts
- **Elderly Patient**: Higher blood pressure, temperature monitoring
- **Athlete**: Lower resting heart rate, weight tracking
- **Patient with Conditions**: Requires frequent monitoring, multiple alerts

## 🔍 UI/UX Testing Checklist

### Visual Design
- [ ] Material Design 3 components render correctly
- [ ] Dark/light theme switching works
- [ ] Custom color scheme matches health monitoring theme
- [ ] Icons and images load properly
- [ ] Text is readable across different screen sizes

### Navigation
- [ ] Bottom navigation bar works smoothly
- [ ] Page transitions are smooth
- [ ] Back button behavior is correct
- [ ] Deep linking works (if implemented)

### Responsive Design
- [ ] Works on different Android screen sizes
- [ ] Portrait/landscape orientation handling
- [ ] Text scales appropriately
- [ ] Charts and graphs are readable

### Accessibility
- [ ] Screen reader compatibility
- [ ] High contrast mode support
- [ ] Font size scaling
- [ ] Touch target sizes meet guidelines

## 🐛 Common Issues & Solutions

### Build Issues
**Gradle Build Failed**
```bash
# Clean and rebuild
flutter clean
flutter pub get
flutter build apk --debug
```

**Firebase Configuration Error**
- Verify `google-services.json` is in `android/app/`
- Check Firebase project configuration
- Ensure all required services are enabled

### Runtime Issues
**Authentication Failed**
- Check Firebase Auth configuration
- Verify API keys are correct
- Test with anonymous authentication first

**No Device Connection**
- Ensure ESP32 is broadcasting
- Check WiFi connectivity
- Verify Firebase Firestore rules allow reads

**Charts Not Loading**
- Check Firestore data structure
- Verify date/time formatting
- Test with mock data first

## 📊 Performance Testing

### Memory Usage
Monitor app memory consumption during:
- Continuous real-time data updates
- Chart rendering with large datasets
- Background data synchronization
- Multiple device connections

### Battery Usage
Test battery consumption during:
- Continuous background monitoring
- Real-time data streaming
- Location services (if used)
- Push notifications

### Network Usage
Monitor data consumption for:
- Real-time sensor data streaming
- Chart data loading
- Image/media content
- Offline data synchronization

## 🔄 Automated Testing

### Unit Tests
```bash
# Run unit tests
flutter test

# Run with coverage
flutter test --coverage
```

### Integration Tests
```bash
# Run integration tests
flutter drive --target=test_driver/app.dart
```

### Widget Tests
```bash
# Test specific widgets
flutter test test/widget_test.dart
```

## 📝 Test Results Documentation

### Template for Test Reports
```markdown
## Test Session: [Date]
**Device**: [Android Version/Model]
**App Version**: [Build Number]
**Tester**: [Name]

### Passed Tests
- [ ] Authentication flow
- [ ] Dashboard loading
- [ ] Real-time data display
- [ ] Chart rendering

### Failed Tests
- [ ] Issue description
- [ ] Steps to reproduce
- [ ] Expected vs actual behavior
- [ ] Screenshots/logs

### Performance Metrics
- App startup time: [seconds]
- Memory usage: [MB]
- Battery drain: [% per hour]
- Network usage: [MB per session]
```

## 🚀 Deployment Readiness

### Pre-Release Checklist
- [ ] All critical features working
- [ ] No crash-inducing bugs
- [ ] Performance meets requirements
- [ ] Security testing completed
- [ ] User acceptance testing passed
- [ ] Firebase backend fully functional

### Release Build
```bash
# Create release APK
flutter build apk --release

# Create App Bundle for Play Store
flutter build appbundle --release
```

---
*Start testing once the Flutter build completes! 🎯*
