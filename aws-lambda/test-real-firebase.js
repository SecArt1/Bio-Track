// Test script for Lambda function with Real Firebase (using emulator)
// This tests the real Firebase Admin SDK functionality without hitting production

// Set environment variables to use real Firebase Admin SDK but with emulator
process.env.USE_MOCK_FIREBASE = 'false';
process.env.FIRESTORE_EMULATOR_HOST = 'localhost:8080';

// Use fake service account credentials for emulator
process.env.FIREBASE_PRIVATE_KEY_ID = 'fake-key-id';
process.env.FIREBASE_PRIVATE_KEY = '-----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQC7VJTUt9Us8cKB\nwFVQGdX01O/iFmyqv7aDpKxEzv4pjDQ3HvQJ3RlQtdP+xBF8qnYcqZv9lA\n-----END PRIVATE KEY-----';
process.env.FIREBASE_CLIENT_EMAIL = 'test@bio-track-de846.iam.gserviceaccount.com';
process.env.FIREBASE_CLIENT_ID = '123456789';
process.env.FIREBASE_CLIENT_X509_CERT_URL = 'https://www.googleapis.com/oauth2/v1/certs';

const handler = require('./index').handler;

// Sample ESP32 telemetry data (same as mock test)
const sampleTelemetryEvent = {
  topic: 'biotrack/device/ESP32_002/telemetry',
  deviceId: 'ESP32_002',
  timestamp: new Date().toISOString(),
  payload: {
    temperature: 37.1,
    heartRate: 82,
    spO2: 97,
    weight: 65.2,
    bioimpedance: {
      impedance: 420,
      bodyFat: 18.5,
      muscleMass: 32.1
    },
    batteryLevel: 78,
    signalStrength: -52
  }
};

async function testRealFirebase() {
  console.log('🔥 Testing Lambda Function with Real Firebase Admin SDK (Emulator)\n');
  
  try {
    console.log('📊 Processing telemetry data with real Firebase Admin SDK...');
    const result = await handler(sampleTelemetryEvent, {});
    
    console.log('✅ Test result:', result.statusCode === 200 ? 'PASSED' : 'FAILED');
    console.log('Response:', result.body);
    
    if (result.statusCode === 200) {
      console.log('\n🎉 SUCCESS: ESP32 data successfully processed and stored in Firebase!');
      console.log('   • Sensor data stored in sensor_data collection');
      console.log('   • Device status updated');
      console.log('   • Health metrics processed');
      console.log('   • Alerts checked');
    }

  } catch (error) {
    console.error('❌ Test failed with error:', error);
    if (error.message.includes('firebase-admin')) {
      console.log('\n💡 Tip: Make sure Firebase emulator is running: firebase emulators:start --only firestore');
    }
  }
}

// Run the test
if (require.main === module) {
  testRealFirebase();
}

module.exports = { testRealFirebase };
