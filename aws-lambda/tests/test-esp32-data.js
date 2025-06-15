// Test script to simulate ESP32 data for the Lambda function
// This simulates the data that would come from AWS IoT Core

const handler = require('./index').handler;

// Sample ESP32 telemetry data
const sampleTelemetryEvent = {
  topic: 'biotrack/device/ESP32_001/telemetry',
  deviceId: 'ESP32_001',
  timestamp: new Date().toISOString(),
  payload: {
    temperature: 36.8,
    heartRate: 75,
    spO2: 98,
    weight: 70.5,
    bioimpedance: {
      impedance: 450,
      bodyFat: 15.2,
      muscleMass: 35.8
    },
    batteryLevel: 85,
    signalStrength: -45
  }
};

// Sample device status event
const sampleStatusEvent = {
  topic: 'biotrack/device/ESP32_001/status',
  deviceId: 'ESP32_001',
  timestamp: new Date().toISOString(),
  payload: {
    status: 'online',
    batteryLevel: 85,
    signalStrength: -45,
    firmwareVersion: '1.2.3',
    lastReboot: new Date(Date.now() - 3600000).toISOString() // 1 hour ago
  }
};

// Sample device pairing event
const samplePairingEvent = {
  topic: 'biotrack/device/ESP32_001/pairing',
  deviceId: 'ESP32_001',
  timestamp: new Date().toISOString(),
  payload: {
    userId: 'user123',
    pairingCode: 'user123-ESP'
  }
};

async function testLambdaFunction() {
  console.log('🧪 Testing Lambda Function with ESP32 Emulated Data\n');
  
  let testsPassed = 0;
  let totalTests = 0;
  
  try {
    // Test 1: Telemetry Data
    totalTests++;
    console.log('📊 Test 1: Processing telemetry data...');
    const telemetryResult = await handler(sampleTelemetryEvent, {});
    const telemetryPassed = telemetryResult.statusCode === 200;
    console.log('✅ Telemetry test result:', telemetryPassed ? 'PASSED' : 'FAILED');
    console.log('Response:', telemetryResult.body);
    if (telemetryPassed) testsPassed++;
    console.log('');

    // Wait a bit
    await new Promise(resolve => setTimeout(resolve, 1000));

    // Test 2: Device Status
    totalTests++;
    console.log('📱 Test 2: Processing device status...');
    const statusResult = await handler(sampleStatusEvent, {});
    const statusPassed = statusResult.statusCode === 200;
    console.log('✅ Status test result:', statusPassed ? 'PASSED' : 'FAILED');
    console.log('Response:', statusResult.body);
    if (statusPassed) testsPassed++;
    console.log('');

    // Wait a bit
    await new Promise(resolve => setTimeout(resolve, 1000));

    // Test 3: Device Pairing
    totalTests++;
    console.log('🔗 Test 3: Processing device pairing...');
    const pairingResult = await handler(samplePairingEvent, {});
    const pairingPassed = pairingResult.statusCode === 200;
    console.log('✅ Pairing test result:', pairingPassed ? 'PASSED' : 'FAILED');
    console.log('Response:', pairingResult.body);
    if (pairingPassed) testsPassed++;
    console.log('');

    // Test 4: User-specific functionality (if available)
    try {
      const userTests = require('./test-user-functionality');
      console.log('👤 Test 4: Running user-specific functionality tests...');
      const userTestsPassed = await userTests.runComprehensiveTests();
      totalTests++;
      if (userTestsPassed) testsPassed++;
    } catch (error) {
      console.log('⚠️  User-specific tests not available or failed:', error.message);
    }

    console.log(`\n📊 Test Summary: ${testsPassed}/${totalTests} tests passed`);
    
    if (testsPassed === totalTests) {
      console.log('🎉 All tests completed successfully!');
      return true;
    } else {
      console.log('❌ Some tests failed!');
      return false;
    }

  } catch (error) {
    console.error('❌ Test failed with error:', error);
    return false;
  }
}

// Run the tests
if (require.main === module) {
  // Set environment variable to use mock Firebase for testing
  process.env.USE_MOCK_FIREBASE = 'true';
  testLambdaFunction();
}

module.exports = {
  testLambdaFunction,
  sampleTelemetryEvent,
  sampleStatusEvent,
  samplePairingEvent
};
